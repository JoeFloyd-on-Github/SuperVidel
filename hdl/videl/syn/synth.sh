#!/bin/sh
# Synthesise and place-and-route the Videl core for the SV-Lite FPGA
# (LFE5UM5G-45F, caBGA381) and report timing. Open-source flow:
#   1. GHDL      VHDL-2008 -> Verilog netlist (ghdl --synth --out=verilog)
#   2. Yosys     synth_ecp5 -> ECP5 cells (JSON), resource report.
#                -nodsp: the one multiplier goes to LUTs, because the
#                MULT18X18D has no simulation model in Yosys 0.52 (gatesim)
#   3. nextpnr   place and route, static timing against syn/videl.lpf,
#                routed JSON + SDF (delays for gate-level simulation)
#   4. Yosys     routed JSON -> Verilog netlist for syn/gatesim.sh
#                (-norename: keep nextpnr's $-names, which the SDF uses)
# Tools: GHDL from tools/ghdl.sh (else PATH), the rest from tools/fpga.sh
# (tools/get-fpga-tools.sh). Outputs land in hdl/videl/build/syn/.
# Extra arguments go to nextpnr-ecp5, e.g. --seed 3.
set -e
cd "$(dirname "$0")"
here=$(pwd)
tools=$(cd ../../../tools && pwd)
if [ -z "$GHDL" ]; then
  if [ -x "$tools/ghdl/root/usr/bin/ghdl-mcode" ]; then GHDL=$tools/ghdl.sh; else GHDL=ghdl; fi
fi
F=$tools/fpga.sh
out=../build/syn
mkdir -p $out && cd $out

echo "== 1. GHDL: VHDL -> Verilog"
rm -f work-obj08.cf
for f in videl_pkg videl_regs videl_fetch videl_pixel videl_core; do
  $GHDL -a --std=08 "$here/../rtl/$f.vhd"
done
$GHDL -a --std=08 "$here/videl_synth_top.vhd"
$GHDL --synth --std=08 --out=verilog videl_synth_top > videl_synth_top.v 2> ghdl.log || { cat ghdl.log; exit 1; }

echo "== 2. Yosys: synth_ecp5"
$F yosys -q -l yosys.log -p "read_verilog videl_synth_top.v; \
  synth_ecp5 -nodsp -top videl_synth_top -json synth.json; tee -o util.txt stat"

echo "== 3. nextpnr-ecp5: place, route, timing"
$F nextpnr-ecp5 --um5g-45k --package CABGA381 --speed 8 --json synth.json \
  --lpf "$here/videl.lpf" --lpf-allow-unconstrained \
  --write routed.json --sdf videl_routed.sdf --report report.json \
  --log nextpnr.log --timing-allow-fail "$@" || { tail -30 nextpnr.log; exit 1; }

echo "== 4. Yosys: routed netlist -> Verilog"
$F yosys -q -p "read_json routed.json; write_verilog -noattr -norename videl_routed.v"

echo
grep -E "Info: Device utilisation" -A12 nextpnr.log | grep -E "TRELLIS_SLICE|DP16KD|TRELLIS_IO|MULT18|EHXPLL" || true
grep -E "Max frequency for clock" nextpnr.log | tail -2 | sed 's/\$glbnet\$//; s/\$TRELLIS_IO_IN//'
echo "Full logs and outputs: hdl/videl/build/syn/"
