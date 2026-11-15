#!/usr/bin/env bash
# Static + behavioural validation for the launcher, no TV required.
#
# Usage:   scripts/validate.sh
# Checks:  JS syntax, apps.json parses, config.xml is well-formed, wallpaper
#          bundle stays inside the size budget, and a headless-Chrome run of the
#          remote-key state machine (arrows / OK / Back) at 1080p and 720p.
set -uo pipefail

cd "$(dirname "$0")/.."
FAILED=0
ok()   { printf "  \033[32mok\033[0m    %s\n" "$1"; }
bad()  { printf "  \033[31mFAIL\033[0m  %s\n" "$1"; FAILED=$((FAILED + 1)); }
head_() { printf "\n%s\n" "$1"; }

# ---------------------------------------------------------------- syntax -----
head_ "syntax"
if command -v node >/dev/null 2>&1; then
  for f in AiTV/js/app.js HomeKey/js/main.js; do
    if node --check "$f" >/dev/null 2>&1; then ok "node --check $f"; else bad "node --check $f"; fi
  done
else
  echo "  (node not found — JS syntax check skipped)"
fi

# ---------------------------------------------------------------- config -----
head_ "configuration"
if python3 -c "import json,sys; json.load(open('AiTV/js/apps.json'))" 2>/dev/null; then
  ok "AiTV/js/apps.json is valid JSON"
else
  bad "AiTV/js/apps.json is not valid JSON"
fi

if python3 - <<'PY'
import xml.etree.ElementTree as ET
for p in ("AiTV/config.xml", "HomeKey/config.xml"):
    ET.parse(p)
PY
then ok "config.xml files are well-formed XML"; else bad "config.xml XML error"; fi

if python3 - <<'PY'
import xml.etree.ElementTree as ET
ns = {"w": "http://www.w3.org/ns/widgets", "t": "http://tizen.org/ns/widgets"}
expect = {"AiTV/config.xml": "AiTVLaunch.AiTV", "HomeKey/config.xml": "AiTVKeyApp.HomeKey"}
bad = []
for path, app_id in expect.items():
    root = ET.parse(path).getroot()
    if root.tag != "{http://www.w3.org/ns/widgets}widget":
        bad.append(f"{path}: root is not <widget>")
    if not root.get("version"):
        bad.append(f"{path}: widget@version missing")
    content = root.find("w:content", ns)
    if content is None or not (content.get("src") or "").endswith("index.html"):
        bad.append(f"{path}: <content src=index.html> missing")
    icon = root.find("w:icon", ns)
    if icon is None:
        bad.append(f"{path}: <icon> missing")
    app = root.find("t:application", ns)
    if app is None:
        bad.append(f"{path}: <tizen:application> missing")
    else:
        if app.get("id") != app_id:
            bad.append(f"{path}: tizen:application@id = {app.get('id')!r}, expected {app_id!r}")
        if not app.get("required_version"):
            bad.append(f"{path}: tizen:application@required_version missing")
        if "." not in app.get("id", "") or not app.get("id")[0].isalpha():
            bad.append(f"{path}: app id must contain a dot and start with a letter")
    if root.find("t:profile", ns) is None:
        bad.append(f"{path}: <tizen:profile name=tv-samsung> missing")
print("\n".join(bad))
raise SystemExit(1 if bad else 0)
PY
then ok "Tizen app shells declare id / version / content / icon / profile"; else bad "Tizen config.xml content check"; fi

# ------------------------------------------------------------- wallpapers ----
head_ "assets"
if python3 - <<'PY'
import os, sys
try:
    from PIL import Image
except ImportError:
    print("  (Pillow missing — image dimension check skipped)"); raise SystemExit(0)
total = 0
problems = []
wdir = "AiTV/wallpapers"
files = sorted(f for f in os.listdir(wdir) if f.lower().endswith(".jpg"))
for name in files:
    p = os.path.join(wdir, name)
    size = os.path.getsize(p)
    total += size
    with Image.open(p) as im:
        if im.format != "JPEG" or im.size != (960, 540):
            problems.append("%s: %s %s" % (name, im.format, im.size))
