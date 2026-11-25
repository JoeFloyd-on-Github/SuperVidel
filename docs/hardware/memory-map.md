# Memory Map

> Primary source: *SuperVidel Memory Map*, Rev 1, 2012-03-12 [S011]. This was the register reference for firmware of that time; later firmware may differ. Full register details are in [registers.md](registers.md).

All addresses are 68060/CT60 physical addresses. All SV ranges are in the CT60's non-cacheable 060 bus slot window (`$80000000`–`$BFFFFFFF`) or in the Falcon shadow (`$FFxxxxxx`); see [../ct60/memory-map.md](../ct60/memory-map.md).

## Overview

| Range | Size | Access | Contents | Ref |
|-------|------|--------|----------|-----|
| `$80010000`–`$8001007F` | 32 longs | Long only | SuperVidel control registers: general, clock PLL, VGA timing, DVI timing, JTAG, SuperBlitter (S011), plus the firmware version register at `$8001007C` (S021) | [S011][S021] |
| `$80012000`–`$80012053` | 84 bytes | Long, R/W | Ethernet MAC core control registers | [S011] |
| `$80012400`–`$800127FF` | 1 KB | Long, R/W | Ethernet MAC buffer descriptors | [S011] |
| `$80012800`–`$80013FFF` | 6 KB | Long, R/W | Ethernet MAC packet data buffers | [S011] |
| `$A0000000`–`$A0FFFFFF` | 16 MB | — (none listed) | Shadow of ST-RAM in DDR2 SDRAM | [S011] |
| `$A1000000`–`$A7FFFFFF` | 112 MB | Byte/Word/Long, R/W | General-purpose graphics RAM in DDR2 SDRAM | [S011] |
| `$FFFF8200` area | — | — | Emulated Videl registers (see below) | [S001][S011] |
| `$FFFF9800`–`$FFFF9BFF` | 1 KB | Byte/Word/Long, R/W | 256-colour palette (24-bit entries) | [S011] |

The two DDR2 ranges add up to 128 MB, matching the 2 × 512 Mbit DDR2 chips on the board ([S010]; see [architecture.md](architecture.md)).

### DDR2 RAM

- **`$A0000000`, 16 MB: ST-RAM shadow.** S011 describes it only as "Shadow of ST-RAM in DDR2 SDRAM" and lists no access types. How the shadow is kept up to date (for example by snooping CPU writes to ST-RAM, which is how Videl-mode screens could be shown from DDR2) is not documented. **(unverified)**
- **`$A1000000`, 112 MB: graphics RAM.** Readable and writable at byte, word and long sizes. The drivers put the screen here; S012 calls it "fast video memory".

### Screen address registers vs CPU addresses

The VGA/DVI screen address registers and the SuperBlitter address registers are 27 bits wide (bits 26:0), which spans exactly 128 MB. That suggests they're offsets into the DDR2 (so CPU address = `$A0000000` + offset), but S011 doesn't say so. **(unverified)**

## Emulated Videl registers

The SV decodes writes to the original Videl registers and translates them into its own video timing ("Videl regs and translation" in the VHDL diagram [S010]). The mechanism is presumably the CT60's [hardware emulation window](../ct60/bus-slot.md#hardware-emulation-window), which the CT60 manual describes with a "SUPER-VIDEL chip" as its example **(inferred)** [S022]. S011 doesn't list these registers but mentions:

- **`$FFFF82C0.w` bit 8:** a copy of the *SV mode* status bit (`$80010000` bit 6). Programs that save and restore the Videl registers will save and restore this bit too, so the SV knows whether to go back to a SuperVidel or a Videl resolution. [S011]
- S001 says a control bit for 8-bit chunky mode was added in the `$FF82xx` Videl register range; which register and bit is not documented yet. [S001]

## Palette

`$FFFF9800` is the same address as the Falcon's own 256-entry palette. S011 defines each longword entry as:

| Bits | 31:24 | 23:16 | 15:8 | 7:0 |
|------|-------|-------|------|-----|
| Field | Red | Green | Reserved (reads 0) | Blue |

All three channels are 8 bits. (The original Videl uses only 6 bits per channel in the same layout; S011 doesn't say whether the SV ignores the low bits in Videl modes.) The VHDL diagram shows separate VGA and DVI palette lookups, but S011 documents only one palette address. [S010][S011]

## Ethernet MAC

The Ethernet MAC is inside the SuperVidel FPGA [S010]; the SVEthLANa daughterboard supplies only the physical interface (see [architecture.md](architecture.md)). For register details S011 refers to two external documents, `eth_speci.pdf` (section 3; section 4.2.2) and `eth_design_document.pdf` (section 2.3.7.3). Neither is in our sources yet. A 2026 article confirms the MAC is the **OpenCores** Ethernet MAC [S013], so these are presumably that project's specification and design documents. FW010's transmit DMA has known hardware issues; see [../software/drivers.md](../software/drivers.md#fw010-dma-hardware-issues).

- Data buffers: 3 × 2048-byte blocks forming 4 packet buffers of 1536 bytes each.
- **Write the data buffers with longword accesses only.** Byte or word writes corrupt data. [S011]

[S001]: ../../sources/INDEX.md
[S010]: ../../sources/INDEX.md
[S011]: ../../sources/INDEX.md
[S013]: ../../sources/INDEX.md
[S021]: ../../sources/INDEX.md
[S022]: ../../sources/INDEX.md
