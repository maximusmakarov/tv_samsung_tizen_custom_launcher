#!/bin/sh
# sdb.sh — wrapper for the Tizen Smart Development Bridge (sdb) shipped in
# this toolchain. Nothing is installed system-wide:
#
#   ./sdb.sh version
#   ./sdb.sh connect 192.168.0.100:26101
#   ./sdb.sh devices
#
# The wrapper:
#   * puts toolchain/bin on PATH (so sdb and any helper it spawns are found),
#   * exec's the sdb binary (default: bin/sdb = 4.2.36),
#   * lets you pick another build with SDB_BIN=/path/to/sdb ./sdb.sh ...
#     (this toolchain also ships bin/sdb-legacy-2.3.8, the Tizen 2.4-era build).
#
# Note: both sdb builds in this toolchain are Intel x86_64 Mach-O files
# (Samsung publishes no arm64 slice). They run through Apple's Rosetta 2,
# which is installed on this machine (macOS 26, arm64).

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# Locate the requested sdb build.
SDB_PATH=${SDB_BIN:-"$ROOT/bin/sdb"}
if [ ! -x "$SDB_PATH" ]; then
    echo "sdb.sh: no executable sdb at $SDB_PATH (set SDB_BIN or restore toolchain/bin/sdb)" >&2
    exit 127
fi

# Put the toolchain first on PATH so any companion binaries are picked up.
PATH="$ROOT/bin:$PATH"
export PATH

# sdb works with a per-user server on TCP 26099/26097; keep it in the user's
# HOME (default) — no daemon setup is needed. SDB_HOME is only exported when
# the caller set it, so that several toolchains can keep separate state.
if [ -n "${SDB_HOME:-}" ]; then
    export SDB_HOME
fi

exec "$SDB_PATH" "$@"
