#!/bin/sh
# Run a tool from the sandboxed FPGA toolchain in tools/fpga/
# (created by tools/get-fpga-tools.sh), e.g.:
#   tools/fpga.sh yosys -V
#   tools/fpga.sh nextpnr-ecp5 --version
#   tools/fpga.sh iverilog -V
# Falls back to the same command on PATH if the sandbox is absent.
here=$(cd "$(dirname "$0")" && pwd)
root="$here/fpga/root"
tool=$1; shift
if [ ! -d "$root/usr/bin" ]; then
  exec "$tool" "$@"
fi
export PATH="$root/usr/bin:$PATH"
export LD_LIBRARY_PATH="$root/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
case $tool in
  # yosys finds share/ and yosys-abc relative to its binary; iverilog needs
  # its module dir (ivl, vvp targets) given explicitly when relocated.
  iverilog) exec "$root/usr/bin/iverilog" -B"$root/usr/lib/x86_64-linux-gnu/ivl" "$@" ;;
  vvp)      exec "$root/usr/bin/vvp" -M"$root/usr/lib/x86_64-linux-gnu/ivl" "$@" ;;
  # Ubuntu's nextpnr-ecp5 only looks for its chip database at the absolute
  # path /usr/share/nextpnr/ecp5/ and, if absent, silently drops the device
  # options (--um5g-45k becomes "unrecognised option"). Without root, lay
  # the sandbox's share/ over /usr/share in a private user + mount namespace
  # (unshare -rm, read-only overlayfs). Nothing outside this process sees it.
  nextpnr-ecp5)
    exec unshare -rm sh -c 'mount -t overlay overlay -o "lowerdir=$0/usr/share:/usr/share" /usr/share &&
      exec "$0/usr/bin/nextpnr-ecp5" "$@"' "$root" "$@" ;;
  *)        exec "$tool" "$@" ;;
esac
