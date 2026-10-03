# 05 · Editing the app

`index.html` is the live app. The Image and Video tools are packed inside it as base64, so you can't edit them directly in `index.html`. Edit the copies in `src/` and pack them back in.

## Change the Image or Video tool

```bash
python3 tools/unpack.py      # refresh src/ from index.html (skip if src/ is already current)
# edit src/image.html or src/video.html
python3 tools/pack.py        # puts them back into index.html and checks the scripts
```

Open `index.html` in a browser to check, then commit and push. Vercel deploys `main` automatically, usually within a minute.

> When you give the app to another AI or developer, give them **`src/image.html` or `src/video.html`**, not `index.html`. Ask for the complete file back, then run `tools/pack.py`.

## Change the shell (sign-in, Plans & team, payments)

The shell is the normal HTML/CSS/JS in `index.html` outside the `var DOCS=` line. Edit it directly.

Key places:
- `PLANS = [...]`: fallback prices shown if the database can't be reached. The real prices are in the Supabase `plans` table.
- `payFor()`: opens Flutterwave checkout. `payment_options` sets which methods are offered.
- `confirmPayment()` / `resumePendingPayment()`: payment confirmation paths.
- `allow="clipboard-write; clipboard-read; microphone"` on the two frames. Keep `microphone`, or voice typing breaks.

## Change the server (`api/`)

These are plain Node.js functions with no dependencies. Vercel runs every file in `api/` that doesn't start with `_` as a URL.

## Change the database

Edit `supabase/imagend-billing.sql` and re-run it in Supabase SQL Editor. Keep it **re-runnable**: use `create … if not exists`, `create or replace function` and `on conflict do …`.

## Before pushing a payment-related change

1. Change one thing at a time.
2. Test with **test keys** (`_TEST`) in a Preview deployment if you can.
3. After deploying, do one real small payment and check it shows "✓ Payment confirmed".
