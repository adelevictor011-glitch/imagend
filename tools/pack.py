#!/usr/bin/env python3
"""Put src/image.html and src/video.html back inside index.html.

Usage (from the repo root):  python3 tools/pack.py
Then open index.html locally to check, commit, and push. Vercel deploys main automatically.
"""
import base64, re, pathlib, subprocess, sys
root = pathlib.Path(__file__).resolve().parent.parent
idx = root / "index.html"
html = idx.read_text(encoding="utf-8")
lines = html.split("\n")
i = next(n for n, l in enumerate(lines) if "var DOCS={image:\"" in l)
for name in ("image", "video"):
    src = (root / "src" / f"{name}.html").read_text(encoding="utf-8")
    b64 = base64.b64encode(src.encode("utf-8")).decode()
    lines[i], count = re.subn(rf'({name}:")[A-Za-z0-9+/=]+(")', lambda m: m.group(1) + b64 + m.group(2), lines[i], count=1)
    if count != 1:
        sys.exit(f"could not find the {name} tool inside index.html")
idx.write_text("\n".join(lines), encoding="utf-8")
print("packed src/image.html and src/video.html into index.html")
# Optional syntax check if Node.js is installed
try:
    subprocess.run(["node", "-e", "const h=require('fs').readFileSync('index.html','utf8');for(const [,s] of h.matchAll(/<script>([\\s\\S]*?)<\\/script>/g)) new Function(s);console.log('script syntax OK')"], cwd=root, check=True)
except FileNotFoundError:
    pass
