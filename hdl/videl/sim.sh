#!/bin/sh
# Run the Videl core testbench in GHDL (VHDL-2008).
# Regenerates the Hatari golden output first (needs a C compiler).
# Set GHDL to the ghdl binary if it isn't on PATH.
set -e
cd "$(dirname "$0")"
make -C ../../tools/videl_ref expected.txt
# Default: the sandboxed GHDL in tools/ghdl/ (tools/get-ghdl.sh), else ghdl on PATH.
if [ -z "$GHDL" ]; then
  if [ -x ../../tools/ghdl/root/usr/bin/ghdl-mcode ]; then GHDL=$(cd ../../tools && pwd)/ghdl.sh; else GHDL=ghdl; fi
fi
mkdir -p build && cd build
for f in ../rtl/videl_pkg.vhd ../rtl/videl_regs.vhd ../rtl/videl_fetch.vhd \
         ../rtl/videl_pixel.vhd ../rtl/videl_core.vhd ../tb/tb_videl_core.vhd; do
  $GHDL -a --std=08 "$f"
done
$GHDL -e --std=08 tb_videl_core
$GHDL -r --std=08 tb_videl_core --ieee-asserts=disable \
  -gVECTORS=../../../tools/videl_ref/vectors.txt \
  -gEXPECTED=../../../tools/videl_ref/expected.txt
