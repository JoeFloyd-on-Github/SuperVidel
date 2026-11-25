#!/bin/sh
# Create a private, user-local GHDL (mcode backend) under tools/ghdl/ without
# root: download the Ubuntu .debs with apt-get and unpack them with dpkg -x.
# Nothing is installed system-wide. tools/ghdl/ is gitignored.
# See docs/design/videl-core-methodology.md, section 7.
set -e
cd "$(dirname "$0")"
mkdir -p ghdl/deb
cd ghdl/deb
apt-get download ghdl-common ghdl-mcode
cd ..
rm -rf root
for d in deb/*.deb; do dpkg -x "$d" root; done
echo "Unpacked. Check with: tools/ghdl.sh --version"
