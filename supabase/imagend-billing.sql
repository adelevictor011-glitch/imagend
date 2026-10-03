-- ============================================================
-- IMAGEND · Plans, daily quotas, teams & payments
-- Run once in Supabase → SQL Editor → New query → Run.
-- Safe to run again (it only adds / replaces, never deletes data).
-- ============================================================

-- ---------- 1. Plans (single source of truth for limits & prices) ----------
create table if not exists public.plans (
  id            text primary key,
  name          text not null,
  daily_limit   int  not null,
  price_monthly int  not null default 0,   -- NGN
  price_yearly  int  not null default 0,   -- NGN
  sort          int  not null default 0
);
insert into public.plans (id, name, daily_limit, price_monthly, price_yearly, sort) values
  ('free',    'Free',     2,      0,      0, 0),
  ('creator', 'Creator',  5,   5000,  50000, 1),
  ('studio',  'Studio',  20,  16000, 160000, 2)
on conflict (id) do update set
  name = excluded.name, daily_limit = excluded.daily_limit,
  price_monthly = excluded.price_monthly, price_yearly = excluded.price_yearly, sort = excluded.sort;

alter table public.plans enable row level security;
drop policy if exists "plans are public" on public.plans;
create policy "plans are public" on public.plans for select using (true);
grant select on public.plans to anon, authenticated;

-- ---------- 2. Complimentary (owner) accounts: free, unlimited ----------
create table if not exists public.comp_accounts (
  email text primary key,
  note  text
);
-- Owner emails are added directly in Supabase (see docs/04-runbooks.md), not kept in this repo:
-- insert into public.comp_accounts (email, note) values ('owner@example.com','owner') on conflict (email) do nothing;
alter table public.comp_accounts enable row level security;   -- no policies = invisible to users

-- ---------- 3. Teams ----------
create table if not exists public.teams (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  owner_id    uuid not null,
  invite_code text not null unique,
  created_at  timestamptz not null default now()
);
alter table public.teams enable row level security;

-- ---------- 4. Profile columns ----------
alter table public.profiles add column if not exists plan               text        not null default 'free';
alter table public.profiles add column if not exists plan_until         timestamptz;
alter table public.profiles add column if not exists beta_until         timestamptz;
alter table public.profiles add column if not exists team_id            uuid references public.teams(id) on delete set null;
alter table public.profiles add column if not exists team_joined_at     timestamptz;
alter table public.profiles add column if not exists dialogue_uses_used int         not null default 0;
alter table public.profiles add column if not exists redeemed_code      text;
alter table public.profiles add column if not exists generations_used   int         not null default 0;
alter table public.profiles add column if not exists pro_until          timestamptz;
alter table public.profiles add column if not exists trial_until        timestamptz;
alter table public.profiles add column if not exists trial_claimed_at   timestamptz;

create unique index if not exists profiles_user_id_uidx on public.profiles(user_id);

-- Carry over anyone who already redeemed BETATESTER under the old system
update public.profiles
   set beta_until = timestamptz '2026-10-31 23:00:00+00'
 where upper(coalesce(redeemed_code,'')) = 'BETATESTER' and beta_until is null;

-- ---------- 5. Daily usage (resets at midnight Lagos time) ----------
create table if not exists public.usage_daily (
  user_id uuid not null,
  day     date not null,
  count   int  not null default 0,
  primary key (user_id, day)
);
alter table public.usage_daily enable row level security;

-- ---------- 6. Payments ledger (one row per Flutterwave transaction) ----------
create table if not exists public.payments (
  tx_id      text primary key,           -- Flutterwave transaction id
  tx_ref     text,
  user_id    uuid not null,
  plan       text not null references public.plans(id),
  cycle      text not null check (cycle in ('monthly','yearly')),
  amount     numeric not null,
  currency   text not null,
  created_at timestamptz not null default now()
);
alter table public.payments enable row level security;
drop policy if exists "own payments" on public.payments;
create policy "own payments" on public.payments for select using (auth.uid() = user_id);
grant select on public.payments to authenticated;

