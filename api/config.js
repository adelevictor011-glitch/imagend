// GET /api/config — hands the app the Flutterwave PUBLIC key (safe to expose).
// Switching test → live is just changing FLW_PUBLIC_KEY in Vercel; no code edits.
module.exports = (req, res) => {
  res.setHeader("Cache-Control", "no-store");
  res.status(200).json({
    flwPublicKey: process.env.FLW_PUBLIC_KEY || null,
    testMode: /_TEST/i.test(process.env.FLW_PUBLIC_KEY || ""),
  });
};