if len(files) < 4:
    problems.append("need at least 4 wallpapers, found %d" % len(files))
if total > 12 * 1024 * 1024:
    problems.append("wallpapers dir is %.1f MB (budget 12 MB)" % (total / 1048576.0))
if problems:
    print("\n".join(problems)); raise SystemExit(1)
print("  %d wallpapers, %.2f MB total, all 960x540 JPEG (fast decode, low memory on Tizen 2.4)" % (len(files), total / 1048576.0))
PY
then ok "wallpaper bundle passes checks"; else bad "wallpaper bundle"; fi

# --------------------------------------------------------------- behaviour ---
CHROME="${CHROME_BIN:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
head_ "remote-control state machine (headless Chrome)"
if [ -x "$CHROME" ]; then
  PORT=$(python3 - <<'PY'
import socket
s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()
PY
)
  python3 -m http.server "$PORT" --bind 127.0.0.1 --directory AiTV >/dev/null 2>&1 &
  SERVER_PID=$!
  trap 'kill $SERVER_PID 2>/dev/null || true' EXIT
  sleep 1

  run_case() {
    local keys="$1" want="$2" label="${3:-keys=$1}"
    local w="${4:-1920}" h="${5:-1080}"
    local title
    title=$("$CHROME" --headless=new --disable-gpu --hide-scrollbars \
      --window-size="${w},${h}" --virtual-time-budget=9000 --dump-dom \
      "http://127.0.0.1:${PORT}/index.html?instant=1&keys=${keys}" 2>/dev/null \
      | grep -o "<title>[^<]*</title>" | head -1)
    if printf '%s' "$title" | grep -qF "$want"; then
      ok "  $label"
    else
      bad "  $label (wanted '$want', got '$title')"
    fi
  }

  run_case "39,39"        "|dock=2|"                    "dock: two rights -> IVI"
  run_case "39,39"        "focus=IVI"                   "dock: focus label follows"
  run_case "37"           "|dock=6|"                    "dock: wrap left from first -> all-apps tile"
  run_case "37,37"        "|dock=5|"                    "dock: wrap-around continues"
  run_case "40"           "mode=dock"                   "dock: down is harmless"
  run_case "10009"        "mode=dock"                   "dock: back is harmless"
  run_case "38"           "mode=grid"                   "up opens the all-apps overlay"
  run_case "38"           "focus=YouTube"               "overlay: focus lands on first app"
  run_case "38,39,39"     "|grid=2|"                    "overlay: horizontal move"
  run_case "38,40"        "|grid=7|"                    "overlay: down -> next row"
  run_case "38,40,39"     "|grid=8|"                    "overlay: row 2 + right"
  run_case "38,40,39,40"  "|grid=15|"                   "overlay: vertical wrap"
  run_case "38,10009"     "mode=dock"                   "overlay: back closes it"
  run_case "38,27"        "mode=dock"                   "overlay: Esc closes it"
  run_case "38,461"       "mode=dock"                   "overlay: 461 closes it"
  run_case "38,10009,39"  "|dock=1|"                    "after close: dock navigation continues"
  run_case "13"           "Предпросмотр"                 "OK in browser -> preview toast"
  run_case "38,40"        "|grid=7|"                    "720p: same 7-column grid" 1280 720
  run_case "38"           "|cols=7|"                    "grid column count detected from layout"

  kill $SERVER_PID 2>/dev/null || true
  trap - EXIT
else
  echo "  (Chrome not found — behavioural checks skipped)"
fi

# ------------------------------------------------------------------ total ---
head_ "result"
if [ "$FAILED" -eq 0 ]; then
  echo "  all checks passed"
else
  echo "  $FAILED check(s) failed"
  exit 1
fi
