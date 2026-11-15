#!/usr/bin/env bash
# Download the six bundled nature wallpapers (1920x1080 JPEG, Unsplash License).
#
# Usage:   scripts/fetch_wallpapers.sh [--force]
# Writes:  AiTV/wallpapers/01.jpg ... 06.jpg
#
# The files are already committed in the repo; this script only exists so the
# provenance is reproducible (and so a wallpaper can be re-fetched at higher
# quality later). Unsplash License: https://unsplash.com/license — free to use,
# attribution appreciated (see launcher/README.md for the per-file credits).
set -euo pipefail

cd "$(dirname "$0")/.."
OUT="AiTV/wallpapers"
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36"
FORCE="${1:-}"

mkdir -p "$OUT"

# file | Unsplash photo id | title
SOURCES=(
  "01.jpg|1506905925346-21bda4d32df4|Sunrise above the clouds"
  "02.jpg|1470770841072-f978cf4d019e|Alpine lake and boathouse"
  "03.jpg|1519681393784-d120267933ba|Milky Way over snowy peaks"
  "04.jpg|1441974231531-c6227db76b6e|Sunlight in a pine forest"
  "05.jpg|1501785888041-af3ef285b470|Turquoise mountain lake"
  "06.jpg|1470071459604-3b5ec3a7fe05|Highland valley at sunset"
)

for row in "${SOURCES[@]}"; do
  IFS='|' read -r name id title <<< "$row"
  target="$OUT/$name"
  if [ -s "$target" ] && [ "$FORCE" != "--force" ]; then
    echo "keep   $target  ($title)"
    continue
  fi
  echo "fetch  $target  ($title)"
  curl -fsSL --max-time 60 -A "$UA" \
    "https://images.unsplash.com/photo-${id}?w=1920&h=1080&fit=crop&crop=entropy&q=82&fm=jpg" \
    -o "$target"
  # sanity: a JPEG of the right size class
  if ! file "$target" | grep -q "JPEG image data"; then
    echo "ERROR: $target is not a JPEG" >&2
    rm -f "$target"
    exit 1
  fi
  bytes=$(wc -c < "$target" | tr -d ' ')
  if [ "$bytes" -lt 100000 ]; then
    echo "ERROR: $target is suspiciously small ($bytes bytes)" >&2
    exit 1
  fi
done

echo
du -sh "$OUT"
echo "done: $(ls -1 "$OUT" | wc -l | tr -d ' ') wallpapers"
