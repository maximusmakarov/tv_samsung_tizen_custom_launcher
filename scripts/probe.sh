#!/usr/bin/env bash
# Read-only capability probe for the retail Tizen 2.4 TV.
# Writes everything to backup/probe-<ts>/ and prints a summary.
# Safe: no installs, no uninstalls, no settings changes.
. "$(dirname "$0")/tv-env.sh"

OUT="$ROOT/backup/probe-$(ts)"
mkdir -p "$OUT"
echo "probe -> $OUT"

# 0. dev mode sanity
tv_api "/api/v2/" > "$OUT/api_v2.json" 2>&1
python3 - "$OUT/api_v2.json" <<'PY' || true
import json,sys
d=json.load(open(sys.argv[1])); dev=d.get("device",{})
print("model:", dev.get("modelName"), "devMode:", dev.get("developerMode"), "devIP:", dev.get("developerIP"))
PY

# 1. sdb transport
"$SDB" version > "$OUT/sdb_version.txt" 2>&1 || true
"$SDB" connect "$TV_SDB" > "$OUT/sdb_connect.txt" 2>&1 || true
"$SDB" devices > "$OUT/sdb_devices.txt" 2>&1 || true
sdb_cmd capability > "$OUT/sdb_capability.txt" || true
sdb_cmd get-serialno > "$OUT/sdb_serial.txt" || true

# 2. shell surface: what is allowed, what is closed
for c in "shell" "shell id" "shell ls /" "shell 0" "shell 0 help" "shell 0 vd_applist" "shell 0 applist" \
         "shell 0 vd_appinstall" "shell 0 vd_appuninstall" "shell 0 debug" "shell 0 execute" "shell 0 was_execute" \
         "shell vd_applist" "shell applist"; do
  f="$OUT/shell_$(echo "$c" | tr ' /' '__').txt"
  { echo "+ sdb $c"; sdb_cmd $c; echo; echo "exit=$?"; } > "$f" 2>&1 || true
done

# 3. file visibility (read-only pulls into the probe dir)
mkdir -p "$OUT/pull"
for p in /opt/dbspace /opt/usr/apps /usr/apps /opt/etc /tmp; do
  d="$OUT/pull/$(echo "$p" | tr '/' '_')"
  { echo "+ sdb pull $p"; "$SDB" -s "$TV_SDB" pull "$p" "$d" 2>&1; echo "exit=$?"; } > "$d.log" 2>&1 || true
done

# 4. sdb app service (no-op listing is not available; record the binary's own help)
"$SDB" help > "$OUT/sdb_help.txt" 2>&1 || true

echo "--- capability ---"; sed -n '1,40p' "$OUT/sdb_capability.txt" 2>/dev/null
echo "--- devices ---"; cat "$OUT/sdb_devices.txt" 2>/dev/null
echo "--- shell results (first line each) ---"
for f in "$OUT"/shell_*.txt; do printf '%-46s %s\n' "$(basename "$f")" "$(sed -n '2p' "$f" | cut -c1-70)"; done
