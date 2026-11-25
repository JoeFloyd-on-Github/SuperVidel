# Architecture

> Sources: the hardware and VHDL block diagrams in *HW VHDL SW overview*, Rev 1, 2012-03-10 [S010]; board details from the installation manual [S012]. The diagrams are on pages 2 and 3 of S010.

## Board hardware

```
 CT60 addr conn ─┐                     ┌─ Xilinx PROM 4Mbit ─ Xilinx PROM 4Mbit ─ JTAG conn (14-pin)
 CT60 data conn ─┼─ 74LCX245 ×13 ─┐    │      (master serial config + SW_JTAG)
                 │                │    │
 CT60 clk ─ filter/jumper (J7) ───┤    │   TI CDCE937 clock chip ← 25 MHz crystal
                                  │    │     ├ DDR clk
                                  ▼    ▼     ├ VGA clk
                          ┌──────────────────┴ DVI clk ──┐
 Motherboard CLK conn ───▶│ Xilinx Spartan-3 2000 -5     │──RGB24+VGA clk──▶ ADV7125 DAC ──analog──┐
  (32 MHz, 25.175 MHz)    │       FGG456C                │                                        ├▶ DVI-I
 Expansion/SVEthLANa ◀───▶│                              │──RGB24+DVI clk──▶ TI TFP410 ──TMDS─────┘
  FPC 45-pin              └───────┬───────────┬──────────┘
  (18 data, 3.3V, GND)            │ D16       │ D16  (shared addr/ctrl)
                            Micron DDR2   Micron DDR2
                             512 Mbit      512 Mbit

 Power: TI TPS75003 (from 3.3 V and 5 V) → 2.5 V, 1.8 V, 1.2 V
```

| Block | Part | Notes | Ref |
|-------|------|-------|-----|
| FPGA | Xilinx Spartan-3 XC3S2000, speed grade -5, FGG456C package | All logic | [S010] |
| Video RAM | 2 × Micron DDR2, 512 Mbit, 16 bits wide each | Together 32 bits wide, 128 MB; shared address/control bus | [S010] |
| VGA DAC | Analog Devices **ADV7125** | Fed 24-bit RGB and the VGA clock | [S010] |
| DVI transmitter | TI **TFP410** (PAP package per photo [S003]) | Fed 24-bit RGB and the DVI clock; set up by the FPGA over I²C | [S010] |
| Clock synthesizer | TI **CDCE937** (S011 says CDCE925) | 25 MHz crystal; outputs DDR, VGA and DVI clocks; programmed over I²C by the FPGA | [S010][S011] |
| Bus buffers | 13 × 74LCX245 | Between the CT60 address/data connectors and the FPGA | [S010] |
| Configuration | 2 × Xilinx PROM, 4 Mbit | Master-serial configuration of the FPGA; programmable over JTAG | [S010] |
| Regulator | TI **TPS75003** | Makes 2.5 V, 1.8 V and 1.2 V from the CT60's 3.3 V and 5 V | [S010] |
| Output | DVI-I connector (J1 on the v2 layout) | Digital (TMDS) and analogue RGB | [S010][S012] |

### Host (CT60/CT63) requirements

The SV sits on the CT60/CT63 expansion slot, so the CT60's own CPLD firmware (the ABE and SDR chips) affects how it behaves:

