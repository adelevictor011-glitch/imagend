# 06 · Legal, privacy and intellectual property

> These documents and this checklist were drafted from public guidance on Nigerian and international law. They are **not legal advice**. Before you scale (or take investment), have a Nigerian lawyer review the Terms, Privacy Policy and Refund Policy. It usually takes one session.

## What's live on the site

| Page | URL | Covers |
|---|---|---|
| Terms of Service | `/terms` | Service scope (prompts only, no images), accounts, plans, no auto-renewal, teams, ownership of prompts, our IP, liability, Nigerian law + overseas consumer rights |
| Privacy Policy | `/privacy` | NDPA 2023 + GDPR: what's collected, why, lawful basis, providers, transfers, retention, rights, NDPC complaints, breach notice |
| Refund Policy | `/refunds` | 7-day refund if fewer than 5 prompts used; duplicate or failed charges always fixed; FCCPA rights kept |
| Acceptable Use | `/acceptable-use` | Banned content (minors, non-consensual deepfakes, impersonation, fraud, IP theft, hate) and misuse of the service |

The sign-in screen and the Plans screen link to these pages. **Before relying on them, fill in Made by Youni Ltd's registered address** (see below).

## Nigeria: data protection (NDPA 2023 + GAID 2025)

- [ ] **Privacy notice before collecting data:** done (`/privacy`). Covers identity and contact, purposes, lawful basis, recipients, retention, rights and the right to complain to the NDPC (NDPA s.27).
- [ ] **Registration with the NDPC as a "data controller of major importance."** Thresholds are based on how many people's data you process in 6 months. Summaries of the current guidance list **200–999 (ordinary-high, ~₦10,000)**, **1,000–4,999 (extra-high, ~₦100,000)** and **5,000+ (ultra-high, ~₦250,000)**. *Confirm the current tiers and fees on ndpc.gov.ng.* Imagend will likely cross 200 users within 6 months, so plan to register.
- [ ] **Compliance Audit Return (CAR):** required for the higher tiers, filed annually (by 31 March, through a licensed Data Protection Compliance Organisation). Late filing attracts a surcharge.
- [ ] **Data Protection Officer:** required for organisations of major importance. As a solo founder you can take the role yourself, but it needs the Commission's credential process. Check current rules.
- [ ] **Breach notification:** 72 hours to notify the NDPC (NDPA s.40). Procedure in [Runbooks](04-runbooks.md).
- [ ] **Cross-border transfers** (Supabase, Vercel, Google and Flutterwave infrastructure abroad): rely on providers' contractual safeguards (NDPA s.41–43). Keep a list of providers and where they store data.
- [ ] **Answer data requests within 30 days:** procedure in [Runbooks](04-runbooks.md).

## Nigeria: consumer protection (FCCPA 2018)

- Blanket "no refund" clauses can be unenforceable. Consumers can get a refund when a service isn't delivered as agreed. Imagend's Refund Policy covers this, and the Terms say statutory rights are never excluded.
- Terms must be clear and easy to understand. That's why each page starts with a short "the short version" box.

## Overseas users

- **EU / UK (GDPR, UK GDPR):** the Privacy Policy already covers lawful bases, rights and complaining to a local authority. If EU or UK users become significant, consider appointing an EU/UK representative (GDPR Art. 27) and signing providers' data processing agreements (Supabase, Vercel and Google offer standard ones).
- **Consumers abroad** keep their mandatory local rights. The Terms say so.
- **Payments in naira only** keep things simple. If you add USD pricing, revisit tax (VAT/GST) rules for digital services in those countries.

## Protecting the product and brand

- [x] **Licence changed from MIT to "All rights reserved"** (`LICENSE`). Under MIT, anyone could legally copy, modify and sell Imagend. Copies already downloaded under MIT stay MIT, but every version from now on is protected.
- [ ] **Make the GitHub repo private** (Settings → General → Change visibility). The code is still visible to anyone who opens the site, but the full history, docs, SQL and server code won't be.
- [ ] **Register the "Imagend" trademark** with the Trademarks, Patents and Designs Registry (Federal Ministry of Industry, Trade and Investment, Nigeria), in classes **9** (software) and **42** (SaaS). Register in other countries before you market there.
- [ ] **Register the business name / confirm Imagend is under Made by Youni Ltd** at the CAC, and keep the registered office address up to date. Add it to the legal pages.
- [ ] **Keep the domain on auto-renew** at GoDaddy, with registrar lock on.
- [ ] **Copyright:** the code and designs are protected automatically when created. Keep this repo's history as your dated proof of authorship.

## Content safety

- The Acceptable Use Policy bans sexual content involving minors, non-consensual intimate imagery and deepfakes, impersonation and fake documents, fraud, IP infringement, hate and deceptive political content.
- Imagend writes prompts only, and the downstream AI tools apply their own filters. Still, act on reports sent to hello@imagendai.com, and keep a simple log of reports and actions.
- If you ever add server-side generation, add input filtering before launch.

## Open items for Zee

1. **Registered address:** the legal pages say "Lagos, Nigeria". CAC-registered companies have a registered office; add the full address when available.
2. **Lawyer review** of `/terms`, `/privacy` and `/refunds`.
3. **NDPC registration** once you approach 200 users in a 6-month window.
4. **Trademark filing** for "Imagend".
5. **Make the repo private.**
6. **Business email:** set up `hello@imagendai.com` on the GoDaddy mailbox. The legal pages use it.
