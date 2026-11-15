#!/usr/bin/env bash
# Снимок текущего состояния ТВ (после изменений) в backup/after-<ts>/.
. "$(dirname "$0")/tv-env.sh"
B="$ROOT/backup/after-$(ts)"; mkdir -p "$B"
"$SDB" connect "$TV_SDB" >/dev/null 2>&1
tv_api /api/v2/ > "$B/api_v2.json" 2>&1 || true
"$SDB" devices > "$B/sdb_devices.txt" 2>&1 || true
"$SDB" -s "$TV_SDB" shell 0 applist > "$B/applist.txt" 2>&1 || true
"$SDB" -s "$TV_SDB" shell 0 getduid > "$B/duid.txt" 2>&1 || true
"$SDB" -s "$TV_SDB" shell 0 getappinstallpath >> "$B/duid.txt" 2>&1 || true
echo "snapshot: $B"
grep -iE "AiTV" "$B/applist.txt" || true