-- ---------- 6b. Free-trial claims (one per account; device and network checked) ----------
-- ip_hash / device_hash are keyed HMAC-SHA256 digests made on the server; raw IPs are never stored.
create table if not exists public.trial_claims (
  user_id     uuid primary key,
  ip_hash     text not null,
  device_hash text,
  claimed_at  timestamptz not null default now()
);
create index if not exists trial_claims_ip_idx     on public.trial_claims(ip_hash, claimed_at);
create index if not exists trial_claims_device_idx on public.trial_claims(device_hash);
alter table public.trial_claims enable row level security;   -- no policies = invisible to users

-- ---------- 7. Lock down direct writes ----------
-- Users can READ their own profile, but can no longer edit plan, counters or codes
-- from the browser. All changes go through the functions below.
alter table public.profiles enable row level security;
revoke insert, update, delete on public.profiles from anon, authenticated;
revoke all on public.usage_daily, public.teams, public.comp_accounts, public.trial_claims from anon, authenticated;
drop policy if exists "read own profile" on public.profiles;
create policy "read own profile" on public.profiles for select using (auth.uid() = user_id);
grant select on public.profiles to authenticated;

-- ============================================================
-- FUNCTIONS
-- ============================================================

create or replace function public._lagos_today() returns date
language sql stable as $$ select (now() at time zone 'Africa/Lagos')::date $$;

-- Make sure a profile row exists
create or replace function public._ensure_profile(p_uid uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (user_id) values (p_uid) on conflict (user_id) do nothing;
end $$;

-- What plan is this user really on right now?
create or replace function public._effective_plan(p_uid uuid,
  out plan text, out plan_name text, out daily_limit int, out until timestamptz, out source text)
language plpgsql stable security definer set search_path = public as $$
declare pr record; em text;
begin
  select lower(u.email) into em from auth.users u where u.id = p_uid;
  if em is not null and exists (select 1 from public.comp_accounts c where lower(c.email) = em) then
    plan := 'studio'; plan_name := 'Owner'; daily_limit := 100000; until := null; source := 'comp';
    return;
  end if;

  select * into pr from public.profiles p where p.user_id = p_uid;

  -- Paid plan
  if pr.plan in ('creator','studio') and pr.plan_until > now() then
    select pl.id, pl.name, pl.daily_limit into plan, plan_name, daily_limit from public.plans pl where pl.id = pr.plan;
    until := pr.plan_until; source := 'paid';
  end if;

  -- 14-day Creator trial
  if pr.trial_until > now() and coalesce(daily_limit,0) < (select pl.daily_limit from public.plans pl where pl.id='creator') then
    select pl.id, 'Creator trial', pl.daily_limit into plan, plan_name, daily_limit from public.plans pl where pl.id = 'creator';
    until := pr.trial_until; source := 'trial';
  end if;

  -- Beta (Studio level) wins if it gives more
  if pr.beta_until > now() and coalesce(daily_limit,0) < (select pl.daily_limit from public.plans pl where pl.id='studio') then
    select pl.id, pl.name, pl.daily_limit into plan, plan_name, daily_limit from public.plans pl where pl.id = 'studio';
    until := pr.beta_until; source := 'beta';
  end if;

  if plan is null then
    select pl.id, pl.name, pl.daily_limit into plan, plan_name, daily_limit from public.plans pl where pl.id = 'free';
    until := null; source := 'free';
  end if;
end $$;

-- Full status for the signed-in user (what the app shows)
create or replace function public.get_my_status() returns json
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); ep record; pr record; team_json json := null;
        used_today int; t_limit int; t_used int; t_count int;
