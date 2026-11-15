#!/usr/bin/env bash
# Rebuild the launcher preview screenshots in preview/ with headless Chrome.
#
# Usage:   scripts/preview.sh
# Needs:   python3 (http.server) and Google Chrome.
#
# How it works:
#   * serves AiTV/ over http://127.0.0.1:<free port>
#   * takes every screenshot with ?instant=1, a QA switch that pins CSS
#     transitions/animations at their end state: Chromium's virtual-time clock can
#     otherwise capture the boot fade half-way and produce a near-black image.
#     On the TV the transitions run normally (see README -> Local preview).
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
CHROME="${CHROME_BIN:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
PORT="${PORT:-}"

if [ ! -x "$CHROME" ]; then
  echo "Google Chrome not found at: $CHROME  (set CHROME_BIN=...)" >&2
  exit 1
fi

if [ -z "$PORT" ]; then
  PORT=$(python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
)
fi

mkdir -p preview
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory AiTV >/dev/null 2>&1 &
SERVER_PID=$!
trap 'kill $SERVER_PID 2>/dev/null || true' EXIT
sleep 1

URL="http://127.0.0.1:${PORT}/index.html"
shoot() {
  local w=$1 h=$2 out=$3 query=$4
  echo "shoot  ${w}x${h}  preview/${out}"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --no-first-run --force-device-scale-factor=1 \
    --window-size="${w},${h}" --screenshot="${ROOT}/preview/${out}" \
    --virtual-time-budget=6000 "${URL}${query}" >/dev/null 2>&1
}

shoot 1920 1080 launcher-main.png "?instant=1"
shoot 1920 1080 launcher-allapps.png "?instant=1&allapps=1"
shoot 1280  720 launcher-720p.png "?instant=1"
shoot 1280  720 launcher-720p-allapps.png "?instant=1&allapps=1"

echo
ls -la preview/*.png
