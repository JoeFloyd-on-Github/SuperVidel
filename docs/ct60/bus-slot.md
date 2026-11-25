# CT60 060 Bus Slot

> Source: CT60 hardware guide, Rev 5.2 [S022]. This is the connector the SuperVidel (and the CTPCI) plugs into.

## Physical

Two **HE13 male headers, 2×25 pins each** (100 pins): the **address connector** (A) and the **data connector** (D). Boards that stack on top pass both headers through upward. The SV installation manual calls them "the upward going 50 pin headers on the front and back sides" and warns to press only on them when seating the board. [S012][S022]

The slot was designed for "future daughter cards like the PCI adaptor or a PPC developers system". The slot can be a **bus master**, because arbitration with the 060 is built into the CT60 logic. [S022]

## Signals

| Group | Signals |
|-------|---------|
| Address / data | A31–A0, D31–D0 (full 060 bus, 32-bit) |
| Transfer control | /TS (transfer start), R/W, /BS0–/BS3 (byte selects), SIZ1–SIZ0, TT1–TT0, TM2–TM0, /TA (transfer acknowledge) |
| Arbitration | /BR, /BG, /BB |
| Errors / reset / interrupts | /TEA (transfer error acknowledge), /RST, **/I6** (card → CT60, level 6), /INT (CT60 → card, for a second CPU) |
| Clock | CLK, the CT60 bus clock (= 060 clock, 66 MHz or more) |
| Power | +5 V, +3.3 V, +12 V, −12 V; each power pin can supply up to 6 A; 9 GND pins |

## Pinout

