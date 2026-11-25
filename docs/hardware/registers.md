# SuperVidel Register Reference

> Source: *SuperVidel Memory Map*, Rev 1, 2012-03-12 [S011], unless marked otherwise. All registers are 32 bits wide and must be accessed as longwords. "R" = read-only, "R/W" = read/write, "W" = write-only. Reset values marked `?` depend on hardware state.

## Register summary

| Address | Name | Access |
|---------|------|--------|
| `$80010000` | General settings/status | R/W |
| `$80010004` | CDCE925 PLL1 reg 1 (DDR clock) | W |
| `$80010008` | CDCE925 PLL1 reg 2 (DDR clock) | W |
| `$8001000C` | CDCE925 PLL2 reg 1 (video clock) | W |
| `$80010010` | CDCE925 PLL2 reg 2 (video clock) | W |
| `$80010014` | VGA screen address | R/W |
| `$80010018` | VGA horizontal data begin/end | R/W |
| `$8001001C` | VGA horizontal sync | R/W |
| `$80010020` | VGA vertical data begin/end | R/W |
| `$80010024` | VGA vertical sync | R/W |
| `$80010028` | VGA last horizontal/vertical position | R/W |
| `$8001002C` | VGA data amount | R/W |
| `$80010030` | VGA video mode | R/W |
| `$80010034` | DVI screen address | R/W |
| `$80010038` | DVI horizontal data begin/end | R/W |
| `$8001003C` | DVI horizontal sync | R/W |
| `$80010040` | DVI vertical data begin/end | R/W |
| `$80010044` | DVI vertical sync | R/W |
| `$80010048` | DVI last horizontal/vertical position | R/W |
| `$8001004C` | DVI data amount | R/W |
| `$80010050` | DVI video mode | R/W |
| `$80010054` | JTAG control | R/W |
| `$80010058` | SuperBlitter source 1 address | R/W |
| `$8001005C` | SuperBlitter source 2 address | R/W |
| `$80010060` | SuperBlitter destination address | R/W |
| `$80010064` | SuperBlitter line byte count / alpha | R/W |
| `$80010068` | SuperBlitter source 1 line offset | R/W |
| `$8001006C` | SuperBlitter source 2 line offset | R/W |
| `$80010070` | SuperBlitter destination line offset | R/W |
| `$80010074` | SuperBlitter address mask / number of lines | R/W |
| `$80010078` | SuperBlitter control/status | R/W |

The VGA block (`$80010014`–`$80010030`) and the DVI block (`$80010034`–`$80010050`) are laid out the same way; the DVI block starts `$20` higher.

## Interrupt vectors

| Vector | Address | Source | Enabled by |
|--------|---------|--------|------------|
| `$C6` | `$318` | SuperBlitter job done | `$80010078` bit 5 |
| `$C7` | `$31C` | VGA vertical sync | `$80010000` bit 19 |
| `$C8` | `$320` | DVI vertical sync | `$80010000` bit 21 |

Install the handler in the vector before enabling the interrupt. Each handler must clear its "done" flag by writing 0 to it. [S011]

---

## `$80010000`: General settings/status

| Bit | Name | Access | Reset |
|-----|------|--------|-------|
| 31:24 | Reserved | R | `$00` |
| 23 | Reserved | R | 0 |
| 22 | DVI VSYNC interrupt flag | R/W | 0 |
| 21 | DVI VSYNC interrupt enable | R/W | 0 |
| 20 | VGA VSYNC interrupt flag | R/W | 0 |
| 19 | VGA VSYNC interrupt enable | R/W | 0 |
| 18 | HW revision | R | ? |
| 17 | DVI protect | R/W | 0 |
| 16 | VGA protect | R/W | 0 |
| 15 | DVI clock is from clock chip | R | ? |
| 14 | DVI Videl clock is 25.175 MHz | R | ? |
| 13 | VGA clock is from clock chip | R | ? |
| 12 | VGA Videl clock is 25.175 MHz | R | ? |
| 11 | Videl 25.175 MHz valid | R | ? |
| 10 | Videl 32 MHz valid | R | ? |
| 9:8 | Monitor type | R/W | `%10` |
| 7 | DVI connected | R | 0 |
| 6 | SV mode | R | 1 |
| 5 | DVI Hsync active | R | ? |
| 4 | DVI Vsync active | R | ? |
| 3 | VGA Hsync active | R | ? |
| 2 | VGA Vsync active | R | ? |
| 1 | DVI reset | R/W | 1 |
| 0 | VGA reset | R/W | 1 |

