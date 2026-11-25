#!/bin/sh
# Run the sandboxed GHDL from tools/ghdl/ (created by tools/get-ghdl.sh).
# GHDL_PREFIX must point at the directory that holds the precompiled
# std/ and ieee/ libraries: root/usr/lib/ghdl/mcode/vhdl (NOT .../mcode).
here=$(cd "$(dirname "$0")" && pwd)
root="$here/ghdl/root"
if [ ! -x "$root/usr/bin/ghdl-mcode" ]; then
  echo "tools/ghdl/ missing: run tools/get-ghdl.sh first" >&2
  exit 1
fi
GHDL_PREFIX="$root/usr/lib/ghdl/mcode/vhdl" exec "$root/usr/bin/ghdl-mcode" "$@"
