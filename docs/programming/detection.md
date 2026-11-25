# Detecting and Identifying a SuperVidel

> Sources: CT60 TOS 3.00 source code [S021] (`flash.tos/src/ct60tos/videl2.S`, `sdram.S`, `svxbios.S`; `cpx/src/ct60conf.cpx/ct60conf.c`), with the register definitions from [S011]. The code here is described from what CT60 TOS does; it isn't an official Nature API.

## 1. From a normal program: the `SupV` cookie

When the SV XBIOS is installed (`SV_XBIOS.PRG` in AUTO, or built into CT60 TOS 3.00), there is a **`SupV`** cookie (`$53757056`) in the cookie jar. `CT60CONF.CPX` uses this to decide whether to show its SuperVidel page. [S021]

```c
long value;
int have_sv = Getcookie('SupV', &value) == C_FOUND;   /* or your own cookie-jar walk */
```

What the cookie's value contains isn't documented in the sources so far.

The cookie tells you the **driver** is installed, not just that the board is fitted. A board with no driver (for example after booting CT60 TOS 3.00 with Left Shift held) has no cookie.

## 2. Probing the hardware directly (supervisor mode)

CT60 TOS probes for the board by reading the first SV control register with a temporary bus-error handler. If nothing answers at `$80010000`, the access raises a bus error. [S021]

```asm
; D0 = 1 if a SuperVidel answers, 0 if not.  Supervisor mode.
sv_probe:
    move.w  sr,-(sp)
    or.w    #$0700,sr           ; mask interrupts
    movec   vbr,a0
    move.l  8(a0),-(sp)         ; save bus error vector
    lea     .buserr(pc),a1
    move.l  a1,8(a0)
    move.l  sp,a1               ; stack marker to unwind the 060 frame
    moveq   #1,d0
    nop
    tst.b   $80010000           ; SV general settings/status register
    nop
    bra.s   .restore
.buserr:
    move.l  a1,sp               ; discard the access-error frame
    moveq   #0,d0
.restore:
    movec   vbr,a0
    move.l  (sp)+,8(a0)
    move.w  (sp)+,sr
    rts
```

This is simplified from `sv_probe` in `videl2.S`, which also saves A0/A1. **The probe relies on `$80000000` and up being cache-inhibited and precise.** CT60 TOS sets DTT0/ITT0 to `$807FE040` early in boot, so an unclaimed access faults synchronously. If you've changed the MMU or TT registers, make sure the probe address is still non-cacheable and precise. [S021]

CT60 TOS stores the answer in a phystop-relative variable (`sv_present`, offset −72: −1 = not probed, 0 = absent, 1 = present). This is internal to TOS; don't rely on it from applications. [S021]

## 3. Hardware revision and firmware version

Read in supervisor mode (CT60 TOS does this at boot to print `SuperVidel rev.N (FWnnn, internal/external clock, DVI)`): [S021]

| What | How | Ref |
|------|-----|-----|
| Hardware revision | `$80010000` bit 18: 1 → rev 1, 0 → rev 2 | [S011][S021] |
| **Firmware version** | **`$8001007C`, bits 9:0** (`and.l #$3FF`), shown as decimal, e.g. "FW010" | [S021] |
| Motherboard Videl clocks seen | `$80010000` bits 11:10 (non-zero → TOS prints "external clock") | [S011][S021] |
| DVI monitor connected | `$80010000` bit 7 | [S011][S021] |

`$8001007C` is **not** in the 2012 register map [S011], which ends at `$80010078`. It was presumably added in later firmware.

## 4. Things to avoid when an SV is present

- **Don't measure the Videl clocks.** TOS's normal boot code switches the Videl between its internal and external clocks and times VBLs to measure them, and that locks up a SuperVidel early in boot. With an SV present, CT60 TOS 1.03e and later skip the measurement. Instead they force the internal clock (clear bit 0 of `$FFFF820A`) and create the cookies **`_FRQ` = 25** (internal clock, MHz) and **`_FRE` = 0** (no external clock). [S020][S021]
- **Don't assume the screen is in ST-RAM.** With the SV XBIOS active, `_v_bas_ad` points into SV graphics RAM. CT60 TOS 3.00 has to patch the TOS memory test, which otherwise uses `_v_bas_ad` as the end of ST-RAM. [S021]
- **Don't draw with the motherboard BLiTTER on an SV screen.** The SV can't see those writes. [S012]

## 5. Boot-time SV configuration (CT60 TOS 3.00)

With CT60 TOS 3.00 the SV XBIOS settings are kept in the CT60's flash parameter area, not in `SV.INF`. They are read and written with the CT60 XBIOS call `ct60_rw_parameter` (opcode `$C60B`), parameter type **`CT60_SV_CONFIG` = 6**. [S021]

The 32-bit value:

| Bits | Meaning |
|------|---------|
| 31:16 | Boot mode code (e.g. `$401A`); 0 = no SV boot mode set |
| 15:12 | Layout version: 1 = current, 0 = never written, `$F` = erased flash |
| 7 | `CT60_SV_DVI`: primary output (0 = VGA, 1 = DVI) |
| 6 | `CT60_SV_PMMU_BOOST`: higher CPU↔VRAM bandwidth |
| 5 | `CT60_SV_KILL_VIDEL`: Videl off in SV resolutions |
| 4 | `CT60_SV_FAST_VIDEL`: accelerate Videl resolutions in GEM |
| 3 | `CT60_SV_REZDIALOG`: extended desktop video dialog |
| 2 | `CT60_SV_CLONE`: same screen on both outputs |
| 1 | `CT60_SV_BPS32`: allow 32-bit true colour in the TOS VDI |
| 0 | `CT60_SV_BPS8C`: allow 8-bit chunky in the TOS VDI |

These are the `[FLASH]` keys of `SV.INF` ([../software/drivers.md](../software/drivers.md)). The VDI-side keys (`default`, `forced`, `dual`, `restrict_x/y`) are still read from `SV.INF` by `SVSCREEN.SYS`. [S014][S021]

If the stored value's version nibble isn't 1, `CT60CONF.CPX` falls back to the shipped defaults: boot mode `$401A`, with CLONE, REZDIALOG, FAST_VIDEL and PMMU_BOOST set. [S021]

## 6. Mode codes

The CPX source describes the default boot mode `$401A` as **"640x480x4bpp"**. [S021] Read as a standard Falcon `VsetMode()` word, `$001A` is 16 colours (BPS4) + 80 columns + VGA, which is 640×480×4 bpp. So the low bits keep their Falcon meaning, and **bit 14 (`$4000`) appears to select an SV mode**. **(inferred)** Under that reading, `$401C` (the `SV.INF` VDI default) is 640×480×16 bpp. How SV-only resolutions (such as 1920×1080) and depths (8-bit chunky, 32-bit) are encoded isn't visible in this source. The SV XBIOS is included only as a binary (`nonfree/sv_xbios.bin`). [S021]

[S011]: ../../sources/INDEX.md
[S012]: ../../sources/INDEX.md
[S014]: ../../sources/INDEX.md
[S020]: ../../sources/INDEX.md
[S021]: ../../sources/INDEX.md
