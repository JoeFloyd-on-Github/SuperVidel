#!/bin/sh
# Gate-level timing simulation of the routed Videl core (Icarus Verilog).
#
#   1. RTL run (GHDL) of tb/tb_videl_core.vhd with TRACE: writes the
#      per-cycle port trace build/trace_{in,out}.txt (one clock).
#   2. Pre-route check: replay the trace into GHDL's Verilog netlist
#      (build/syn/videl_synth_top.v), zero delay.
#   3. Routed check: replay it into nextpnr's routed netlist, zero delay.
#      Proves the patched cell models (tools/ecp5_sim_compat.py) simulate
#      the routed netlist correctly before any timing is added.
#   4. Timing run: the same with nextpnr's SDF delays at PERIOD ps
#      (tools/sdf_icarus.py turns wire delays into delayed assigns and
#      keeps the cell delays for $sdf_annotate).
#
# Run syn/synth.sh first. Usage:
#   hdl/videl/syn/gatesim.sh [PERIOD_PS [CORNER]]
#     PERIOD_PS  clock period, default 20000 (50 MHz)
#     CORNER     min | typ | max delays, default max
# bus_clk and pix_clk are driven by the same clock (the trace is
# cycle-based), so PERIOD applies to both; compare with nextpnr's per-clock
# Fmax in build/syn/nextpnr.log.
#
# Inputs change at the falling edge (tb_gate.v HOLD = PERIOD/2). A short
# fixed delay after the rising edge races the clock tree: the inputs then
# reach the input registers before the clock does (a hold violation of the
# test set-up, not the core; how short depends on placement).
#
# Limits: Icarus does not evaluate SETUPHOLD checks; a setup violation shows
# up as a register capturing its input late, i.e. an output mismatch.
# Icarus prints "SDF WARNING: Cannot find core in scope" for most cells and
# still applies the delays (checked: results change with the SDF).
set -e
cd "$(dirname "$0")"
here=$(pwd)
tools=$(cd ../../../tools && pwd)
F=$tools/fpga.sh
period=${1:-20000}
corner=${2:-max}
if [ -z "$GHDL" ]; then
  if [ -x "$tools/ghdl/root/usr/bin/ghdl-mcode" ]; then GHDL=$tools/ghdl.sh; else GHDL=ghdl; fi
fi
b=../build
[ -f $b/syn/videl_routed.v ] || { echo "run syn/synth.sh first" >&2; exit 1; }

echo "== 1. RTL trace (GHDL)"
GHDL=$GHDL ../sim.sh -gTRACE=trace | grep -E "tests|PASSED|FAILED"

cells=$tools/fpga/root/usr/share/yosys/ecp5/cells_sim.v
[ -f "$cells" ] || cells=/usr/share/yosys/ecp5/cells_sim.v
inc=$(dirname "$cells")
python3 -I "$tools/ecp5_sim_compat.py" "$cells" $b/syn/cells_sim_compat.v

cd $b
# iverilog noise: the routed netlist's output ports also feed internal
# copies ("coerced to inout"); zero-delay runs skip $sdf_annotate.
quiet() { grep -vE "coerced to inout|Omitting .sdf_annotate" || true; }
run() {   # run <vvp> [plusargs]: print the verdict
  vvp=$1; shift
  $F vvp -n "$vvp" +in=trace_in.txt +out=trace_out.txt "$@" > "${vvp%.vvp}.log" 2>&1 || true
  grep -E "^cycle|^ +want" "${vvp%.vvp}.log" | head -4
  grep -E "cycles checked|PASSED|FAILED" "${vvp%.vvp}.log"
}

echo "== 2. pre-route netlist, zero delay"
$F iverilog -g2012 -o rtl.vvp "$here/tb_gate.v" syn/videl_synth_top.v 2>&1 | quiet
run rtl.vvp

echo "== 3. routed netlist, zero delay"
$F iverilog -g2012 -DDUT=top -I"$inc" -o routed0.vvp \
  "$here/tb_gate.v" syn/videl_routed.v syn/cells_sim_compat.v 2>&1 | quiet
run routed0.vvp

echo "== 4. routed netlist + SDF ($corner corner), period $period ps"
python3 -I "$tools/sdf_icarus.py" syn/videl_routed.v syn/videl_routed.sdf \
  syn/videl_routed_ic.v syn/videl_routed_ic.sdf "$corner"
$F iverilog -g2012 -gspecify -DDUT=top -Ptb_gate.PERIOD="$period" -I"$inc" \
  -o gate.vvp "$here/tb_gate.v" syn/videl_routed_ic.v syn/cells_sim_compat.v 2>&1 | quiet
run gate.vvp +sdf=syn/videl_routed_ic.sdf
echo "(log: hdl/videl/build/gate.log)"
