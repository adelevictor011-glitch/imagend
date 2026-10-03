# 04 · Runbooks: what to do when…

Each runbook is a short checklist. SQL runs in **Supabase → SQL Editor → New query**. Replace the example values.

---

## A customer paid but their plan didn't switch on

1. Flutterwave → **Transactions** → open the payment. Check it says **Successful**.
2. Try **Resend webhook** on that transaction. If the webhook is set up correctly, the plan switches on within seconds.
3. If resend says "no hook data found", or nothing changes, credit it by hand. Copy the **Transaction ID** and **Reference** (`imgnd_creator_monthly_…`). The plan and cycle are in the reference.

```sql
select public.apply_payment(
  (select id from auth.users where lower(email) = 'customer@gmail.com'),
  'creator', 'monthly',          -- from the reference: creator|studio, monthly|yearly
  'TRANSACTION_ID', 'REFERENCE',
  5000, 'NGN'                    -- the amount actually paid
);
```

- `{"applied": true, …}` means done.
- `{"applied": false, "reason": "already applied"}` means it was already credited. Check below.
- An error saying the amount doesn't match means they paid less than the plan price. Check the amount.

**Check a customer's plan:**
```sql
select u.email, p.plan, p.plan_until, p.beta_until, p.team_id
from public.profiles p join auth.users u on u.id = p.user_id
where lower(u.email) = 'customer@gmail.com';
```

## Refund a customer

1. Refund in Flutterwave (Transactions → the payment → Refund).
2. End their plan in Imagend. A refund in Flutterwave **does not** do this automatically:
```sql
update public.profiles set plan = 'free', plan_until = null
where user_id = (select id from auth.users where lower(email) = 'customer@gmail.com');
```
This affects only that one email.

## Give someone free unlimited (owner) access
```sql
insert into public.comp_accounts (email, note) values ('person@gmail.com', 'reason')
on conflict (email) do nothing;
```
To remove them: `delete from public.comp_accounts where email = 'person@gmail.com';`

## Change prices or daily limits
```sql
update public.plans set price_monthly = 6000, price_yearly = 60000, daily_limit = 5 where id = 'creator';
```
The plans screen reads these values live. The database will then only accept payments at the new price. **Also update `terms.html`, `index.html` (the `PLANS` fallback list in the shell) and the docs.**

## Extend or end the BETATESTER promotion
The end date (31 Oct 2026 23:00 UTC) is in `redeem_code` in `supabase/imagend-billing.sql`. Change it there and re-run the file.

Existing beta users keep the `beta_until` already saved. To move everyone:
```sql
update public.profiles set beta_until = timestamptz '2026-11-30 23:00:00+00' where beta_until is not null;
```

## Flutterwave says "webhooks are not reaching your server"
1. Check the URL is **`https://www.imagendai.com/api/flutterwave-webhook`** (with **www**).
2. Check the secret hash matches `FLW_SECRET_HASH` in Vercel exactly. A wrong hash returns 401.
3. Check "v3 webhooks" and "JSON format" are on.
4. Vercel → project → **Logs**, filter `/api/flutterwave-webhook`, and look at the status code. `200` means fine. `401` means the hash is wrong. `500` means a missing environment variable. `308` means the www problem.

## Customers say sign-in sends them to the wrong site
Check the Supabase Site URL and redirect URLs (see [03 · Setup](03-setup.md)).

## A deploy broke the site
Vercel → **Deployments** → the last good one → **⋯ → Promote to Production** (instant rollback). Then fix the code and push again.

## A data request (access, correction, deletion)
1. Reply within **30 days**. Confirm the request comes from the account's email address.
2. **Access:** send them the "check a customer's plan" output, plus their payments: `select * from public.payments where user_id = (select id from auth.users where lower(email)='…');`
3. **Deletion:** remove them from any team (leave their row's `team_id` null). Delete `usage_daily` rows, then the profile, then the user in **Authentication → Users**. **Keep `payments` rows for 6 years**: they're accounting records. Tell the person you keep them, and why.

## A data breach (or suspected one)
1. Rotate secrets right away: the Supabase service key (Supabase → API → roll), the Flutterwave secret key and the webhook hash. Then update Vercel and redeploy.
2. Write down what happened, when, which data was affected and how many people.
3. If people's rights are at risk, **notify the Nigeria Data Protection Commission within 72 hours** and tell affected users without undue delay.
