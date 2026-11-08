#!/usr/bin/env python3
"""Embed colony.wasm into the single-file page.
usage: embed.py colony.wasm web/template.html index.html
"""
import base64
import subprocess
import sys

wasm, template, out = sys.argv[1:4]
page = open(template, encoding="utf-8").read()
if "__WASM_BASE64__" not in page or "__BUILD_ID__" not in page:
    sys.exit("template is missing a placeholder")
try:
    commit = subprocess.check_output(
        ["git", "rev-parse", "--short", "HEAD"], text=True
    ).strip()
except (OSError, subprocess.CalledProcessError):
    commit = "uncommitted"
b64 = base64.b64encode(open(wasm, "rb").read()).decode("ascii")
page = page.replace("__BUILD_ID__", commit)
page = page.replace("__WASM_BASE64__", b64)
open(out, "w", encoding="utf-8").write(page)
print(f"wrote {out} ({len(b64)} base64 chars, source {commit})")
