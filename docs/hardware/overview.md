# Hardware Overview

> Status: this page summarises the developers' project page ([S001], 2012-03-04), with later sources added. For details see [architecture.md](architecture.md) (parts and block diagrams), [memory-map.md](memory-map.md), [registers.md](registers.md) and [../software/drivers.md](../software/drivers.md). Items S001 listed as planned are kept separate below.

## Summary

The SuperVidel (SV) replaces the Falcon030's Videl video chip with a graphics card. It sits on the internal CT60 expansion connector of a CT60/CT63-equipped Falcon. It aims to be 100% compatible with the original Videl at the register level, and adds its own video RAM, higher resolutions and colour depths, and a blitter. [S001]

**Why it was made:** CPU writes to ST-RAM limit screen updates. S001 estimates the available ST-RAM bandwidth at about 5.5 MB/s, which allows only about 30 fps of full-screen updates at 320×240×16-bit, even with a CT60. [S001]

## Main components

| Item | Detail | Ref |
|------|--------|-----|
| Host interface | CT60 expansion bus slot (internal connector on the CT60/CT63) | [S001] |
| Logic | Xilinx Spartan-3 2000 FPGA, FG456 package; holds all the graphics logic | [S001] |
| Video RAM | 128 MB DDR2, 32 bits wide, up to 200 MHz (DDR400); 1600 MB/s theoretical. Tested at 220 MHz with an earlier, smaller FPGA design | [S001] |
| Output connector | DVI-I (digital and analogue). A DVI-I splitter cable gives one VGA and one DVI output | [S001] |
| Clock chip | TI CDCE937 per S010's block diagram (S011 says CDCE925); 25 MHz crystal; outputs up to 240 MHz | [S001][S010][S011] |
| Clock routing | Separate VGA and DVI clock signals to the FPGA (an earlier design had only one) | [S001] |
| Videl clock input | Flat cable from the motherboard to JP7. S001 says 4 wires for both 25.175 MHz and 32 MHz; the installation manual supplies a 6-wire cable and connects only the 25.175 MHz VGA clock | [S001][S012] |
| VGA DAC / DVI transmitter | Analog Devices ADV7125 / TI TFP410 | [S010] |
| Board colour | Orange | [S001] |

The full parts list from the hardware block diagram is in [architecture.md](architecture.md).

### Prototype photos

These come from the rev 1 prototype photo (January 2009) [S003] and the SVEthLANa prototype photos (January 2011) [S004][S005]:

- The prototype's TI **TFP410PAP**, Xilinx Spartan FPGA (U8) and Analog Devices IC (U4) match S010's block diagram, where U4 is the ADV7125 DAC. [S003][S010]
- The 2×7 boxed header on the prototype fits S010's "JTAG Conn. 14 pin". **(unverified)** [S003][S010]
- SVEthLANa: the RJ45 jack is a Bel Stewart MagJack **0890-1K1T-06-F**, with the transformers built in. The small QFP IC is presumably the Ethernet PHY, since the MAC is in the SV FPGA [S010]. Its part number can't be read. [S004][S005]

## Video capabilities

- **Videl compatibility:** all Videl colour depths and resolutions, from mono to 16-bit, by acting as the Videl at the hardware register level. As of 2012-03-04, all VGA resolutions worked, including 2-bit and ST modes. [S001]
- **New colour depths:**
  - 24-bit colour, stored as 4-byte RGBA. [S001]
  - 8-bit chunky, with a control bit added to the old Videl register range `$FF82xx`. [S001] The exact register and bit are not yet documented.
