// Shared helpers for Imagend payment functions.
// Files starting with "_" inside /api are NOT exposed as URLs by Vercel.

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const FLW_SECRET = process.env.FLW_SECRET_KEY;

function missingEnv() {
  const need = ["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "FLW_SECRET_KEY"];
  return need.filter((k) => !process.env[k]);
}

// Who is calling? Checks the Supabase login token the browser sends.
async function getUserFromToken(token) {
  if (!token) return null;
  const r = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${token}` },
  });
  if (!r.ok) return null;
  const u = await r.json();
  return u && u.id ? u : null;
}

// Ask Flutterwave directly whether a transaction really succeeded.
async function flwVerify(transactionId) {
  const id = String(transactionId || "").replace(/[^0-9]/g, "");
  if (!id) throw new Error("missing transaction id");
  const r = await fetch(`https://api.flutterwave.com/v3/transactions/${id}/verify`, {
    headers: { Authorization: `Bearer ${FLW_SECRET}` },
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok || j.status !== "success" || !j.data) {
    throw new Error("Flutterwave could not verify this transaction");
  }
  return j.data;
}

// tx_ref format created by the app: imgnd_<plan>_<cycle>_<userId>_<timestamp>
function parseTxRef(ref) {
  const parts = String(ref || "").split("_");
  if (parts.length !== 5 || parts[0] !== "imgnd") return null;
  const [, plan, cycle, userId] = parts;
  if (!["creator", "studio"].includes(plan)) return null;
  if (!["monthly", "yearly"].includes(cycle)) return null;
  if (!/^[0-9a-f-]{36}$/i.test(userId)) return null;
  return { plan, cycle, userId };
}

// Record the payment and switch on the plan (database checks price + duplicates).
async function applyPayment({ userId, plan, cycle, tx }) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/apply_payment`, {
    method: "POST",
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      p_user: userId,
      p_plan: plan,
      p_cycle: cycle,
      p_tx_id: String(tx.id),
      p_tx_ref: tx.tx_ref,
      p_amount: Number(tx.amount),
      p_currency: tx.currency,
    }),
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error((j && j.message) || "Could not apply payment");
  return j;
}

// Full check: verified by Flutterwave, successful, reference is ours, then apply.
async function processTransaction(transactionId, expectedUserId) {
  const tx = await flwVerify(transactionId);
  if (tx.status !== "successful") throw new Error(`Payment status is "${tx.status}"`);
  const ref = parseTxRef(tx.tx_ref);
  if (!ref) throw new Error("Not an Imagend payment");
  if (expectedUserId && ref.userId !== expectedUserId) throw new Error("Payment belongs to another account");
  const result = await applyPayment({ userId: ref.userId, plan: ref.plan, cycle: ref.cycle, tx });
  return { ...result, plan: ref.plan, cycle: ref.cycle };
}

module.exports = { missingEnv, getUserFromToken, flwVerify, parseTxRef, applyPayment, processTransaction };
