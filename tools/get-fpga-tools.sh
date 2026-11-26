#!/bin/sh
# Create a private, user-local FPGA toolchain under tools/fpga/ without root,
# the same way tools/get-ghdl.sh does for GHDL: download the Ubuntu .debs with
# apt-get and unpack them with dpkg -x. Nothing is installed system-wide.
# tools/fpga/ is gitignored. Run the tools through tools/fpga.sh.
#
#   yosys, yosys-abc          synthesis (ECP5 mapping, synth_ecp5)
#   nextpnr-ecp5 (+ chipdb)   place and route, static timing, SDF output
#   iverilog                  gate-level simulation with SDF delays
#   libboost-program-options  runtime library nextpnr needs and the host
#                             may lack (others are expected to be installed)
#
# VHDL is converted to Verilog by GHDL itself (ghdl --synth --out=verilog),
# so no Yosys GHDL plugin is needed (Ubuntu has no package for it).
set -e
cd "$(dirname "$0")"
mkdir -p fpga/deb
cd fpga/deb
apt-get download yosys yosys-abc nextpnr-ecp5 nextpnr-ecp5-chipdb iverilog \
  libboost-program-options1.90.0
cd ..
rm -rf root
for d in deb/*.deb; do dpkg -x "$d" root; done
echo "Unpacked. Check with: tools/fpga.sh yosys -V"