- **Maximum modes:** 1600×1200 @ 60 Hz (162 MHz pixel clock), or 1920×1080 @ 60 Hz with reduced timings (DVI only), including in 24-bit. [S001] For higher resolutions S001 suggests halving the pixel clock to get 30 Hz.
- **Pixel clocks:** supports the original 25.175 MHz (VGA) and 32 MHz (RGB) settings. Single-link DVI limits output to 165 MHz. VGA at 1920×1200 needs about 200 MHz, which means the clock to the DVI chip has to be blocked while that mode runs. [S001]
- **Bandwidth example:** 1600×1200 @ 60 Hz in 32-bit uses about 460 MB/s of the 1600 MB/s available. [S001]
- **Dual screen:** VGA and DVI at the same time, up to 1920×1080, recommended only up to 8-bit. Because the VGA and DVI clocks are separate, the hardware can drive different resolutions on each; desktop software support was still to come. Two DVI screens aren't possible because there's no dual-channel DVI output. [S001]

### Clock drift in Videl modes

When the SV runs Videl-timed modes (games, demos), its own 25.175 MHz and 32 MHz clocks slowly drift away from the motherboard's Videl clocks. Over time, double-buffered programs start to flicker. The supplied wire harness feeds the original Videl clocks into the SV to fix this. [S001]

## Blitter ("Super Blitter")

- Not compatible with the original Falcon BLiTTER. [S001]
- Does normal 2D blits, and alpha blending in the 24-bit RGBA mode. [S001]
- Register interface: not yet documented.

## Firmware updates

- Firmware runs on the FPGA and is updated from a program running in 68060 mode, with no cables needed. The new firmware takes effect after a power cycle. [S001]
- If an update fails, recovery needs a Xilinx Platform USB (JTAG) cable. [S001]

## SVEthLANa (Ethernet daughterboard)

- "SuperVidel Ethernet LAN adapter": connects to the SV with a small flat cable and screws to the back of the Falcon case. [S001]
- The prototype measured 70×28 mm; the production board is slightly longer and orange. [S001]
- Intended for users with no EtherNat, or with one but no need for its USB support. [S001]

## Physical fit and installation constraints

- The DVI connector takes the space of the standard 2.5" hard-drive bracket. The drive has to be moved, for example laid flat on the motherboard. [S001]
- **Standard case, standard CT60/63 mounting:** only one board fits under the keyboard; the upward-facing address connector touches the keyboard. S001 advises removing a screw on the underside of the keyboard. [S001]
- **With the CT extender boards** (the developers' version of Rodolphe's CT extender): the CT60 moves a few cm back, so stacked boards clear the keyboard. Only two boards fit vertically (for example SV + EtherNat). Installing the extenders means removing the CT60's original female headers and soldering the extenders' male headers in their place, which raises the CT60 only about 2 mm. [S001]
- A DVI splitter cable can be hard to fit between the SV and the floppy drive. [S001]

## Planned or unreleased as of 2012-03-04

These were marked as planned in [S001]. Whether any of them shipped is unknown.

- RGB/TV monitor timings. The hardware supports them but the VHDL hadn't been written, and an RGB monitor would need a VGA-15-to-RGB adapter.
- A flexible DVI-I male-to-female board to replace the splitter cable.
- Software support for VGA resolutions that need the DVI clock blocked.
- Scaling blits.
- MPEG2 decoding (about DVD/PAL resolution), possibly using soft CPU core(s) in the FPGA plus IDCT and sub-pixel blit logic.
- Hardware 3D: a textured polygon mapper.

## Open questions

Answered by later sources: the native register map and the location of video RAM ([registers.md](registers.md), [memory-map.md](memory-map.md)); the firmware format and updater, and which drivers exist ([../software/drivers.md](../software/drivers.md)); the main part numbers ([architecture.md](architecture.md)).

Still open:

- The emulated Videl registers and the 8-bit chunky control bit in `$FF82xx`.
- Pinouts of the CT60 expansion connector, JP7 and the 45-pin SVEthLANa FPC connector.
- The SVEthLANa PHY part number.
- Which of the planned features were eventually released; firmware changelogs after FW010.

[S001]: ../../sources/INDEX.md
[S010]: ../../sources/INDEX.md
[S011]: ../../sources/INDEX.md
[S012]: ../../sources/INDEX.md
[S003]: ../../sources/INDEX.md
[S004]: ../../sources/INDEX.md
[S005]: ../../sources/INDEX.md