- **VGA reset / DVI reset (bits 0, 1):** 1 holds that output's video logic in reset, so nothing is displayed. Both are 1 after reset.
- **Sync active (bits 2–5):** 1 while a horizontal or vertical sync pulse is in progress on that output.
- **SV mode (bit 6):** 1 when the SuperVidel registers were written last, so they define the current resolution. It becomes 0 when Videl registers are written, and the resolution then comes from the Videl registers. A copy of this bit is at `$FFFF82C0.w` bit 8, so code that saves and restores the Videl registers also saves and restores this bit, and the SV can return to the right mode.
- **DVI connected (bit 7):** 1 if a DVI monitor that is switched on is attached.
- **Monitor type (bits 9:8):** a *fake* monitor type, used only for Videl compatibility. It applies to the analogue (VGA) output only, and the hardware does not detect the real monitor.

  | Value | Monitor |
  |-------|---------|
  | `%00` | Monochrome |
  | `%01` | RGB colour |
  | `%10` | VGA colour (reset value) |
  | `%11` | TV |

- **Videl 32 MHz / 25.175 MHz valid (bits 10, 11):** the motherboard clock arrives over the JP7 cable and is toggling. These bits don't check the frequency. [S011] The installation manual says the SV uses the motherboard clock only when it detects it, and otherwise generates the VGA clock itself with an error of a few ppm. [S012]
- **VGA / DVI Videl clock is 25.175 MHz (bits 12, 14):** the clock multiplexer for that output has selected the 25.175 MHz Videl clock (1) rather than the 32 MHz one (0).
- **VGA / DVI clock is from clock chip (bits 13, 15):** that output's clock comes from the CDCE9xx clock chip (1) rather than from a Videl 25.175 or 32 MHz clock (0).
- **VGA / DVI protect (bits 16, 17):** 1 stops that output from switching to a Videl resolution when Videl registers are written. Both are 0 after reset, so a Videl resolution appears on both outputs. These bits make it possible to keep one output in a SuperVidel mode while a program reprograms the Videl.
- **HW revision (bit 18):** 1 = revision 1 hardware, 0 = revision 2.
- **VSYNC interrupts (bits 19–22):** setting an enable bit makes that output raise an interrupt at vertical sync and set its flag. Clear the flag in the handler by writing 0. Vectors are listed above.

## `$80010004`–`$80010010`: Clock chip PLLs

These four write-only registers program the two PLLs of the TI clock chip. The register bytes come from the *CDCE925 ClockFinder* tool (see [../software/drivers.md](../software/drivers.md)), which calculates settings for a target frequency from the 25 MHz crystal.

| Address | PLL | Bits 31:24 | 23:16 | 15:8 | 7:0 | Reset |
|---------|-----|-----------|-------|------|-----|-------|
| `$80010004` | PLL1 (DDR clock), reg 1 | chip reg `$17` | `$18` | `$19` | `$1A` | `$01069013` |
| `$80010008` | PLL1 (DDR clock), reg 2 | — | — | — | chip reg `$1B` | `$00000047` |
| `$8001000C` | PLL2 (video clock), reg 1 | chip reg `$27` | `$28` | `$29` | `$2A` | `$00000000` |
| `$80010010` | PLL2 (video clock), reg 2 | — | — | — | chip reg `$2B` | `$00000000` |

**Order matters:** write reg 1 first. Writing reg 2 starts the update to the chip. [S011]

S011 calls the chip a CDCE925; the hardware block diagram in S010 labels it a **CDCE937**. Both are TI programmable clock synthesizers configured over I²C. **Which part is fitted (and whether it changed between board revisions) is not settled.**

## Video timing registers (VGA `$80010014`–`$80010030`, DVI `$80010034`–`$80010050`)

The offsets below are relative to the start of each block (VGA `$80010014`, DVI `$80010034`).

### +`$00`: Screen address

| Bits | 31:27 | 26:1 | 0 |
|------|-------|------|---|
| Field | Reserved | Video address | always 0 |

This is a 27-bit byte address with bit 0 forced to 0, so the screen must start at an even address. See [memory-map.md](memory-map.md) for how it probably relates to CPU addresses.