The manual gives the pinout as a two-column table per connector, with only the corner pins numbered (#A1/#A2 … #A49/#A50). The pin numbers below follow that row order: odd pins on the left, even on the right. The 9 GND pins (A1, A2, A16, A49, A50, D1, D2, D49, D50) match the manual's stated GND count. [S022]

### Address connector

| Pin | Signal | Pin | Signal |
|-----|--------|-----|--------|
| A1 | GND | A2 | GND |
| A3 | +5V | A4 | /BR |
| A5 | /TS | A6 | /BG |
| A7 | R/W | A8 | /BB |
| A9 | SIZ0 | A10 | SIZ1 |
| A11 | /TA | A12 | /TEA |
| A13 | *(not listed)* | A14 | CLK |
| A15 | /RST | A16 | GND |
| A17 | A30 | A18 | A31 |
| … | A28, A26 … A2 | … | A29, A27 … A3 |
| A47 | A0 | A48 | A1 |
| A49 | GND | A50 | GND |

Address lines run in pairs from A17/A18 = A30/A31 down to A47/A48 = A0/A1. So pin A(17+2k) = A(30−2k) and pin A(18+2k) = A(31−2k), for k = 0…15.

### Data connector

| Pin | Signal | Pin | Signal |
|-----|--------|-----|--------|
| D1 | GND | D2 | GND |
| D3 | TM0 | D4 | +12V |
| D5 | TM1 | D6 | −12V |
| D7 | TM2 | D8 | +3.3V |
| D9 | TT0 | D10 | TT1 |
| D11 | /BS0 | D12 | /BS1 |
| D13 | /BS2 | D14 | /BS3 |
| D15 | **/I6** | D16 | /INT |
| D17 | D0 | D18 | D1 |
| … | D2, D4 … D28 | … | D3, D5 … D29 |
| D47 | D30 | D48 | D31 |
| D49 | GND | D50 | GND |

Data lines run upward: pin D(17+2k) = D(2k) and pin D(18+2k) = D(2k+1), for k = 0…15.

**Check before relying on this:** the per-pin numbering is derived from the manual's table layout, not from a schematic. **(derived)**

## Hardware emulation window

This CT60 feature is what makes the SuperVidel possible. The manual lists "SUPER-VIDEL chip in a FPGA with DDR memory" as its first example. [S022]

A card on the 060 slot can **take over any Falcon address** (`$00xxxxxx` and `$FFxxxxxx`):

1. When the 060 starts an access (/TS) to a Falcon address, a counter in ABE60 starts.
2. **Until the end of the 6th CLK cycle**, a slot card may terminate the access itself with /TA, /TEA, or both (both = retry). That cancels the Falcon motherboard access the CT60 had begun.
3. From the **7th cycle** the Falcon read goes ahead and can't be stopped; ABE60 drives the data onto the CT60 bus.

How a card uses this:

- **Card registers:** 2–3 cycles, well inside the window.
- **SDRAM on the card:** 66 MHz burst read 5-1-1-1 and burst write 3-1-1-1. The first /TA comes before the end of cycle 6, so the Falcon access is cancelled.
- **Shadowing a Falcon chip (write to both):** for an address that exists on both boards, the card latches the write but **doesn't assert /TA**. The motherboard's /TA (via ABE) ends the cycle, so the data reaches both the real chip and the card. Example from the manual: a write to `$FFFF820E` goes to both the Videl and the card.
- **Reads of a shadowed register:** the card must assert /TA before cycle 7 to return its own value.
- The manual recommends a **switch bit on the card** to turn emulation on or off. When it's off, the card's copies of the registers live at their own addresses and the card acknowledges normally.

**How this maps onto the SV:** the SV registers' *SV mode*, *VGA protect* and *DVI protect* bits, together with the "Videl regs and translation" block, behave like this on/off emulation: Videl writes reach both the Videl and the SV unless an output is protected. See [../hardware/registers.md](../hardware/registers.md) and [../hardware/architecture.md](../hardware/architecture.md). The detailed timing of the SV's implementation isn't documented. **(inferred)**

Consequences for SV software:

- Writes to Videl registers still go to the real Videl too. That's why the Videl keeps generating its own VBL (`$70`) even in SV modes, as the 2026 driver changelog notes [S014]. The SV driver option `kill_videl` exists to turn the Videl off. [S014]
- The SV can only see accesses that cross the **CT60 bus**. The Falcon BLiTTER's writes stay on the motherboard and aren't seen [S012]; the same presumably applies to any other Falcon-side bus master. **(inferred)**

## Interrupts

The CT60 adds **/I6**, the slot's interrupt line at level 6 with the **highest** priority, and /INT (out to a second CPU). [S022]

| Name | Level | Source | IVR code | Priority |
|------|-------|--------|----------|----------|
| **I6** | 6 | **CT60 bus slot** | `111` | highest |
| INT6 / MFPINT | 6 | Falcon bus slot / MFP | `110` | |
| DSPREQ | 6 | DSP | `110` | |
| INT5 | 5 | SCC | `101` | |
| VBL | 4 (autovector) | Videl VSync | `100` | |
| HBL | 2 (autovector) | Videl HSync | `010` | lowest |

INT1 and INT3 (Falcon bus slot) are **not supported** with the CT60. IVR (`$F3000000`) holds only the level of the pending interrupt, not a vector. [S022]

The SV's own interrupts use vectors `$C6` (SuperBlitter), `$C7` (VGA VSync) and `$C8` (DVI VSync) [S011]. Those are user (vectored) interrupt numbers, so the SV presumably raises **/I6** and supplies its vector during the interrupt-acknowledge cycle. **(inferred)**

## Burst transfers

The 060 transfers **16-byte lines** (4 longwords) to and from cacheable memory. CT60 SDRAM timing at bus clock [S022]:

| Case | Write | Read |
|------|-------|------|
| Page hit | 3-1-1-1 (6 cycles), ~178 MB/s at 66 MHz | 5-1-1-1 (8 cycles), ~132 MB/s |
| Page miss | 7-1-1-1 (10 cycles), ~107 MB/s | 9-1-1-1 (12 cycles), ~89 MB/s |

All SDRAM is **copyback**; ST-RAM is writethrough. Non-burst transfers to SDRAM happen only for locked read-modify-write, table searches, exception vector fetches and stacking, single-dirty-longword pushes, and writes to writethrough pages. [S022] For slot cards, burst support depends on the address window (see [memory-map.md](memory-map.md)) and on the CPLD version (move16 on the slot from the release after V5M/V5E [S019]).

[S011]: ../../sources/INDEX.md
[S012]: ../../sources/INDEX.md
[S014]: ../../sources/INDEX.md
[S019]: ../../sources/INDEX.md
[S022]: ../../sources/INDEX.md