begin
  if uid is null then raise exception 'not signed in'; end if;
  perform public._ensure_profile(uid);
  select * into ep from public._effective_plan(uid);
  select * into pr from public.profiles where user_id = uid;
  select coalesce(count,0) into used_today from public.usage_daily where user_id = uid and day = public._lagos_today();
  used_today := coalesce(used_today,0);

  if pr.team_id is not null then
    select coalesce(sum(e.daily_limit),0), count(*) into t_limit, t_count
      from public.profiles m, lateral public._effective_plan(m.user_id) e
     where m.team_id = pr.team_id;
    select coalesce(sum(u.count),0) into t_used
      from public.usage_daily u join public.profiles m on m.user_id = u.user_id
     where m.team_id = pr.team_id and u.day = public._lagos_today();
    select json_build_object('id', t.id, 'name', t.name, 'invite_code', t.invite_code,
                             'is_owner', t.owner_id = uid, 'members', t_count)
      into team_json from public.teams t where t.id = pr.team_id;
  end if;

  return json_build_object(
    'plan', ep.plan, 'plan_name', ep.plan_name, 'source', ep.source, 'until', ep.until,
    'daily_limit', ep.daily_limit, 'used_today', used_today,
    'limit', case when pr.team_id is not null then t_limit else ep.daily_limit end,
    'used',  case when pr.team_id is not null then t_used  else used_today     end,
    'dialogue_used', pr.dialogue_uses_used,
    'trial_until', pr.trial_until,
    'trial_available', (pr.trial_claimed_at is null and ep.source = 'free'
                        and not exists (select 1 from public.payments x where x.user_id = uid)),
    'team', team_json
  );
end $$;

-- Count one generation (call BEFORE showing the prompt). Returns {ok, reason, ...status}
create or replace function public.consume_generation(p_kind text default 'prompt') returns json
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); st json; pr record; ep record;
begin
  if uid is null then raise exception 'not signed in'; end if;
  perform public._ensure_profile(uid);
  select * into pr from public.profiles where user_id = uid;
  -- serialise per team (or per user) so two tabs can't overspend the pool
  perform pg_advisory_xact_lock(hashtext(coalesce(pr.team_id::text, uid::text)));

  st := public.get_my_status();
  if (st->>'used')::int >= (st->>'limit')::int then
    return json_build_object('ok', false, 'reason', 'quota', 'status', st);
  end if;

  select * into ep from public._effective_plan(uid);
  if p_kind = 'dialogue' and ep.plan = 'free' and pr.dialogue_uses_used >= 3 then
    return json_build_object('ok', false, 'reason', 'dialogue', 'status', st);
  end if;

  insert into public.usage_daily (user_id, day, count) values (uid, public._lagos_today(), 1)
  on conflict (user_id, day) do update set count = public.usage_daily.count + 1;
  update public.profiles set generations_used = generations_used + 1,
         dialogue_uses_used = dialogue_uses_used + case when p_kind='dialogue' then 1 else 0 end
   where user_id = uid;

  return json_build_object('ok', true, 'reason', null, 'status', public.get_my_status());
end $$;

-- BETATESTER → Studio until 31 Oct 2026
create or replace function public.redeem_code(p_code text) returns json
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); beta_end timestamptz := timestamptz '2026-10-31 23:00:00+00';
begin
  if uid is null then raise exception 'not signed in'; end if;
  if upper(trim(coalesce(p_code,''))) <> 'BETATESTER' or now() >= beta_end then
    raise exception 'That code isn''t valid or has expired';
  end if;
  perform public._ensure_profile(uid);
  update public.profiles set beta_until = beta_end, redeemed_code = 'BETATESTER' where user_id = uid;
  return public.get_my_status();
end $$;

