# Videl core for SV-Lite (VHDL)

A VHDL-2008 Videl emulation block for the [SV-Lite design](../../docs/design/sv-lite.md). Its mode-decode and colour rules are translated from Hatari's Videl emulation (`src/falcon/videl.c`, commit `36a8acf`) [S035]. The scope and reasoning are in [videl-compat.md](../../docs/design/videl-compat.md).

**Status:** simulated only. All 9 test vectors match Hatari. The core has not been synthesized or run on hardware.

**Licence:** GPL-2.0-or-later, because it is derived from Hatari.

## What it does

```
CT60 bus writes ──▶ videl_regs ──▶ videl_decode ──▶ videl_fetch ──▶ line buffer ──▶ videl_pixel ──▶ RGB24
 ($FF82xx, $FF9800)  (snoop shadow)   (geometry)      (ST-RAM shadow,  (2 × 2048 × 16)  (ST/Falcon palette,
                                                       planar→chunky)                   true colour)
```

| File | Block |
|------|-------|
| `rtl/videl_pkg.vhd` | Types; `videl_decode` (Hatari's `VIDEL_getScreenBpp`, `Videl_GetPixelCyclesAndDivider`, `VIDEL_getScreenWidth`, `VIDEL_getScreenHeight`); colour expansion (`VIDEL_UpdateColors`) |
| `rtl/videl_regs.vhd` | Write snoop of `$FFFF8200`–`$FFFF82FF` and the Falcon palette. Side effects as in Hatari: writing base hi/mid clears lo; `$8260` sets LWD/VMD and selects the ST palette; `$8266` selects the Falcon palette; ST colour byte writes are copied into both bytes |
| `rtl/videl_fetch.vhd` | Reads one source line (base + y × (LWD+LOF) × 2) through a simple request/stream memory port; converts interleaved bit-planes to chunky; applies h-scroll |
| `rtl/videl_pixel.vhd` | Line buffer → palette → RGB24, 3-cycle latency, border colour = entry 0 |
| `rtl/videl_core.vhd` | Top level: two clock domains (CT60 bus clock, pixel clock), palette RAM, line buffer |
| `tb/tb_videl_core.vhd` | Self-checking testbench against the Hatari golden model |

The real Videl stays in the Falcon and answers every read. This core only latches writes, as the CT60's hardware emulation window allows [S022].

It produces picture **geometry and pixels**, not sync timing. The SV-Lite output stage is expected to:

- request lines (`line_start`, `line_y`, `line_bank`);
- read pixels (`in_x`, `in_border`) in its own VGA/HDMI timing, using the `geom` record (sizes and borders) to place and scale the picture.

## Verification

`tools/videl_ref/` builds Hatari's **unmodified** `videl.c` from `sources/` against small stub headers. It replays `vectors.txt` and writes `expected.txt`. The testbench feeds the same register writes into the core and checks:

- bpp, width, height, all four borders, line stride, h-scroll, the ST/Falcon palette switch and the screen base;
- the fetch address of line 1;
- the border colour and the first 16 pixels' colours, through the full fetch → planar-to-chunky → palette path.

Vectors cover true colour, 8/4/2/1 bpp, ST low/medium/high through `$8260`, mono, RGB, VGA and TV monitors, HDB bit 9, interlace, line doubling, h-scroll with line offset, STE byte-write duplication, and a VDE < VDB edge case. One vector set is MiKRO's worked 640×400 true-colour example [S031].

A check with deliberately injected bugs (hdb offset, HDB bit-9 term, STE nibble order, 6-bit palette expansion) gave 3–22 failures for each bug, so the comparison is effective.

Run it (needs a C compiler; GHDL comes from the local sandbox):

```bash
tools/get-ghdl.sh
```

```bash
hdl/videl/sim.sh
```

Skip `get-ghdl.sh` if `tools/ghdl/` already exists. The full method, data formats, acceptance criteria, the GHDL sandbox and every trap hit along the way are in [docs/design/videl-core-methodology.md](../../docs/design/videl-core-methodology.md). Read it before extending the core.

## Known gaps

- **True-colour pixel format** is taken as RGB 5:6:5. Hatari's converter (`conv_gen.c`) isn't in the sources, so TC pixels (not borders) aren't checked against Hatari. **(unverified)**
- **Screen base composition** (`$8201`/`$8203`/`$820D` into a 24-bit address) follows the harness's stand-in for Hatari's `Video_GetScreenBaseAddr`, which is in `video.c` and not in the sources. **(unverified)**
- **What Hatari itself approximates**, listed in [videl-compat.md §5](../../docs/design/videl-compat.md#5-what-hatari-does-not-model): h-scroll and line-offset interaction, 1-plane quirks, the half-line VFC, and mid-frame raster changes (the core uses one geometry per frame).
- **Not handled:** `$8266` bits 3:0 (16-colour bank select, also ignored by Hatari), the overlay bit, and video-counter writes (`$8205`–`$8209`).
- **When VDE < VDB,** Hatari keeps the previous height; the core reports 0.
- **Cross-clock:** the geometry crosses from the bus clock to the pixel clock without synchronisers, on the assumption that it only changes during blanking.
- **Not synthesized:** resource use and timing on the ECP5 are unknown.

[S022]: ../../sources/INDEX.md
[S031]: ../../sources/INDEX.md
[S035]: ../../sources/INDEX.md
