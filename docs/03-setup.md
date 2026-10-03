# 03 · Setup and settings

Every setting outside the code, in one place. **Never put secret keys in this repo.** They belong only in Vercel.

## Vercel (project `imagend`)

**Domains** (Settings → Domains)
- `www.imagendai.com` is the **primary** domain that serves the site.
- `imagendai.com` **redirects (308)** to `www`.
- `imagend.vercel.app` still works.

**Environment variables** (Settings → Environment Variables, Production + Preview)

| Name | Secret? | Where to get it |
|---|---|---|
| `SUPABASE_URL` | no | `https://bkrrrnpdopanjcaqrsce.supabase.co` |
| `SUPABASE_SERVICE_ROLE_KEY` | **yes** | Supabase → Project Settings → API → `service_role` |
| `FLW_PUBLIC_KEY` | no (shown to browsers) | Flutterwave → Settings → API Keys (Live) |
| `FLW_SECRET_KEY` | **yes** | Flutterwave → Settings → API Keys (Live) |
| `FLW_SECRET_HASH` | **yes** | A long password you invent. It must match Flutterwave's webhook "Secret hash" |
| `TRIAL_HASH_SECRET` | **yes** (optional) | Another long password you invent, used to code IPs for the free trial. If missing, the service key is used. Once set, **don't change it**: old trial records would stop matching |

After changing any variable: **Deployments → latest → ⋯ → Redeploy**. Vercel only reads variables at deploy time.

**Test mode vs live:** a test public key contains `_TEST`. The plans screen shows a yellow "Test mode" banner when it does.

## Supabase

- **Authentication → URL Configuration**
  - Site URL: `https://imagendai.com`
  - Redirect URLs: `https://imagendai.com/**`, `https://www.imagendai.com/**`, `https://imagend.vercel.app/**`
  - `/**` means "this address and any page under it".
- **Authentication → Providers → Google:** enabled.
- **Database:** run `supabase/imagend-billing.sql` in **SQL Editor**. Re-run the whole file whenever it changes; it is safe to re-run and never deletes your data. (The 3 Oct evening update added the free trial, so it must be re-run once.)
- **Owner (free, unlimited) emails** are in table `comp_accounts`. See [Runbooks](04-runbooks.md) to add one.

## Flutterwave (Live mode)

- **Payment methods:** card, bank transfer, OPay and USSD switched on. PayPal is off. The app requests `card,banktransfer,opay,ussd,account,nqr`.
- **Settings → Webhooks**
  - URL: **`https://www.imagendai.com/api/flutterwave-webhook`** (with **www**; the bare domain redirects and the webhook fails)
  - Secret hash: same value as `FLW_SECRET_HASH`
  - ✅ JSON format · ✅ Retries · ✅ v3 webhooks · ✅ Resend from dashboard · ☐ Failed transactions · ☐ Refunds · ☐ Subaccount wallet funding

## GoDaddy DNS (imagendai.com)

Connected to Vercel with **DNS records, not nameservers**, so email keeps working.

| Type | Name | Value | Notes |
|---|---|---|---|
| A | @ | Vercel's IP (shown in Vercel → Domains) | Was "WebsiteBuilder Site" |
| CNAME | www | Vercel's CNAME target (shown in Vercel → Domains) | Was `imagendai.com.` |
| MX, TXT (SPF, `_dmarc`), CNAME `email` / `*._domainkey` / `_domainconnect`, SRV `_autodiscover`, NS, SOA | | | **Don't touch: email and domain** |

## GitHub

- Repo `adelevictor011-glitch/imagend`, branch `main`. Every push to `main` deploys to production automatically.
- **Recommended:** Settings → General → Danger Zone → **Change visibility → Private**. Vercel keeps deploying from private repos.