-- ---------- Teams ----------
create or replace function public.create_team(p_name text) returns json
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); tid uuid; code text;
begin
  if uid is null then raise exception 'not signed in'; end if;
  perform public._ensure_profile(uid);
  if (select team_id from public.profiles where user_id = uid) is not null then
    raise exception 'You''re already in a team. Leave it first.';
  end if;
  if length(trim(coalesce(p_name,''))) < 2 then raise exception 'Give your team a name'; end if;
  loop
    code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    exit when not exists (select 1 from public.teams where invite_code = code);
  end loop;
  insert into public.teams (name, owner_id, invite_code) values (left(trim(p_name), 40), uid, code) returning id into tid;
  update public.profiles set team_id = tid, team_joined_at = now() where user_id = uid;
  return public.get_my_status();
end $$;

create or replace function public.join_team(p_code text) returns json
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); tid uuid;
begin
  if uid is null then raise exception 'not signed in'; end if;
  perform public._ensure_profile(uid);
  if (select team_id from public.profiles where user_id = uid) is not null then
    raise exception 'You''re already in a team. Leave it first.';
  end if;
  select id into tid from public.teams where invite_code = upper(trim(coalesce(p_code,'')));
  if tid is null then raise exception 'No team found with that code'; end if;
  update public.profiles set team_id = tid, team_joined_at = now() where user_id = uid;
  return public.get_my_status();
end $$;

create or replace function public.leave_team() returns json
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); tid uuid; next_owner uuid;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select team_id into tid from public.profiles where user_id = uid;
  if tid is null then return public.get_my_status(); end if;
  update public.profiles set team_id = null, team_joined_at = null where user_id = uid;
  if (select owner_id from public.teams where id = tid) = uid then
    select user_id into next_owner from public.profiles where team_id = tid order by team_joined_at limit 1;
    if next_owner is null then delete from public.teams where id = tid;
    else update public.teams set owner_id = next_owner where id = tid; end if;
  end if;
  return public.get_my_status();
end $$;

create or replace function public.get_team_members() returns json
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); tid uuid;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select team_id into tid from public.profiles where user_id = uid;
  if tid is null then return '[]'::json; end if;
  return coalesce((
    select json_agg(json_build_object(
      'email', u.email, 'plan', e.plan_name, 'daily_limit', e.daily_limit,
      'used_today', coalesce(d.count,0), 'is_owner', t.owner_id = m.user_id, 'is_me', m.user_id = uid)
      order by m.team_joined_at)
    from public.profiles m
    join auth.users u on u.id = m.user_id
    join public.teams t on t.id = m.team_id
    left join public.usage_daily d on d.user_id = m.user_id and d.day = public._lagos_today()
    cross join lateral public._effective_plan(m.user_id) e
    where m.team_id = tid), '[]'::json);
end $$;

-- ---------- Payments: ONLY the server (service role) can call this ----------
create or replace function public.apply_payment(p_user uuid, p_plan text, p_cycle text,
  p_tx_id text, p_tx_ref text, p_amount numeric, p_currency text) returns json
language plpgsql security definer set search_path = public as $$
declare expected int; pr record; step interval; inserted int;
begin
  if p_plan not in ('creator','studio') then raise exception 'bad plan'; end if;
  if p_cycle not in ('monthly','yearly') then raise exception 'bad cycle'; end if;
  select case when p_cycle='yearly' then price_yearly else price_monthly end into expected
    from public.plans where id = p_plan;
  if upper(p_currency) <> 'NGN' or p_amount < expected then
    raise exception 'amount % % does not match % %', p_amount, p_currency, expected, 'NGN';
  end if;

  perform public._ensure_profile(p_user);
  insert into public.payments (tx_id, tx_ref, user_id, plan, cycle, amount, currency)
  values (p_tx_id, p_tx_ref, p_user, p_plan, p_cycle, p_amount, upper(p_currency))
  on conflict (tx_id) do nothing;
  get diagnostics inserted = row_count;
  if inserted = 0 then return json_build_object('applied', false, 'reason', 'already applied'); end if;

  step := case when p_cycle='yearly' then interval '1 year' else interval '1 month' end;
  select * into pr from public.profiles where user_id = p_user;
  if pr.plan = p_plan and pr.plan_until > now() then
    update public.profiles set plan_until = plan_until + step where user_id = p_user;     -- renew: add time
  else
    -- new / switched plan. Buying Creator during a Creator trial starts the paid month when the trial ends.
    update public.profiles set plan = p_plan,
           plan_until = (case when p_plan = 'creator' and pr.trial_until > now() then pr.trial_until else now() end) + step
     where user_id = p_user;
  end if;
  return json_build_object('applied', true, 'plan', p_plan,
    'until', (select plan_until from public.profiles where user_id = p_user));
