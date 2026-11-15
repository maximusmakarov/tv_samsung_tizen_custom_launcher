#!/bin/sh
# tv-ready.sh [TV_IP] [HOST_IP] — is the TV ready for sdb installs yet?
#
# Run AFTER enabling Developer Mode on the TV, setting Host PC IP to this Mac's
# LAN address, and fully restarting the TV (see README.md §2).
#
#   ./tv-ready.sh <TV_IP> <HOST_IP>   # addresses are required
#   ./tv-ready.sh 192.168.0.100 192.168.0.10
#
# Exit codes: 0 = TV visible over sdb (ready), 1 = not ready (dev mode off,
# wrong Host PC IP, TV not restarted, or wrong network).

set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

TV=${1:?usage: tv-ready.sh <TV_IP> [HOST_IP]}
HOST=${2:?usage: tv-ready.sh <TV_IP> [HOST_IP]}
A2S=${A2S_CLI:-$ROOT/../tools_bin/apps2samsung-cli}
SDB="$ROOT/sdb.sh"

say() { printf '%s\n' "$*"; }

say "== TV readiness check: TV=$TV host=$HOST"
say "-- 1/5 ping"
if ping -c 2 -W 1000 "$TV" >/dev/null 2>&1; then say "   OK: $TV answers ping"; else say "   FAIL: no answer from $TV (network?)"; fi

say "-- 2/5 sdbd port 26101"
if nc -z -G 3 "$TV" 26101 >/dev/null 2>&1; then say "   OK: 26101 open"; else say "   FAIL: 26101 closed (Developer Mode off, Host PC IP not $HOST, or TV not restarted)"; fi

say "-- 3/5 sdb connect"
"$SDB" connect "$TV:26101" 2>&1 | sed 's/^/   /'
say "-- 4/5 sdb devices"
DEVICES=$("$SDB" devices 2>&1)
printf '%s\n' "$DEVICES" | sed 's/^/   /'

say "-- 5/5 Apps2Samsung CLI TV check"
if [ -x "$A2S" ]; then
    "$A2S" tv "$TV" --local-ip "$HOST" 2>&1 | sed 's/^/   /'
else
    say "   (Apps2Samsung CLI not found at $A2S — set A2S_CLI=/path/to/apps2samsung-cli)"
fi

# A real attached target line looks like: "192.168.0.100:26101\tdevice"
if printf '%s\n' "$DEVICES" | grep -Eq "$TV:26101[[:space:]]+device"; then
    say ""
    say "RESULT: TV is visible over sdb. Install with either:"
    say "  $ROOT/tizen.sh install -s $TV:26101 -n <app>.wgt -- <out-dir>"
    say "  $A2S install <signed>.wgt --tv $TV --local-ip $HOST --tizen-cert -y"
    exit 0
fi

say ""
say "RESULT: TV is NOT reachable over sdb yet. On the TV: Apps -> 12345 ->"
say "Developer Mode On -> Host PC IP $HOST -> full restart (power cycle), then rerun."
exit 1