- **ABE_V5M / SDR_V5E (2006):** the initial CT60 version, compatible with the CT63. S019 recommends it "for CT60/63 alone (no add-on board)". [S019]
- **The release that replaced V5M/V5E** (apparently ABE/SDR 7A, judging by S019's `SDR_V7A.jed` link) made **move16 bursts usable on all expansion-slot addresses**. It also added a new local arbiter (the 2003 one "never tested"), delayed TS by one clock to remove the speed limit above 100 MHz, and changed the watchdog. [S019] The move16 change is the basis for the move16 transfer rates to and from SV RAM in [../software/drivers.md](../software/drivers.md#performance-notes-for-programmers).
- **ABE_V7F / SDR_V7D (January 2012), the latest:** modified the local arbiter between the F030, the 68060 and the expansion slot ("CTPCI, SuperVidel"), so that Radeon and NEC USB cards and SDMA + BLiTTER can run together. It also added CTPCI IDE port support and a new watchdog timing. [S019] Given the V5M/V5E recommendation above, V7F/V7D is presumably the version to use with an add-on board such as the SV. **(inferred)**
- The CT60's CPLDs are programmed over JTAG with Xilinx iMPACT, the same tool used to recover the SV's PROMs. [S018][S019]

Whether a particular SV firmware needs a minimum ABE/SDR version isn't documented in the sources so far.

### JTAG chain

Two separate JTAG paths reach the PROMs [S010]:

- **HW_JTAG:** from the 14-pin JTAG connector (JP2) through both PROMs, for a Xilinx Platform USB cable. This is the recovery route when an update fails; see [../software/drivers.md](../software/drivers.md#recovery-over-jtag-xilinx-impact). [S012][S018]
- **SW_JTAG:** driven by the FPGA itself, and controlled by the CPU through the JTAG control register at `$80010054` ([registers.md](registers.md)). This is what allows firmware updates from the Atari with no cable.

### Connectors and jumpers

| Ref | Function | Ref |
|-----|----------|-----|
| CT60 address and data connectors | Host bus. The front and back 50-pin headers pass through upward, so other boards can stack on top | [S010][S012] |
| J7 | Jumper that enables the CT60 clock filter. Fit it only if the SV is the lowest board on the CT60, since only one board in the stack may filter the clock | [S012] |
| JP7 | Motherboard clock input, a right-angle 6-pin header (6-wire flat cable). The manual describes connecting only the VGA (25.175 MHz) clock: wire 4 to the clock and wire 3 to ground, counting from the red wire as #1. The motherboard solder point is next to the 25.175 MHz oscillator near the Videl | [S012] |
| JP4 | Flat-cable connector used with the SVEthLANa when an EtherNat is also stacked on the SV | [S012] |
| Expansion / SVEthLANa FPC | 45-pin FPC: 18 data lines, 3.3 V, GND | [S010] |
| JP2 | 14-pin JTAG (2 mm pitch, keyed), near the DVI connector, for the Xilinx Platform Cable USB. It's on the HW_JTAG chain through both PROMs | [S010][S018] |

S010 shows separate "Motherboard CLK connector" and "Expansion/SVEthLANa FPC" blocks; S012 names JP7 and JP4. That JP7 is the motherboard CLK connector is clear from S012. Whether JP4 is the 45-pin FPC itself or a separate header is **not yet confirmed**.

**Discrepancy:** S001 says the clock cable has "4 wires" covering both the 25.175 MHz and 32 MHz clocks. S012 supplies a 6-wire cable and wires only the VGA clock, because RGB modes weren't supported yet.

### Board revisions

- The v2 layout drawing in S012 (p. 8) is labelled "SuperVidel v2".
- Register `$80010000` bit 18 reads 1 on revision 1 hardware and 0 on revision 2. [S011]
- The blue prototype photographed in January 2009 [S003] is earlier than both; the production boards were orange [S001].
- A 2022 re-layout ("SuperVidel v2022") and the Zynq-based SV3 are covered in [revisions.md](revisions.md).

## FPGA design (VHDL)

S010's VHDL diagram shows these blocks, colour-coded by clock domain:

| Block | Clock domain | Function |
|-------|--------------|----------|
| CT60 bus interface | CT60 clock | Decodes CPU accesses to all internal blocks |
| Videl regs and translation | CT60 | Emulates the Videl registers and translates them into SV timing ("translated Videl regs") |
| SV regs | CT60 | Native SV registers (`$80010000`…), feed the blitter, SVEthLANa settings and I²C |
| I²C CDCE937 | CT60 | Programs the clock chip (from the PLL registers) |
| TFP410 init | CT60 | Sets up the DVI transmitter over I²C |
| Ethernet MAC controller | CT60 | Ethernet MAC with an MII interface to the SVEthLANa PHY |
| Palette | CT60, with VGA and DVI lookup ports | 256-entry palette, read separately by each pipeline |
| CT60–DDR2 bridge | CT60 / DDR2 | CPU access to graphics RAM; makes bus requests to the arbiter |
| MUX ×2 | — | For each output, picks the translated Videl resolution or the SV settings. These are controlled by the SV mode and VGA/DVI protect bits [S011] |
| VGA pipeline (with data fetch) | VGA clock | Fetches pixels from DDR2, looks up the palette, outputs RGB24 and sync |
| DVI pipeline (with data fetch) | DVI clock | Same as VGA, for the DVI output |
| SuperBlitter | DDR2 clock | Reads and writes through the DDR2 cache |
| DDR2-bus arbiter | DDR2 | Shares DDR2 between the CT60 bridge, blitter, VGA pipeline and DVI pipeline |
| DDR2 cache | DDR2 | Sits between all users and the controller |
| DDR2 controller | DDR2 | 32-bit DDR2 interface |

Points worth noting for developers:

- **Each output has its own pipeline, clock and multiplexer**, so VGA and DVI can show different resolutions. The two register blocks (`$80010014`… and `$80010034`…) match this.
- **The Ethernet MAC is in the SV FPGA.** The SVEthLANa board carries the PHY and the RJ45 MagJack and connects over MII through the expansion connector. [S005][S010]
- **The SV can't see the motherboard BLiTTER's writes.** With the built-in TOS VDI, which uses the BLiTTER, the screen shows garbage unless NVDI or the SV drivers are used. [S012]

[S001]: ../../sources/INDEX.md
[S003]: ../../sources/INDEX.md
[S005]: ../../sources/INDEX.md
[S010]: ../../sources/INDEX.md
[S011]: ../../sources/INDEX.md
[S012]: ../../sources/INDEX.md
[S018]: ../../sources/INDEX.md
[S019]: ../../sources/INDEX.md
