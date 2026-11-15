#!/usr/bin/env bash
# Package the two Tizen web apps into installable .wgt archives.
#
#   dist/AiTV.wgt      -> AiTV.Launcher, package AiTV
#   dist/HomeKey.wgt   -> AiTV.HomeKey,   package HomeKey
#
# A .wgt is a zip with config.xml at the archive root. Output is unsigned:
# sign it with Apps2Samsung CLI (or Tizen Studio) before installing on a TV,
# see README.md -> "Packaging & installing".
#
# Usage:   ./build.sh
set -euo pipefail

cd "$(dirname "$0")"
ROOT="$(pwd)"

pack() {
  local src="$1" out="$2"
  echo "pack   ${src}/  ->  dist/${out}"
  rm -f "dist/${out}"
  # -X drops extra file attributes, keeping the archive portable.
  # stale signing material (from a previous `tizen package` run in-tree) must
  # never ride along inside a freshly packaged, unsigned .wgt
  ( cd "$src" && zip -qrX "${ROOT}/dist/${out}" . \
      -x '.DS_Store' '._*' '*/._*' '__MACOSX/*' \
         'author-signature.xml' 'signature1.xml' '.manifest.tmp' )
}

check() {
  local wgt="$1"
  python3 - "$wgt" <<'PY'
import sys, zipfile
path = sys.argv[1]
with zipfile.ZipFile(path) as z:
    names = z.namelist()
    bad = z.testzip()
need = {"config.xml", "index.html"}
missing = need - set(names)
if bad:
    sys.exit("%s: corrupt entry %s" % (path, bad))
if missing:
    sys.exit("%s: missing %s" % (path, sorted(missing)))
print("       %d files, %.2f MB, config.xml at root: ok" % (
    len(names), sum(z.getinfo(n).file_size for n in names) / 1048576.0))
PY
}

mkdir -p dist
echo "AiTV + HomeKey -> ${ROOT}/dist"
echo

pack AiTV AiTV.wgt
check dist/AiTV.wgt
echo
pack HomeKey HomeKey.wgt
check dist/HomeKey.wgt
echo

ls -la dist/*.wgt
