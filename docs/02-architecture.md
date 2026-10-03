# 02 · How Imagend works

Think of Imagend like the dealership:

- **The showroom floor** (`index.html` in the browser) is where customers work. Prompts are written right there, on their device.
- **The service desk records** (Supabase) hold who the customer is, their plan and how many jobs they've used today.
- **The cashier** (Flutterwave) takes payments.
- **The back office** (`api/` on Vercel) only acts after phoning the cashier to confirm a payment is real.

```mermaid
flowchart LR
  U[User's browser<br/>index.html] -- Google sign-in --> SB[(Supabase<br/>auth + database)]
  U -- get_my_status / consume_generation / redeem_code / teams --> SB
  U -- checkout --> FW[Flutterwave]
  FW -- redirect back with tx id --> U
  U -- POST /api/verify-payment --> API[Vercel api/]
  FW -- webhook charge.completed --> API
  API -- verify transaction --> FW
  API -- apply_payment (service key) --> SB
```

## The parts

### 1. The app: `index.html`
One file with three parts:

- **Shell:** sign-in screen, Plans & team screen, Flutterwave checkout, payment confirmation and resume, and the portal tab between Image and Video.
- **Image tool** and **Video tool:** each runs inside its own frame. Their source is packed into `index.html` as base64. Editable copies are in `src/`.
  - The prompt engine runs **entirely in the browser**: idea → internal representation → one serializer per model.
  - The library, history, settings and guest usage are stored in the browser (localStorage).
  - Voice typing uses the browser's speech recognition and needs `allow="microphone"` on the frames.

The shell passes the Supabase session into each tool with `postMessage`. Tools ask the shell to open Plans (`IMAGEND_UPGRADE`), sign in (`IMAGEND_SIGNIN`) or sign out (`IMAGEND_SIGNOUT`). The shell tells tools to refresh after a payment or team change (`IMAGEND_REFRESH`).

### 2. The database: Supabase
Set up by `supabase/imagend-billing.sql`.

| Table | Holds |
|---|---|
| `plans` | Free / Creator / Studio: daily limit and prices. **Prices and limits live here.** |
| `profiles` | One row per user: `plan`, `plan_until`, `beta_until`, `team_id`, counters |
| `usage_daily` | Prompts used per user per day (Lagos date) |
| `teams` | Team name, owner, 6-character invite code |
| `payments` | One row per Flutterwave transaction (`tx_id` is unique, so it can't be credited twice) |
| `comp_accounts` | Owner emails with free unlimited access |

Users can **read** their own profile and payments. They **cannot write** to anything. All changes go through these functions:

| Function | Who can call it | Does |
|---|---|---|
| `get_my_status()` | signed-in user | Returns plan, limit, used today and team |
| `consume_generation(kind)` | signed-in user | Counts one prompt, refuses if over today's limit |
| `redeem_code(code)` | signed-in user | BETATESTER → Studio until 31 Oct 2026 |
| `create_team`, `join_team`, `leave_team`, `get_team_members` | signed-in user | Teams |
| `apply_payment(...)` | **server only** (service role) | Checks the amount matches the price, records the payment, extends the plan |

**How the effective plan is decided:** owner email → unlimited; otherwise the **higher** of an active beta code (Studio) and an active paid plan; otherwise Free. The paid plan is stored separately, so it reappears when the beta ends. On a team, the limit is the **sum of every member's limit**, and usage is the sum of everyone's usage that day.

### 3. Payments: Flutterwave + `api/`

| File | URL | Job |
|---|---|---|
| `api/config.js` | `GET /api/config` | Gives the app the **public** key (`FLW_PUBLIC_KEY`) |
| `api/verify-payment.js` | `POST /api/verify-payment` | Called by the app with `transaction_id` or `tx_ref`. Checks the signed-in user, verifies with Flutterwave, applies the plan |
| `api/flutterwave-webhook.js` | `POST /api/flutterwave-webhook` | Flutterwave's backup notice. Checks the `verif-hash` header, verifies, applies |
| `api/_lib.js` | (not a URL) | Shared helpers |

**Payment reference format:** `imgnd_<plan>_<cycle>_<userId>_<timestamp>`, e.g. `imgnd_creator_monthly_<uuid>_1790000000000`. The server reads the plan, cycle and user **only from Flutterwave's verified record**, never from the browser. The database then checks that the amount matches the price.

**Three ways a payment gets confirmed (any one is enough):**
1. **Checkout callback**: card payments in the page.
2. **Redirect back**: after OPay or bank transfer, Flutterwave sends the user to `/?paid=1&transaction_id=…`.
3. **Resume on next visit**: the app remembers each payment it starts and re-checks it by reference next time the user opens Imagend.

The **webhook** covers anyone who never comes back at all.

## Security model and known limits

- ✅ Plans, limits and payments are decided by the database and server. Faking them in the browser doesn't work.
- ✅ Card and bank details never touch Imagend.
- ✅ Secret keys live only in Vercel environment variables. The Supabase **anon** key in `index.html` is public by design and is protected by row-level security.
- ⚠️ The prompt engine runs in the browser, so a technical user could edit the page to read prompts past the daily limit. The limit stops normal use, and paid features and payments can't be faked. Moving the engine to the server would close this, at the cost of speed and server bills.
- ⚠️ Team members can see each other's email, plan and daily usage. This is stated in the Terms and Privacy Policy.
