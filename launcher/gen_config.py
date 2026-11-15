#!/usr/bin/env python3
"""Regenerate AiTV/js/config.js from AiTV/js/apps.json (embedded config for file:// TVs)."""
import json, pathlib
root = pathlib.Path(__file__).resolve().parent
cfg = json.loads((root / "AiTV/js/apps.json").read_text())
(root / "AiTV/js/config.js").write_text(
    "/* Generated from js/apps.json by gen_config.py — no XHR needed on the TV. */\n"
    "window.AITV_CONFIG = " + json.dumps(cfg, ensure_ascii=False, indent=4) + ";\n")
print("AiTV/js/config.js written")