end $$;

-- ---------- Free trial: ONLY the server (service role) can call this ----------
-- Rules: one trial per account, never after a payment, one per device,
-- and at most TRIAL_PER_NETWORK trials per network (IP) in 30 days.
create or replace function public.apply_trial(p_user uuid, p_ip_hash text, p_device_hash text) returns json
language plpgsql security definer set search_path = public as $$
declare pr record; ep record; per_network constant int := 2; days constant int := 14; until_ts timestamptz;
begin
  if p_user is null or coalesce(p_ip_hash,'') = '' then raise exception 'missing user or network'; end if;
  perform public._ensure_profile(p_user);
  perform pg_advisory_xact_lock(hashtext('trial:'||p_ip_hash));
  delete from public.trial_claims where claimed_at < now() - interval '12 months';   -- retention: 12 months
  select * into pr from public.profiles where user_id = p_user for update;
  select * into ep from public._effective_plan(p_user);

  if pr.trial_claimed_at is not null or exists (select 1 from public.trial_claims where user_id = p_user) then
    return json_build_object('ok', false, 'reason', 'already_claimed');
  end if;
  if exists (select 1 from public.payments where user_id = p_user) then
    return json_build_object('ok', false, 'reason', 'paid_before');
  end if;
  if ep.source <> 'free' then
    return json_build_object('ok', false, 'reason', 'plan_active', 'source', ep.source, 'until', ep.until);
  end if;
  if coalesce(p_device_hash,'') <> '' and exists (select 1 from public.trial_claims where device_hash = p_device_hash) then
    return json_build_object('ok', false, 'reason', 'device_used');
  end if;
  if (select count(*) from public.trial_claims
       where ip_hash = p_ip_hash and claimed_at > now() - interval '30 days') >= per_network then
    return json_build_object('ok', false, 'reason', 'network_used');
  end if;

  until_ts := now() + make_interval(days => days);
  insert into public.trial_claims (user_id, ip_hash, device_hash) values (p_user, p_ip_hash, nullif(p_device_hash,''));
  update public.profiles set trial_until = until_ts, trial_claimed_at = now() where user_id = p_user;
  return json_build_object('ok', true, 'until', until_ts);
end $$;

-- ---------- Who can call what ----------
revoke all on function public._effective_plan(uuid)        from public, anon, authenticated;
revoke all on function public._ensure_profile(uuid)        from public, anon, authenticated;
revoke all on function public.apply_payment(uuid,text,text,text,text,numeric,text) from public, anon, authenticated;
grant execute on function public.apply_payment(uuid,text,text,text,text,numeric,text) to service_role;
revoke all on function public.apply_trial(uuid,text,text) from public, anon, authenticated;
grant execute on function public.apply_trial(uuid,text,text) to service_role;
revoke all on function public.get_my_status()              from public, anon;
revoke all on function public.consume_generation(text)     from public, anon;
revoke all on function public.redeem_code(text)            from public, anon;
revoke all on function public.create_team(text)            from public, anon;
revoke all on function public.join_team(text)              from public, anon;
revoke all on function public.leave_team()                 from public, anon;
revoke all on function public.get_team_members()           from public, anon;
grant execute on function public.get_my_status(), public.consume_generation(text), public.redeem_code(text),
  public.create_team(text), public.join_team(text), public.leave_team(), public.get_team_members()
  to authenticated;
