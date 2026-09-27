// POST /api/flutterwave-webhook
// Flutterwave calls this after every payment, even if the customer closed the tab.
// Set the same "Secret hash" in Flutterwave → Settings → Webhooks and in Vercel as FLW_SECRET_HASH.
const { missingEnv, processTransaction } = require("./_lib");

module.exports = async (req, res) => {
  if (req.method !== "POST") return res.status(405).end();
  const hash = process.env.FLW_SECRET_HASH;
  if (!hash || missingEnv().length) return res.status(500).json({ error: "Server not configured" });
  if (req.headers["verif-hash"] !== hash) return res.status(401).end(); // not from Flutterwave

  const body = typeof req.body === "string" ? JSON.parse(req.body || "{}") : req.body || {};
  const data = body.data || {};
  const event = body.event || body["event.type"];

  if (event !== "charge.completed" || data.status !== "successful") {
    return res.status(200).json({ received: true, ignored: true });
  }
  try {
    // Re-check with Flutterwave's API — never trust the webhook body alone.
    const result = await processTransaction(data.id, null);
    return res.status(200).json({ received: true, ...result });
  } catch (e) {
    // 200 so Flutterwave doesn't retry forever on a payment that isn't ours / is invalid.
    return res.status(200).json({ received: true, error: e.message });
  }
};
