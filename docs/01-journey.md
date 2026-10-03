# 01 · The journey: how Imagend got here

A dated log of what was built, what broke, and why each decision was made. Newest at the bottom. Commit hashes link the story to the code.

---

## June 2026: Prysm, the prototype

**Problem:** people describe images in plain words, but each AI image model rewards a different "dialect" of prompt. The gap shows up as re-rolls, off-brief shots and wasted credits.

**What was built:** *Prysm*, a single HTML file with no backend.

- **Decisions made up front**
  - Target **Midjourney, Nano Banana / GPT-Image and Ideogram** first.
  - **Rule-based templates, not live AI rewrites.** That means no per-prompt AI cost, it is instant, and it works offline.
  - **Ship as one HTML file**: no build step, so it deploys anywhere.
- **Architecture:** idea → one internal representation of the idea → a separate *serializer* per model that writes it in that model's dialect.
- **Added over several rounds:** five categories (poster, brand, UGC, logo, promo); a style rail; guarded "Surprise me"; locks; a 6-card history rail; **Flux** and **Recraft** (5 image models); reference-image mode; a 28-style aesthetic library; quality finish tokens.
- **Rebrand to Imagend**, with an iris/aperture mark and a violet-magenta-gold palette, plus a premium visual overhaul.
- **First deploy on Vercel.** The first deploy gave a 404 because the file wasn't named exactly `index.html` at the repo root. Lesson: Vercel serves `index.html` by default.

**Strategy notes from this stage:** the long-term risk is that models keep getting better at plain prompts (the "melting iceberg"). The defensible value is taste, brand consistency and speed, so lead marketing with speed, ease and output quality, not the internal mechanism.

## July 2026: accounts, video, monetisation groundwork

- Added a **negatives toggle**, a robust **clipboard fallback** for embedded frames, social meta tags and a fix for a script-timing bug in lazy-loaded frames.
- **Video world** was added inside the app; a separate video manager was later linked from a portal tab.
- **Supabase + Google sign-in.** The outer shell handles sign-in and passes the session into the Image and Video tools.
- **BETATESTER code** and a **"5 free prompts" gate**. *(Both were later found to be enforced only in the browser; see 27 Sep.)*
- **Payment provider chosen: Flutterwave.** Stripe isn't directly available to Nigerian merchants, and Lemon Squeezy was too complex. A webhook was written but **never deployed**.
- Instagram content strategy drafted.

## 26 September 2026: brand assets and own domain

