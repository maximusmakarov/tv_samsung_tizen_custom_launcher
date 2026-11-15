#!/usr/bin/env bash
# Full pre-change backup of the TV into backup/<timestamp>/.
# Run once Developer Mode is on and sdb can connect. Read-only against the TV.
. "$(dirname "$0")/tv-env.sh"

B="$ROOT/backup/$(ts)"
mkdir -p "$B"
echo "backup -> $B"

# 1. TV identity / API state (raw)
tv_api "/api/v2/" > "$B/api_v2.json" 2>&1 || true
tv_api "/api/v2/?hidden=1" > "$B/api_v2_hidden.json" 2>&1 || true
printf 'TV_IP=%s\nLOCAL_IP=%s\ndate=%s\n' "$TV_IP" "$LOCAL_IP" "$(date -Iseconds)" > "$B/META.txt"
{ "$SDB" version; "$SDB" devices; } > "$B/sdb_state.txt" 2>&1 || true

# 2. developer-mode state
python3 - "$B/api_v2.json" > "$B/device_summary.txt" <<'PY' || true
import json,sys
try: d=json.load(open(sys.argv[1]))
except Exception: raise SystemExit("api dump unreadable")
dev=d.get("device",{})
for k in ("modelName","model","firmwareVersion","developerMode","developerIP","resolution","countryCode","OS","networkType","wifiMac"):
    print(f"{k}: {dev.get(k)}")
PY

# 3. app inventory (several command generations; keep whichever answers)
mkdir -p "$B/apps"
for c in "0 vd_applist" "0 applist" "0 vd_applist --all" "0 applist --all" "0 vd_appinfo"; do
  n="$(echo "$c" | tr ' /' '__')"
  { echo "+ sdb shell $c"; sdb_cmd shell $c; } > "$B/apps/$n.txt" 2>&1 || true
done
# Tizen Studio's own device manager list (if it can talk to this build)
"$TIZEN" device list > "$B/apps/tizen_device_list.txt" 2>&1 || true
# Apps2Samsung installed list (speaks sdb in-process)
"$A2S" installed --tv "$TV_IP" --local-ip "$LOCAL_IP" --json > "$B/apps/apps2samsung_installed.json" 2>&1 || true

# 4. vconf snapshot when a command channel is available (probe with read-only gets)
V="$B/vconf"; mkdir -p "$V"
for k in db/appfw/home_appid db/appfw/startup_appid db/appfw/first_screen/type db/appfw/app_id \
         db/menu/smart_hub/ontvsetting/auto_start db/menu/autorun_tv_plus \
         db/menu/support/softwareupdate/autoupdate db/menu/support/usage/terms/adv \
         television/ads/interest_based_ads db/menu/support/ad_setting; do
  n="$(echo "$k" | tr '/' '_')"
  { echo "+ vconftool get $k"; sdb_cmd shell "vconftool get $k"; } > "$V/$n.txt" 2>&1 || true
done

# 5. everything that could be pulled (best effort: permissions may be closed)
mkdir -p "$B/pull"
for p in /opt/dbspace /opt/usr/apps /opt/usr/data /usr/apps /opt/etc /tmp; do
  d="$B/pull/$(echo "$p" | tr '/' '_')"
  "$SDB" -s "$TV_SDB" pull "$p" "$d" > "$d.log" 2>&1 || true
done

# 6. keep a copy of every local artefact we are about to install / change
mkdir -p "$B/local"
for f in "$ROOT"/launcher/dist/*.wgt; do [ -f "$f" ] && cp "$f" "$B/local/"; done
cp -R "$ROOT/scripts" "$B/local/scripts" 2>/dev/null || true
sha256sum "$B"/local/* 2>/dev/null > "$B/local/SHA256SUMS" || shasum -a 256 "$B"/local/* > "$B/local/SHA256SUMS" 2>/dev/null || true

# 7. human-readable manifest
cat > "$B/MANIFEST.md" <<MD
# TV backup $(basename "$B")

- TV: $(grep -E '^modelName' "$B/device_summary.txt" 2>/dev/null | cut -d' ' -f2-)
- Date: $(date -Iseconds)
- TV IP: $TV_IP (Host PC IP: $LOCAL_IP)

## Contents
| path | what |
|---|---|
| api_v2.json | raw REST /api/v2/ dump (identity, firmware fields, developerMode) |
| device_summary.txt | the useful device fields |
| sdb_state.txt | sdb version + connected devices |
| apps/ | app-list attempts from each command generation + Apps2Samsung listing |
| vconf/ | vconf readbacks (only meaningful if a command channel exists) |
| pull/ | best-effort sdb pulls of TV config trees (may be empty on retail firmware) |
| local/ | exact .wgt packages and scripts that will be installed by this project |

## Restore
\`../scripts/restore.sh $(basename "$B")\` (see that script and README.md).
MD

echo "backup done: $B"
echo "summary:"; cat "$B/device_summary.txt" 2>/dev/null
