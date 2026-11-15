#!/usr/bin/env bash
# Shared environment for the UE40K6500 (192.168.0.100) TV scripts.
# Source it:  . scripts/tv-env.sh
set -uo pipefail

export TV_IP="${TV_IP:?export TV_IP=<LAN-адрес телевизора>}"
export TV_SDB="${TV_IP}:26101"
export LOCAL_IP="${LOCAL_IP:?export LOCAL_IP=<LAN-адрес этого компьютера>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT
export SDB="$ROOT/toolchain/sdb.sh"
export TIZEN="$ROOT/toolchain/tizen.sh"
export A2S="$ROOT/tools_bin/apps2samsung-cli"

# sdb helper: sdb_cmd <args...>  (never fails the caller)
sdb_cmd() { "$SDB" -s "$TV_SDB" "$@" 2>&1; }

# api: GET the TV REST API
tv_api() { curl -s -m 6 "http://$TV_IP:8001$1"; }

# key: send a remote key (needs the paired websocket token)
tv_key() { "$ROOT/.venv/bin/python" "$ROOT/tv/tv_remote.py" --name dsh-agent key "$@" 2>&1 | grep -E "sent|channel|UNAUTH" ; }

ts() { date +%Y%m%d-%H%M%S; }

wait_devmode() {
  local i
  for i in $(seq 1 "${1:-60}"); do
    local dm
    dm=$(tv_api /api/v2/ | python3 -c 'import json,sys;print(json.load(sys.stdin)["device"].get("developerMode","?"))' 2>/dev/null)
    if [ "$dm" = "1" ] || [ "$dm" = "true" ]; then echo "developerMode=1"; return 0; fi
    sleep 5
  done
  echo "developerMode still off"; return 1
}