- **Logo**: aperture mark plus wordmark, drawn as vector. Delivered as SVG and transparent PNG in dark-mode, light-mode and icon versions.
- **Domain `imagendai.com`** (registered at GoDaddy) pointed at Vercel using **DNS Records, not Vercel nameservers**, so GoDaddy email keeps working.
  - In GoDaddy, only two records changed: the `@` A record (from "WebsiteBuilder Site" to Vercel's IP) and the `www` CNAME (to Vercel).
  - MX, SPF/DMARC/DKIM, autodiscover, NS and SOA records were left untouched.
- **Sign-in kept returning to `imagend.vercel.app`.** Cause: Supabase's Site URL still pointed at the old address. Fix: Site URL `https://imagendai.com`, plus redirect URLs `https://imagendai.com/**`, `https://www.imagendai.com/**` and `https://imagend.vercel.app/**`. The app's own code was already correct.
- `og:url` corrected from `imagend.app` to `imagendai.com`.

## 27 September 2026: the paywall was fake, so it was rebuilt properly

**Found in an audit:**
1. The **"Upgrade to Pro" button only showed a "coming soon" pop-up**. No payment code was live, and Vercel had no keys.
2. **BETATESTER entered on the sign-in screen was saved but never applied.** Also, the Image and Video tools each kept their own redeemed-code record.
3. **Pro status and counters lived in the browser.** Anyone could give themselves Pro from the browser console.

**Quick fix first:** the BETATESTER code is now applied after sign-in and shared by both tools.

**Pricing decided:**

| Plan | Daily prompts | Monthly | Yearly (10× monthly) |
|---|---|---|---|
| Free | 2 | ₦0 | ₦0 |
| Creator | 5 | ₦5,000 | ₦50,000 |
| Studio | 20 | ₦16,000 | ₦160,000 |

- **BETATESTER** gives Studio level until 31 Oct 2026.
- **Owner accounts** are unlimited.
- **Teams** pool their daily limits, but each member signs in and pays individually.

**Built (commit `63f93d6`):**

- **Database** (`supabase/imagend-billing.sql`)
  - Plans, daily usage (reset at midnight Lagos time), teams, owner accounts and a payments ledger.
  - Users can **read** their own data but **can't change** plans or counters. Every change goes through server-side functions.
  - `apply_payment` checks the price and refuses duplicates.
- **Server** (`api/`)
  - `verify-payment`: called by the app after checkout.
  - `flutterwave-webhook`: Flutterwave's backup notice.
  - `config`: hands the app the public key.
  - Every payment is re-confirmed with Flutterwave's API before a plan is activated.
- **App**
  - Plans & team screen with a Monthly/Yearly switch.
  - Flutterwave checkout.
  - Daily-limit gates in both tools.
  - Account bar showing the plan and prompts left.
- **Testing:** done before going live against a real Postgres copy of the schema and a headless browser with a simulated Flutterwave.
- The SQL was run in Supabase and the site went live with free tiers and the beta code working.

## 28 September 2026: keys and launch content

- Flutterwave keys and the Supabase service key were added to Vercel. The key added was **live**, not test.
- **Launch content**
  - WhatsApp greeting messages, including a free-offer and Lazy Guide walkthrough version.
  - LinkedIn teaser and launch posts.
  - Posting times based on Buffer's 2026 data: weekdays 3–8pm, Wednesday strongest.
- A **Lazy Guide simulator form** (a separate artifact) and a two-slide problem brief for briefing developers and AIs.

## 1 October 2026: live payments, first customer, first bug

- Flutterwave account **activated**.
- Checkout now offers **card, bank transfer, OPay, USSD, pay-with-account and NQR** (commit `d562811`). Methods also have to be switched on in the Flutterwave dashboard.
- **First real payment:** ₦5,000 Creator, paid with OPay. Flutterwave showed it as successful, but **Imagend never heard about it**.
  - OPay completes in its own app, so the checkout callback never fired.
  - The webhook wasn't set up yet.
  - **Fix (commit `2e48f5c`):**
    - Checkout now redirects back to the site.
    - The app remembers each payment it starts and re-checks it by reference on the next visit, using Flutterwave's `verify_by_reference`.
  - That first customer was credited manually with `apply_payment` in the SQL Editor (see [Runbooks](04-runbooks.md)).
- **Webhook settings chosen:**
  - JSON format, retries, v3 webhooks and dashboard resend: **on**.
  - Failed transactions, refunds and subaccount hooks: **off**.

## 2 October 2026: webhook "not reaching your server"

- **Cause:** in Vercel, `imagendai.com` **redirects (308) to `www.imagendai.com`**. Browsers follow the redirect; Flutterwave's webhook doesn't.
- **Fix:** webhook URL changed to **`https://www.imagendai.com/api/flutterwave-webhook`**.
- **Lesson:** server-to-server URLs must use the domain that actually serves, which is **www**.

## 3 October 2026: voice typing, legal pages, documentation

- **Voice typing** (commit `80f22c7`)
  - A mic button on the idea, Lazy Guide and category text boxes.
  - Speech goes into a review sheet and only fills the box after **"Use this text"**.
  - Uses the browser's built-in speech recognition. The mic button is hidden where that isn't supported.
- **Legal pages** live at `/terms`, `/privacy`, `/refunds` and `/acceptable-use`.
  - The sign-in screen already linked to `/terms` and `/privacy`, which until now returned 404.
  - Refund policy: full refund within 7 days if fewer than 5 prompts used. Duplicate or failed charges are always fixed.
- **Licence changed from MIT to "all rights reserved"**, and the repo should be made private. See [06](06-legal-and-compliance.md).
- This documentation, editable sources in `src/`, and `tools/pack.py` / `tools/unpack.py`.
- **Image model review:**
  - Keep all five, updated to current versions (Midjourney V8.2, Nano Banana 2/Pro, Ideogram 4.0, FLUX.2, Recraft V4.1).
  - Recommended additions: GPT Image 2.5 and Seedream 5.0.
  - *Status: awaiting decision.*

---

### Lessons worth remembering

1. **Anything enforced only in the browser isn't enforced.** Plans, limits and payments must be decided by the server or database.
2. **Every payment needs two ways home:** the in-page confirmation and the webhook. Wallet apps such as OPay often skip the first.
3. **Redirects break server-to-server calls.** Use the final domain (`www`) for webhooks.
4. **Check the domain points everywhere it needs to:** DNS, the Supabase Site URL and redirect list, the webhook URL and `og:url`.
5. **Test with a fake first, then one real payment, before announcing.**
