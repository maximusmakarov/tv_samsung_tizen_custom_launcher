#!/bin/sh
# tizen.sh — wrapper for the Tizen Studio CLI shipped in this toolchain.
#
#   ./tizen.sh version
#   ./tizen.sh package -t wgt -s tizen-sdk -- ./my-project -o ./out
#   ./tizen.sh install -s 192.168.0.100:26101 -n app.wgt -- ./out
#   ./tizen.sh security-profiles list
#
# The CLI is a Java program; it uses the JDK bundled in tizen-studio/jdk
# (Intel x86_64, runs through Apple's Rosetta 2, already installed here).
# SDK path and per-user data path come from tizen-studio/sdk.info, which this
# wrapper keeps pointing at this toolchain (see README.md).
#
# No system-wide install and no network access are needed for
# build-web / package / security-profiles.

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

SDK="$ROOT/tizen-studio"
DATA="$ROOT/tizen-studio-data"

if [ ! -x "$SDK/tools/ide/bin/tizen" ]; then
    echo "tizen.sh: Tizen CLI not found under $SDK (toolchain incomplete)" >&2
    exit 127
fi

# Keep sdk.info in sync with this checkout if the folder was moved/copied.
WANT="TIZEN_SDK_INSTALLED_PATH=$SDK
TIZEN_SDK_DATA_PATH=$DATA"
if [ ! -f "$SDK/sdk.info" ] || [ "$(cat "$SDK/sdk.info")" != "$WANT" ]; then
    printf '%s\n' "$WANT" > "$SDK/sdk.info"
fi
mkdir -p "$DATA"

export TIZEN_SDK_INSTALLED_PATH="$SDK"
export TIZEN_SDK_DATA_PATH="$DATA"
PATH="$SDK/tools/ide/bin:$SDK/tools:$ROOT/bin:$PATH"
export PATH
# Pin the bundled JRE so a stray system java cannot shadow it.
export JAVA_HOME="$SDK/jdk/Contents/Home"

exec "$SDK/tools/ide/bin/tizen" "$@"