### +`$04`: Horizontal data begin/end

| Bits | 31:27 | 26:16 | 15:11 | 10:0 |
|------|-------|-------|-------|------|
| Field | Reserved | Hor. data begin | Reserved | Hor. data end |

These are the positions on a scanline where the visible data window begins and ends, counted in pixel clocks. **Divide the calculated value by 2 before writing it.**

### +`$08`: Horizontal sync

| Bits | 31 | 30:27 | 26:16 | 15:11 | 10:0 |
|------|----|-------|-------|-------|------|
| Field | Polarity | Reserved | Hsync begin | Reserved | Hsync end |

Polarity 1 = active-high sync pulse (reset value 1). Begin and end are in pixel clocks. **Divide the calculated value by 2 before writing it.**

### +`$0C`: Vertical data begin/end

The layout is the same as the horizontal data register, but values are in scanlines and are **not** halved.

### +`$10`: Vertical sync

The layout is the same as the horizontal sync register (polarity in bit 31, reset 1), with values in scanlines. (In the DVI version, S011's bit table repeats the "Hor. sync" field names, which looks like a copy-paste slip. Its description says vertical sync.)

### +`$14`: Last horizontal/vertical position

| Bits | 31:27 | 26:16 | 15:11 | 10:0 |
|------|-------|-------|-------|------|
| Field | Reserved | Last horizontal position | Reserved | Last vertical position |

These are the last values the counters reach before wrapping to 0, i.e. the total line length minus 1 and the total frame height minus 1. **Divide the horizontal value by 2 before writing it**; the vertical value is in lines and isn't halved.

### +`$18`: Data amount

| Bits | 31:30 | 29:16 | 15:14 | 13:0 |
|------|-------|-------|-------|------|
| Field | Reserved | Virtual screen data | Reserved | Visible screen data |

- **Virtual screen data:** bytes per virtual row, i.e. the visible bytes plus the bytes skipped at the end of each row. Bit 16 is always 0, so the value must be a whole number of 16-bit words.
- **Visible screen data:** bytes per visible row. Bits 3:0 are always 0, so the value must be a multiple of 16; round up, and any extra data read is discarded.

### +`$1C`: Video mode

| Bits | 31:6 | 5 | 4 | 3 | 2:0 |
|------|------|---|---|---|-----|
| Field | Reserved | Line doubling | Double pixel width | ST compatibility | Video mode |

| Bits 2:0 | Mode |
|----------|------|
| `%000` | 1-bit bitplane (Falcon030 compatible) |
| `%001` | 2-bit bitplane (Falcon030 compatible) |
| `%010` | 4-bit bitplane (Falcon030 compatible) |
| `%011` | 8-bit bitplane (Falcon030 compatible) |
| `%100` | 8-bit chunky |
| `%101` | 16-bit high colour (Falcon030 compatible) |
| `%110` | Reserved |
| `%111` | 32-bit true colour (24-bit RGB + alpha byte) |

- **ST compatibility (bit 3):** "No effect right now" (as of 2012-03-12).
- **Double pixel width (bit 4):** halves the horizontal resolution, for example 320 pixels wide on 640×480 VGA timing.
- **Line doubling (bit 5):** draws each line twice, for example 240 lines on 640×480 VGA timing.

## `$80010054`: JTAG control

This register lets the CPU drive the JTAG chain between the FPGA and its two configuration PROMs. The firmware updater SV-JTAG.TTP presumably uses it to program the PROMs. **(unverified)** [S012]

| Bit | Name | Access | Reset |
|-----|------|--------|-------|
| 31 | JTAG enable | R/W | 0 |
| 30:16 | Magic key | W | 0 |
| 15:4 | Reserved | R | 0 |
| 3 | TCK | R/W | 0 |
| 2 | TMS | R/W | 1 |
| 1 | TDI | R/W | 1 |
| 0 | TDO | R | ? |

- **Magic key:** bits 30:16 must be `%101010101010101` (`$5555`) in **every** write that changes the JTAG bits.
- **JTAG enable:** 0 = JTAG pins tri-stated; 1 = the FPGA drives the JTAG pins to the PROMs.
- **TDO:** the level of TDO coming from the PROMs.
- **TCK / TMS / TDI:** writing sets the output level. Reading returns the FPGA's internal value, not the pin, so this register can't detect an external JTAG cable driving the lines.

## SuperBlitter (`$80010058`–`$80010078`)

The SuperBlitter isn't compatible with the original Falcon BLiTTER [S001]. It works on DDR2 graphics memory and internally moves 64-bit words. [S011]

| Address | Register | Fields |
|---------|----------|--------|
| `$80010058` | Source 1 address | bits 26:0: byte address of the main source |
| `$8001005C` | Source 2 address | bits 26:0: byte address of the second source, used only by modes that combine src1 and src2 |
| `$80010060` | Destination address | bits 26:0: byte address |
| `$80010064` | Line byte count | bits 10:0: bytes per line **minus 1** (0 = 1 byte); bits 31:24: alpha value for mode `%0111` |
| `$80010068` | Source 1 line offset | bits 26:0: added to the line start address after each line |
| `$8001006C` | Source 2 line offset | as above, for src2 |
| `$80010070` | Destination line offset | as above, for the destination |
| `$80010074` | Mask / lines | bits 31:24: src1 address count mask; bits 23:16: src2 address count mask; bits 11:0: number of lines |
| `$80010078` | Control/status | see below |

**Line offsets** are 27-bit values. A negative offset (counting backwards) is written with bit 26 set, i.e. 27-bit two's complement.

**Address count masks** make the source address counter wrap, which is useful for repeating patterns. Valid values are 0, 1, 2, 4, … 128 (powers of 2), counted in **64-bit words**, not bytes. The mask applies only to the counter that is added to the base address, not to the base address itself. 0 disables masking, although the counter can only reach 255 anyway.

S011 is inconsistent about the alpha field at `$80010064` bits 31:24: its access is listed as "R", but the text says it supplies the alpha value for mode `%0111`, so it presumably has to be writable.

### `$80010078`: Control/status

| Bit | Name | Access | Reset |
|-----|------|--------|-------|
| 31:7 | Reserved | R | 0 |
| 6 | Done interrupt flag | R/W | 0 |
| 5 | Interrupt enable | R/W | 0 |
| 4:1 | Blit mode | R/W | `%0000` |
| 0 | Busy (read) / Start (write) | R/W | 0 |

- **Start/Busy:** wait until bit 0 reads 0, set up the other registers, then write 1 to start. Bit 0 reads 1 while a blit is in progress.
- **Interrupts:** with bit 5 set, the blitter raises an interrupt on vector `$C6` (address `$318`) when the job finishes and sets bit 6. The handler clears bit 6 by writing 0.

### Blit modes (bits 4:1)

S011 notes that the codes are "not enumerated in the expected order": all the defined modes have the low bit set except mode `%0000`.

| Code | Operation |
|------|-----------|
| `%0000` | `dest = src1` (plain copy) |
| `%0001` | `dest = src1` where `src2 ≠ 0`, else `dest` unchanged. Compares **byte by byte**. For 8-bit chunky sprites, src1 = src2 = sprite data; for 16-bit sprites, src1 = sprite data and src2 = mask. |
| `%0011` | `dest = src1 × src1.alpha + src2 × (256 − src1.alpha)`: 32-bit RGBA alpha blend using src1's per-pixel alpha |
| `%0101` | `dest = src1` where bit 5 of the src1 16-bit word is 1 (bit 0 of green in 16-bit mode), else `dest` unchanged. Gives a colour-key transparency for 16-bit graphics. |
| `%0111` | `dest = src1 × alpha_reg + src2 × (256 − alpha_reg)`: 32-bit alpha blend with one alpha value for the whole block, from `$80010064` bits 31:24 |
| all others | Reserved |

Note on mode `%0111`: S011's description of `$80010064` says src2 is weighted by "255 − alpha", but the formula in the mode table uses 256. One of them is a typo in the source.

---

## Open questions

- The emulated Videl register set (`$FFFF82xx`): which registers are supported, and where the 8-bit chunky control bit is.
- Whether the 27-bit screen and blitter addresses are offsets from `$A0000000`. **(unverified)**
- Whether the clock chip is a CDCE925 or a CDCE937.
- Whether the SVEthLANa and Ethernet MAC have their own interrupt vector.
- What changed in later firmware: S011 is Rev 1, from before boards shipped.

[S001]: ../../sources/INDEX.md
[S011]: ../../sources/INDEX.md
[S012]: ../../sources/INDEX.md
