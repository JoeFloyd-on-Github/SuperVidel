# CT60 Overview

> Source: the CT60 manual [S022] unless marked otherwise. The CT60 hardware was designed by Rodolphe Czuba. The flash TOS, Flash Tool and configuration software are by Didier Méquignon, with Xavier Joubert. [S022]

## Features

| Item | Detail | Ref |
|------|--------|-----|
| CPU | Socketed MC68060: **full** (FPU + PMMU), **LC** (no FPU) or **EC** (no FPU, no PMMU). 66 MHz (mask 1F43G) or 100 MHz (mask 1E41J) | [S022] |
| Bus | The CT60 bus runs at the 060 clock ("full bus mode"): 66 MHz, or 100 MHz on the CT60-100 | [S022] |
| Memory | One PC100/PC133 SDRAM DIMM socket, 64–512 MB, mapped like TT-RAM from `$01000000`. **The CT60 won't run without SDRAM** | [S022] |
| Flash | 1 MB, holding the patched TOS 4.04 plus boot, setup and 060 init. Replaces the TOS ROM in 060 mode | [S022] |
| Falcon mode | Switch between the 060 and the Falcon's own 68030; 030 mode is a plain Falcon (with 68882) | [S022] |
| Expansion | **060 bus slot**: two 2×25-pin HE13 male headers (100 pins). This is where the SuperVidel plugs in. See [bus-slot.md](bus-slot.md) | [S022] |
| Falcon bus | Untouched; existing Falcon-bus cards still work | [S022] |
| Power | Needs an **ATX power supply** (3.3 V at 8 A or more), which replaces the Falcon PSU. Supports soft power-off (SLP register) and +5VSB | [S022] |
| Fitting | No soldering needed. Optional 6-wire "boost" of the Falcon board (DSP and Videl at 40 MHz, bus at 20 MHz) | [S022] |
| CPLDs | Two Xilinx **XC95144XL** CPLDs: **SDR60** (SDRAM controller, I²C, thermal sensor, interrupts) and **ABE60** (bus interface, flash, power) | [S022] |

### SDRAM requirements

Unbuffered, 64-bit (no parity/ECC), PC100/PC133 CL2 DIMMs built from chips with **4 internal banks**. Not supported: 8/16/32 MB DIMMs, registered/buffered DIMMs, DIMMs with 2-bank chips or 32-bit-wide chips, and single-sided 512 MB DIMMs. Best performance comes with 16 KB page-length modules. [S022]

### Performance (from the manual, NemBench 2.1)

| Board | Bus | Read | Write |
|-------|-----|------|-------|
| CT60-100 | 100 MHz | 104.4 MB/s | 102.8 MB/s |
| CT60 | 66 MHz | 73.8 MB/s | 72.6 MB/s |
| Falcon (VGA 16 colours) | 16 MHz | 4.55 MB/s | 5.5 MB/s |

68060 at 66 MHz ≈ 96.8 MIPS; at 100 MHz ≈ 147 MIPS. [S022]

## Clock options

- **CT60-100:** for stability at 100 MHz, cut pin 9 of the CY2309 (IC3) next to the oscillator. [S022] The CT60 update page has a related "CYpin9_cut" image. [S019]
- **Programmable clock modules** in the oscillator socket, set over the SDRAM DIMM's I²C lines: the ak-modul-bus module (Cypress CY27EE16, 125 kHz steps) or the **CTCM** (Dallas DS1085Z-50). [S022] The SV installation manual warns that the CTCM is the tallest part on the CT60 and can block the SV from seating fully. [S012]
- Extra boards on the CT60 bus add load and reflections, which may lower the maximum 060 clock. [S012]

## Family

| Board | Notes | Ref |
|-------|-------|-----|
| CT60 (2003) | The original. First-run boards need a trace/pin cut (CY2309 pin 9) before **any** ABE/SDR update | [S019] |
| CT60-100 | 100 MHz variant (see clock above) | [S022] |
| CT63 | Uses the same CPLD firmware as the CT60. Differences not yet documented | [S019] |
| CT60e | Moves the board forward, out of the keyboard's way, so SV + EtherNat fit in the original case. Has its own TOS build (1.03d = "CT60e TOS 1.03c") | [S015][S020] |
| CTPCI | PCI board on the same 060 bus slot, shares the bus with the SV | [S012][S019] |

## CPLD firmware (ABE60 / SDR60)

| Version | Date | Changes relevant to an SV | Ref |
|---------|------|---------------------------|-----|
| ABE_V5M / SDR_V5E | 2006 | Initial CT60 version (CT63-compatible). Recommended "for CT60/63 alone (no add-on board)" | [S019] |
| (apparently ABE/SDR 7A) | — | **move16 bursts usable on all expansion-slot addresses**; new local arbiter; TS delayed one clock (no speed limit above 100 MHz); boot from ABE flash without a TOS chip | [S019] |
| **ABE_V7F / SDR_V7D** | 2012-01 | Local arbiter changed for the F030, the 060 and the expansion slot ("CTPCI, SuperVidel"); CTPCI IDE support; new watchdog | [S019] |

The CPLDs are programmed over JTAG: from a PC with Xilinx iMPACT, or from the Falcon's parallel port with a modified cable and Flash Tool. See [software.md](software.md#flash-tool-and-jtag). [S019][S022]

[S012]: ../../sources/INDEX.md
[S015]: ../../sources/INDEX.md
[S019]: ../../sources/INDEX.md
[S020]: ../../sources/INDEX.md
[S022]: ../../sources/INDEX.md
