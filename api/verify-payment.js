// POST /api/verify-payment   { transaction_id }
// Header: Authorization: Bearer <Supabase access token>
// Called by the app right after Flutterwave checkout succeeds.
const { missingEnv, getUserFromToken, processTransaction } = require("./_lib");

module.exports = async (req, res) => {
  if (req.method !== "POST") return res.status(405).json({ ok: false, error: "POST only" });
  const missing = missingEnv();
  if (missing.length) return res.status(500).json({ ok: false, error: "Server not configured: " + missing.join(", ") });

  try {
    const token = String(req.headers.authorization || "").replace(/^Bearer\s+/i, "");
    const user = await getUserFromToken(token);
    if (!user) return res.status(401).json({ ok: false, error: "Please sign in again" });

    const body = typeof req.body === "string" ? JSON.parse(req.body || "{}") : req.body || {};
    const result = await processTransaction(body.transaction_id, user.id);
    return res.status(200).json({ ok: true, ...result });
  } catch (e) {
    return res.status(400).json({ ok: false, error: e.message || "Verification failed" });
  }
};
