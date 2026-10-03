// POST /api/claim-trial   { device_id }
// Header: Authorization: Bearer <Supabase access token>
// Starts the free 14-day Creator trial. Rules live in public.apply_trial (Supabase):
// one per account, never after a payment, one per device, at most 2 per network in 30 days.
// Raw IP addresses and device IDs are never stored: only keyed HMAC-SHA256 digests.
const crypto = require("crypto");
const { getUserFromToken } = require("./_lib");

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
// A separate secret is better (TRIAL_HASH_SECRET); falls back to the service key so it works without setup.
const HASH_KEY = process.env.TRIAL_HASH_SECRET || SERVICE_KEY;

function clientIp(req) {
  const h = req.headers;
  const raw = String(h["x-vercel-forwarded-for"] || h["x-real-ip"] || h["x-forwarded-for"] || "").split(",")[0].trim();
  if (!raw) return "";
  // IPv6: phones rotate addresses inside their /64, so compare the /64 network instead.
  if (raw.includes(":")) {
    const full = expandV6(raw);
    return full ? full.split(":").slice(0, 4).join(":") + "::/64" : raw.toLowerCase();
  }
  return raw;
}
function expandV6(ip) {
  try {
    let [head, tail] = ip.toLowerCase().split("::");
    const h = head ? head.split(":") : [], t = tail !== undefined && tail ? tail.split(":") : [];
    const fill = tail !== undefined ? Array(8 - h.length - t.length).fill("0") : [];
    const parts = [...h, ...fill, ...t];
    return parts.length === 8 ? parts.map((p) => p.padStart(4, "0")).join(":") : null;
  } catch (e) { return null; }
}
const digest = (kind, v) => crypto.createHmac("sha256", HASH_KEY).update(kind + ":" + v).digest("hex");

const MESSAGES = {
  already_claimed: "You've already used your free trial on this account.",
  paid_before: "The free trial is for new customers. Your account has had a paid plan before.",
  plan_active: "You already have an active plan, so there's nothing to unlock yet.",
  device_used: "A free trial has already been used on this device. Pick a plan to keep going.",
  network_used: "Too many free trials have been started from this network recently. Pick a plan, or try again from your own connection.",
};

module.exports = async (req, res) => {
  if (req.method !== "POST") return res.status(405).json({ ok: false, error: "POST only" });
  if (!SUPABASE_URL || !SERVICE_KEY) return res.status(500).json({ ok: false, error: "Server not configured" });

  try {
    const token = String(req.headers.authorization || "").replace(/^Bearer\s+/i, "");
    const user = await getUserFromToken(token);
    if (!user) return res.status(401).json({ ok: false, error: "Please sign in again" });

    const body = typeof req.body === "string" ? JSON.parse(req.body || "{}") : req.body || {};
    const ip = clientIp(req);
    if (!ip) return res.status(400).json({ ok: false, error: "Couldn't confirm your network. Try again." });
    const device = String(body.device_id || "").slice(0, 100);

    const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/apply_trial`, {
      method: "POST",
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({ p_user: user.id, p_ip_hash: digest("ip", ip), p_device_hash: device ? digest("dev", device) : "" }),
    });
    const j = await r.json().catch(() => ({}));
    if (!r.ok) return res.status(500).json({ ok: false, error: (j && j.message) || "Couldn't start the trial" });
    if (!j.ok) return res.status(200).json({ ok: false, reason: j.reason, error: MESSAGES[j.reason] || "This account can't start a trial." });
    return res.status(200).json({ ok: true, until: j.until });
  } catch (e) {
    return res.status(400).json({ ok: false, error: e.message || "Couldn't start the trial" });
  }
};
