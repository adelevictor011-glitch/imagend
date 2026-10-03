#!/usr/bin/env python3
"""Extract the Image and Video tools from index.html into src/ so you can edit them.

Imagend ships as ONE file (index.html). The Image and Video tools live inside it,
base64-encoded in the line that starts `var DOCS={image:"...",video:"..."}`.

Usage (from the repo root):  python3 tools/unpack.py
Then edit src/image.html or src/video.html and run tools/pack.py.
"""
import base64, re, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
html = (root / "index.html").read_text(encoding="utf-8")
line = next(l for l in html.split("\n") if "var DOCS={image:\"" in l)
for name, b64 in re.findall(r'(\w+):"([A-Za-z0-9+/=]+)"', line):
    out = root / "src" / f"{name}.html"
    out.parent.mkdir(exist_ok=True)
    out.write_text(base64.b64decode(b64).decode("utf-8"), encoding="utf-8")
    print("wrote", out.relative_to(root))
