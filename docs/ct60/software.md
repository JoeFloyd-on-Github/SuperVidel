# CT60 Software Interface

> Sources: CT60 manual [S022] and CT60 TOS source [S021]; release history in [S020]. For CT60 TOS versions and their SuperVidel-related changes, see [../software/drivers.md](../software/drivers.md#ct60-tos-releases-relevant-to-the-sv).

## TOS in flash

The CT60 flash holds a patched **TOS 4.04**. In 060 mode it replaces the ROM. Among its patches [S022]:

- It enables the 060 superscalar dispatcher (PCR) and works around revision 1 CPU bugs.
- It sets the transparent translation registers (see [memory-map.md](memory-map.md)) and, except on EC/LC CPUs, builds a PMMU tree: ST-RAM writethrough, SDRAM copyback. It may also copy TOS into SDRAM.
- It emulates unimplemented integer and FPU instructions, and replaces `movep`.
- It initialises and declares the SDRAM, and creates the FastRAM buffers.
- It fixes the BLiTTER-based VDI functions (`vro_cpyfm`, `vr_trnfm`, `vrt_cpyfm`) for SDRAM, using an ST-RAM bounce buffer.
- It adds the CT60 XBIOS calls, a boot menu (TOS, MagiC or Linux), boot logging, and IDE/SCSI boot improvements.

CT60 TOS 3.00 also builds in the SuperVidel XBIOS. [S020][S021]

## Cookies

| Cookie | Set by | Meaning | Ref |
|--------|--------|---------|-----|
| `_CPU`, `_FPU` | flash TOS | CPU and FPU type | [S022] |
| `CT60` | flash TOS | CT60 present; can also report the speed of a fan connected to MFP IO3 | [S022] |
| `_FRQ` | flash TOS | Videl internal clock (MHz). **Set to 25 when an SV is present**, without measuring | [S021][S022] |
| `_FRE` | flash TOS | Videl external clock (MHz), if a 32 MHz external clock is used for RGB. **Set to 0 when an SV is present** | [S021][S022] |
| `_FRB` | flash TOS | FastRAM buffer | [S022] |
| `XFRB` | flash TOS | Extended FastRAM buffer | [S022] |
| `PMMU` | flash TOS | PMMU tree in use (not on EC/LC) | [S022] |
| `SupV` | SV XBIOS | SuperVidel driver installed (see [../programming/detection.md](../programming/detection.md)) | [S021] |

## CT60 XBIOS calls

Opcodes `$C60A`–`$C60D`, called with `trap #14` [S021][S022]:

| Opcode | Name | Arguments | Function |
|--------|------|-----------|----------|
| `$C60A` | `ct60_read_core_temperature` | `(short type_deg)`: 0 = Celsius, 1 = Fahrenheit | 68060 core temperature |
| `$C60B` | `ct60_rw_parameter` | `(short mode, long type_param, long value)`: mode 0 = read, 1 = write | Read or write a flash parameter (below) |
| `$C60C` | `ct60_cache` | `(short cache_mode)` | Cache control |
| `$C60D` | `ct60_flush_cache` | — | Flush caches |

C bindings from `ct60.h`:

```c
#define ct60_read_core_temperature(type_deg) (long)trap_14_ww((short)(0xc60a),(short)(type_deg))
#define ct60_rw_parameter(mode,type_param,value) (long)trap_14_wwll((short)(0xc60b),(short)(mode),(long)(type_param),(long)(value))
#define ct60_cache(cache_mode) (long)trap_14_ww((short)(0xc60c),(short)(cache_mode))
#define ct60_flush_cache() (long)trap_14_ww((short)(0xc60d))
```

### Flash parameters (`type_param` for `$C60B`)

| Value | Name | Notes |
|-------|------|-------|
| 0 | `CT60_PARAM_TOSRAM` | Run TOS from RAM |
| 1 | `CT60_BLITTER_SPEED` | |
| 3 | `CT60_BOOT_ORDER` | IDE/SCSI boot order |
| 4 | `CT60_CPU_FPU` | |
| 5 | `CT60_BOOT_LOG` | Redirect AUTO output to `boot.log` |
| **6** | **`CT60_SV_CONFIG`** | **SuperVidel boot configuration** (CT60 TOS 3.00). Layout in [../programming/detection.md](../programming/detection.md#5-boot-time-sv-configuration-ct60-tos-300) |
| 7–9 | `CT60_SAVE_NVRAM_1..3` | NVRAM backup |
| 10 | `CT60_PARAM_OFFSET_TLV` | |
| 11 | `CT60_ABE_CODE` | |
| 12 | `CT60_SDR_CODE` | |
| 13 | `CT60_CLOCK` | |

Value 2 isn't defined in `ct60.h`. Meanings without notes are only the constant names. [S021]

## Configuration CPX

`CT60CONF.CPX` (for XCONTROL, ZCONTROL or COPS) edits NVRAM and flash parameters, shows the CPU load (MiNT/MagiC) and 060 temperature, sets the boot delay and boot OS, powers the machine off, and shows SDRAM details. Temperature graphs use a helper, `CT60TEMP.ACC`/`.APP`. [S022] In CT60 TOS 3.00 the CPX has a **SuperVidel page** that edits `CT60_SV_CONFIG`; it appears only when the `SupV` cookie exists. [S021]

## Boot keyboard shortcuts

| Keys | Effect |
|------|--------|
| Ctrl | Boot without AUTO folder and accessories |
| Alt | Before SDRAM init: caches off. After: boot without disk |
| Ctrl + Left Shift | (before the Atari logo) Boot without a PMMU tree, as on an EC |
| Left Shift + Right Shift | (before the logo) Boot without SDRAM |
| Left Shift | Show SDRAM module info. **CT60 TOS 3.00:** Left Shift alone skips installing the SV XBIOS (but still skips Videl clock detection if an SV is present) [S021] |
| Ctrl + Alt + Undo | (during the memory test) Reset NVRAM and flash parameters |
| Ctrl + Alt + Left Shift + Right Shift | (before the logo) Start Atari Diagnostics |

[S021][S022]

## Flash Tool and JTAG

`FLASH060.PRG` writes TOS images (`.BIN`) to the flash and programs the two XC95144XL CPLDs from `.JED` files. [S022]

- CPLD programming from the Falcon needs a JTAG cable on the parallel port. Use a 74HC125 or 74AHC125 buffer, **not** an HCT part, because the CT60 supplies the cable with 3.3 V. Making a standard Xilinx parallel cable work on the Falcon also needs rewiring (pin 13 → pin 10 on the DB25). [S019][S022]
- SDR60 can be programmed in 030 mode with the CT60 fitted. **ABE60** needs the CT60 off the bus, **unless** a 1 kΩ resistor is fitted between GND and pin 1 of one of the three 74LVC245s, and then the BLiTTER mustn't be used (run NVDI). [S022] (S019's later wording says to solder "a 1 to 10K resistor between pin #1 & #10".)
- From a PC: Xilinx iMPACT with a USB or parallel Xilinx cable. This is the same procedure Nature refers to for recovering an SV over JTAG. [S018][S019]

### JTAG pins on the tower connector (X6)

| Pin | Signal | Cable pin |
|-----|--------|-----------|
| 12 | JTAG_VCC | 1 |
| 13 | JTAG_GND | 2 |
| 14 | JTAG_KEY | (no pin) |
| 15 | JTAG_TCK | 3 |
| 16 | JTAG_TDO | 4 |
| 17 | JTAG_TDI | 5 |
| 18 | JTAG_TMS | 6 |

Pins 1–11 of X6 are the tower front-panel connections: power switch, turbo switch, IDE LED, reset switch and power LED. [S022]

[S018]: ../../sources/INDEX.md
[S019]: ../../sources/INDEX.md
[S020]: ../../sources/INDEX.md
[S021]: ../../sources/INDEX.md
[S022]: ../../sources/INDEX.md
