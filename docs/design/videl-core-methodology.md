# Videl Core: Methodology, Test Harness and Traps

> This is a record of how the SV-Lite Videl core in [`hdl/videl/`](../../hdl/videl/README.md) was made and checked. It is written so someone can repeat, audit or extend the work without hitting the same problems. The behaviour reference is Hatari's `src/falcon/videl.c` at commit `36a8acf` [S035]. The design background is in [videl-compat.md](videl-compat.md) and [sv-lite.md](sv-lite.md).
>
> Work done 2026-11-25 on Ubuntu (x86-64), gcc, GHDL 5.0.1 (mcode backend).

## Contents

1. [Overview and file map](#1-overview-and-file-map)
2. [Isolating the Videl code from Hatari](#2-isolating-the-videl-code-from-hatari)
3. [The golden-model harness (`tools/videl_ref`)](#3-the-golden-model-harness-toolsvidel_ref)
4. [Input data: the vector file](#4-input-data-the-vector-file)
5. [Output data: the expected file](#5-output-data-the-expected-file)
6. [How the C translated into VHDL](#6-how-the-c-translated-into-vhdl)
7. [The GHDL sandbox](#7-the-ghdl-sandbox)
8. [The VHDL testbench](#8-the-vhdl-testbench)
9. [Acceptance criteria](#9-acceptance-criteria)
10. [Traps hit and how they were handled](#10-traps-hit-and-how-they-were-handled)
11. [How to extend the work](#11-how-to-extend-the-work)
12. [What is not verified](#12-what-is-not-verified)
13. [Two clocks, synthesis and gate-level timing simulation](#13-two-clocks-synthesis-and-gate-level-timing-simulation)

---

## 1. Overview and file map

```
sources/web/github.com/hatari/hatari-36a8acf-videl/   S035: Hatari videl.c, videl.h, screen.h (never edited)
        │  #include (read-only, via -I)
        ▼
tools/videl_ref/
    stubs/*.h          stand-ins for the Hatari headers videl.c needs
    videl_ref.c        harness: replays register writes, prints Hatari's results
    Makefile           builds videl_ref; regenerates expected.txt
    vectors.txt        INPUT: register-write test vectors (hand-written)
    expected.txt       OUTPUT: Hatari's decoded geometry + palette, one line per test
        │
        ▼ (same vectors.txt + expected.txt)
hdl/videl/
    rtl/videl_pkg.vhd      types, videl_decode(), colour functions
    rtl/videl_regs.vhd     write-snoop register shadow
    rtl/videl_fetch.vhd    line fetch + planar-to-chunky
    rtl/videl_pixel.vhd    line buffer → palette → RGB24
    rtl/videl_core.vhd     top level, RAMs
    tb/tb_videl_core.vhd   self-checking testbench
    sim.sh                 one-command build + run (extra args go to the simulation)
    syn/videl_synth_top.vhd   synthesis/timing wrapper (§13)
    syn/videl.lpf          clock targets for nextpnr
    syn/synth.sh           GHDL → Yosys → nextpnr: resources, static timing, SDF
    syn/tb_gate.v          Verilog replay bench for netlists
    syn/gatesim.sh         pre-route, routed and SDF-timed netlist simulation
    build/                 GHDL work library, traces, netlists, logs (gitignored)
tools/get-ghdl.sh         recreate the GHDL sandbox
tools/ghdl.sh             run the sandboxed GHDL
tools/ghdl/               the sandbox itself: .debs + unpacked tree (gitignored, 12 MB)
tools/get-fpga-tools.sh   recreate the FPGA tool sandbox (Yosys, nextpnr-ecp5, Icarus)
tools/fpga.sh             run a tool from that sandbox
tools/fpga/               that sandbox (gitignored)
tools/ecp5_sim_compat.py  patched copy of Yosys's ECP5 cell models for routed netlists
tools/sdf_icarus.py       turns nextpnr's SDF into something Icarus can simulate
```

The method is **differential testing**. Hatari's own C code, compiled unchanged, is the oracle. The VHDL core receives exactly the same register writes, and every value it derives must match exactly.

To run everything:

```bash
tools/get-ghdl.sh
```

```bash
hdl/videl/sim.sh
```

Skip `get-ghdl.sh` if `tools/ghdl/` already exists. A successful run ends with:

```
../tb/tb_videl_core.vhd:383:5:@62555ns:(report note): 9 tests, 0 errors
../tb/tb_videl_core.vhd:386:5:@62555ns:(report note): PASSED
```

---

## 2. Isolating the Videl code from Hatari

### 2.1 What was fetched

The three files were fetched from the official Hatari repository on GitHub, `hatari/hatari`, branch `main`. The commit was recorded so the source is fixed: `36a8acf02bb3f08749d1a4db165f85328e60793b` (committed 2026-11-24). They came from `raw.githubusercontent.com`:

| File | Why |
|------|-----|
| `src/falcon/videl.c` | The emulation itself (1,229 lines) |
| `src/falcon/videl.h` | Its public prototypes; `videl.c` includes it |
| `src/includes/screen.h` | Included by `videl.c`; harmless prototypes, used as is |

They're stored in `sources/web/github.com/hatari/hatari-36a8acf-videl/` and catalogued as **S035** in `sources/INDEX.md`. Following the project rules, **these files are never edited**. Everything else the harness needs is supplied from `tools/`.

> Trap: the first download went to an ad-hoc `sources/S035-hatari-videl/` directory. It was moved to the repository's `sources/web/<host>/…` layout before cataloguing. Keep to that layout.

### 2.2 What in `videl.c` matters

`videl.c` mixes three kinds of code:

| Kind | Functions (line numbers at `36a8acf`) | Used? |
|------|----------------------------------------|-------|
| **Register write side effects** | `VIDEL_ScreenBase_WriteByte` (364), `VIDEL_ST_ShiftModeWriteByte` (392), `VIDEL_Falcon_ShiftMode_WriteWord` (513), `Videl_ColorReg_WriteWord` (1057), `VIDEL_FalconColorRegsWrite` (255), `VIDEL_reset` (129) | Yes, called by the harness |
| **Mode decode** | `Videl_GetPixelCyclesAndDivider` (161), `VIDEL_getScreenBpp` (713), `VIDEL_getScreenWidth` (754), `VIDEL_getScreenHeight` (850), `VIDEL_UpdateColors` (906) | Yes. These are what the VHDL reproduces |
| **Host rendering and timing** | `VIDEL_renderScreen` (969, hands the frame to `ConvGen_Convert`), `VIDEL_Get_VFreq`, `VIDEL_VideoRasterHBL`, the counter read handlers, `Videl_Info`, snapshots | Compiled but not used: SV-Lite re-times output and the real Videl answers reads ([videl-compat.md §1](videl-compat.md#1-the-key-simplification-sv-lite-only-has-to-snoop-writes)) |

Several decode functions are `static`. Rather than copying them (which would fork the code), the harness `#include`s `videl.c` itself, so the statics are in the same translation unit and can be called directly. That keeps the reference **byte-for-byte Hatari's code**.

### 2.3 What `videl.c` depends on

`videl.c` includes 13 Hatari headers (lines 68–80). Only `videl.h` and `screen.h` were taken from Hatari. The other 11 are replaced by **minimal stubs** in `tools/videl_ref/stubs/`. Each stub provides only what the compiler or linker asked for:

| Stub | Provides | Notes |
|------|----------|-------|
| `main.h` | `<stdint.h>`, `<stdbool.h>`, `<stdio.h>`, `<math.h>` | `math.h` because `VIDEL_Get_VFreq` uses `round()` (link with `-lm`) |
| `configuration.h` | `CNF_PARAMS ConfigureParams` with `Screen.bAllowOverscan`, `Screen.nMonitorType`, `System.nMachineType`; `MONITOR_TYPE_*`; `MACHINE_FALCON` | Field names come from compiler errors. `bAllowOverscan = 1` (borders on) |
| `ioMem.h` | A 16 MB `IoMem[]` array; big-endian `IoMem_Read/Write{Byte,Word,Long}`; `IoAccessCurrentAddress`, `IoAccessBaseAddress`, `nIoMemAccessSize`; `SIZE_BYTE/WORD/LONG` | Big-endian is essential: the 68k register layout depends on it |
| `log.h` | `LOG_TRACE` (no-op), `LOG_DEBUG`, `Log_Printf` (no-op) | |
| `conv_gen.h` | `ConvGen_SetSize`, `ConvGen_Convert` (no-ops); **`ConvGen_SetPaletteColor` writes into `ref_palette[]`** | This is how the harness captures Hatari's palette expansion |
| `video.h` | `FALCON_MONITOR_MONO/RGB/VGA/TV` = `$00/$40/$80/$C0`; `bUseHighRes`; `Video_GetScreenBaseAddr` prototype | The monitor codes are `$FFFF8006` bits 7:6, as in the header comment of `videl.c` |
| `memorySnapShot.h`, `stMemory.h`, `tos.h`, `vdi.h`, `statusbar.h` | One extern or no-op each | `TosVersion = $404` (not `$207`, which would trigger the Sparrow hack) |

Functions that `videl.c` calls but that live in other Hatari files are defined in `videl_ref.c`: `Screen_Lock`, `Screen_UnLock`, `Screen_GenConvUpdate` and `Video_GetScreenBaseAddr`.

> **Assumption to note:** `Video_GetScreenBaseAddr` is in Hatari's `video.c`, which is **not** in the sources. The harness computes `$8201 << 16 | $8203 << 8 | $820D`, so the "base" column in `expected.txt` checks the VHDL against **this assumption**, not against Hatari. See §12.

---

## 3. The golden-model harness (`tools/videl_ref`)

### 3.1 Build

```make
HATARI := ../../sources/web/github.com/hatari/hatari-36a8acf-videl
videl_ref: videl_ref.c $(wildcard stubs/*.h) $(HATARI)/videl.c
	$(CC) -O1 -w -Istubs -I$(HATARI) -o $@ videl_ref.c -lm
expected.txt: videl_ref vectors.txt
	./videl_ref vectors.txt > $@
```

- `-Istubs` comes **before** `-I$(HATARI)`, so stubs win. Only `videl.h` and `screen.h` resolve to the Hatari directory, because there are deliberately no stubs with those names.
- `-w` suppresses warnings from Hatari's code (unused variables and so on). Don't add `-Werror`.
- `expected.txt` depends on `vectors.txt` and the binary, so editing either regenerates it. `hdl/videl/sim.sh` runs `make … expected.txt` first.

### 3.2 Harness logic (`videl_ref.c`)

For each `test`:

1. `memset(IoMem, 0)`. Set `IoMem[$FF8006]` to the monitor code (`$00`/`$40`/`$80`/`$C0`).
2. `memset(&videl, 0)`, then `VIDEL_reset()`. `VIDEL_reset` reads the monitor type back from `$FF8006 & $C0`, clears `bUseSTShifter` and zeroes `$820E`/`$8264`.
   - The `memset` is needed because Hatari's `videl` struct carries state such as `YSize` between calls. Without it, one test's leftovers leak into the next (trap T11).
3. Each `w` line goes to `cpu_write(addr, size, value)`, which stores the bytes big-endian in `IoMem` and then calls the Hatari write handler, the way Hatari's `ioMemTabFalcon.c` would. That file is **not** in the sources, so the dispatch is a reconstruction:

   | Access | Harness behaviour |
   |--------|-------------------|
   | Byte | Store, then `dispatch(addr, BYTE)` |
   | Word to `$8240`–`$825E` (ST palette) or `$8266` | Store, then one `dispatch(addr, WORD)` |
   | Other words | Store, then `dispatch(addr)` and `dispatch(addr+1)`, so that a word write covering `$8201`, for example, triggers the byte handler |
   | Long to `$9800`–`$9BFF` (Falcon palette) | Store the long, one dispatch |
   | Other longs | Two word accesses (`addr`, `addr+2`). This matches the comment in `videl.c` near line 1083 that `.L` colour writes become two `.W` accesses |

   `dispatch()` maps the address to its handler:
   - `$8201`/`$8203`/`$820D` → `VIDEL_ScreenBase_WriteByte`
   - `$8260` → `VIDEL_ST_ShiftModeWriteByte`
   - `$8266` (word) → `VIDEL_Falcon_ShiftMode_WriteWord`
   - `$8240`–`$825F` → `Videl_ColorReg_WriteWord`
   - `$9800`–`$9BFF` → `VIDEL_FalconColorRegsWrite`

   Handlers read `IoAccessCurrentAddress`, `IoAccessBaseAddress` and `nIoMemAccessSize`, so `dispatch` sets those first.
4. On `end`:
   - call `VIDEL_getScreenWidth()`, then `VIDEL_getScreenHeight()`, then `VIDEL_getScreenBpp()`. Width must come first, because it sets `videl.XSize` and the border sizes as side effects;
   - set `videl.save_scrBpp = bpp` and `hostColorsSync = false`;
   - clear `ref_palette` and call `VIDEL_UpdateColors()`, which fills `ref_palette[]` through the stubbed `ConvGen_SetPaletteColor`;
   - print one result line (§5).

The harness never calls `VIDEL_renderScreen`, so no pixel data passes through Hatari. Pixel colours are checked indirectly: the testbench works out which palette entry each pixel should show and compares against Hatari's expanded palette (§8.4).

---

## 4. Input data: the vector file

`tools/videl_ref/vectors.txt` is plain text, one command per line, read by **both** the C harness and the VHDL testbench:

```
# comment                       (also blank lines)
test <name> <mono|rgb|vga|tv>   start a test: reset model, set monitor type
w <addr> <b|w|l> <value>        CPU write; addr and value in hex, no $ or 0x
end                             compute and compare
```

- `addr` is the 24-bit Falcon address (`ff8282`). The core sees it as `$FFFF8282` on the 060 bus; the testbench strips the top byte.
- `value` may have fewer digits than the access size (`w ff8201 b 03`). The VHDL side parses this with its own `hex()` function, because `hread` can't (trap T7).
- Test names must not contain spaces. Both parsers split on whitespace.

Current vectors (9 tests):

| Test | Monitor | What it exercises |
|------|---------|-------------------|
| `tc640x400_rgb` | RGB | True colour. Register values are MiKRO's worked example in *Videl in practice* [S031]. Palette long write with low bits set (Hatari masks it with `$FCFC00FC`) |
| `stlow_vga` | VGA | `$8260 = 0` side effect (LWD `$50`, VMD `$5`); ST palette word, byte-lo, byte-hi and long writes; STE nibble bit order |
| `stmed_rgb` | RGB | `$8260 = 1`, 2 bpp, ST divider 16, non-zero right border |
| `sthigh_mono` | Mono | `$8260 = 2` on a mono monitor: VMD 0 and all borders forced to 0 |
| `p8_640x480_vga` | VGA | SPSHIFT bit 4 (8 bpp); **HDB bit 9** (start in previous half-line); 1 cycle per pixel; base hi/mid/lo; several palette longs |
| `p4_320x240_vga` | VGA | Falcon 16-colour (SPSHIFT = 0); **write lo then hi/mid clears lo**; line offset `$820E`; **h-scroll 5**; line doubling |
| `p1_640x400_rgb_il` | RGB | SPSHIFT bit 10 (2-colour); interlace (VMD bit 1 = 0) halves the height |
| `st_then_falcon` | TV | `$8260` then `$8266`: switches back to the Falcon palette; 8 bpp on TV |
| `vde_lt_vdb` | VGA | VDE < VDB edge case; true colour with all-zero borders |

Apart from `tc640x400_rgb`, the register values are **test inputs**, chosen to exercise code paths. They are not claimed to be real TOS settings.

---

## 5. Output data: the expected file

`tools/videl_ref/expected.txt` holds one line per `end`, space-separated:

| # | Field | Hatari source |
|---|-------|---------------|
| 1 | test name | — |
| 2 | bpp (1/2/4/8/16) | `VIDEL_getScreenBpp()` |
| 3 | xsize | `videl.XSize` |
| 4 | left border (pixels) | `videl.leftBorderSize` |
| 5 | right border | `videl.rightBorderSize` |
| 6 | ysize (lines) | `videl.YSize` |
| 7 | upper border | `videl.upperBorderSize` |
| 8 | lower border | `videl.lowerBorderSize` |
| 9 | nextline (words) | `($8210 & $3FF) + ($820E & $1FF)`, the same expression as `VIDEL_renderScreen` |
| 10 | h-scroll | `$8265 & $0F` |
| 11 | use_st (0/1) | `videl.bUseSTShifter` |
| 12 | base (6 hex digits) | `Video_GetScreenBaseAddr()`, **harness stand-in** |
| 13–28 | palette entries 0–15, RGB24, 6 hex digits | `ref_palette[]` from `VIDEL_UpdateColors()` |

Points to note:

- Hatari expands only `1 << bpp` entries. In 1-bpp tests only entries 0–1 are meaningful, in 2-bpp tests only 0–3; the rest print `000000`. In true colour only entry 0 (the border) is filled.
- The file is **generated**. Never edit it by hand: change `vectors.txt` and run `make`. It is committed so the testbench runs without a C compiler, and so that a changed oracle shows up as a diff.

Example line (first 13 fields):

```
tc640x400_rgb 16 640 41 59 400 79 87 640 0 0 038000 102045 …
```

This can be checked by hand from Hatari's formulas:

- `hdb_off = ((64 + 16×2)/2) + 1 = 49`;
- left = `(0x71 − 0x50 + 49)/2 = 41`, right = `(0x199 − 0 − 0x122)/2 = 59`;
- palette 0 = `$11223344` masked to `$10200044`, then expanded to `10`/`20`/`45`.

---

## 6. How the C translated into VHDL

### 6.1 Overall structure

| Hatari (software, per frame) | VHDL (hardware) |
|------------------------------|-----------------|
| `IoMem[]` + write handlers | `videl_regs`: 256-byte shadow of `$FF8200`–`$FF82FF`, side effects applied in the same clock as the write |
| `bUseSTShifter` | `use_st` flip-flop in `videl_regs` |
| `VIDEL_getScreen{Bpp,Width,Height}` + `Videl_GetPixelCyclesAndDivider` | One pure function, `videl_decode(regs, monitor, overscan)` in `videl_pkg`, registered every bus clock in `videl_core` |
| `VIDEL_UpdateColors` | `st_colour()`, `falcon_colour()` and `tc_colour()` in `videl_pkg`, applied per pixel in `videl_pixel` |
| `ConvGen_Convert` (bit-planes to host pixels) | `videl_fetch` (planar to chunky) + line buffer + `videl_pixel`. Hatari's `conv_gen.c` isn't in the sources, so this part was written from the Falcon bit-plane format, not translated |
| Frame rendered at VBL | Geometry latched per line or frame by the consumer; lines fetched on request |

### 6.2 Line by line: the decode

| Hatari C | VHDL (`videl_decode`) | Notes |
|----------|-----------------------|-------|
| `if (f_shift & 0x400) bpp=1; else if (&0x100) 16; else if (&0x010) 8; else if (!bUseSTShifter) 4; else st_shift 0→4, 1→2, else 1` | `if spshift(10)…elsif spshift(8)…` assigning **log₂(bpp)** `bl` ∈ 0..4 | Holding log₂ turns every later `/bpp` and `*bpp` into a shift. `st_shift = 3` falls into Hatari's `else` (1 bpp), and the VHDL does the same |
| `vdm = $82C2 & 0xC`; `0→4, 4→2, else 1` cycles per pixel | `vdm := vmd(3 downto 2)`, `cyc` = log₂ (2, 1, 0) | Hatari's "invalid `0xC`" return value is unused, so it isn't modelled |
| divider: VGA → `vdm==0 ? 4 : 2`; ST → 16; else = cycles | `dv` = log₂ (2/1, 4, `cyc`) | |
| `XSize = (LWD & 0x3FF) * 16 / bpp; while (>2048) /= 2` | `xs := shl(lwd, 4 − bl)`, then 3 unrolled `if xs > 2048 then xs := xs/2` | 3 halvings are enough: the maximum is 1023 × 16 = 16368 → 2046 |
| `if (!bAllowOverscan) or mono → borders 0` | Generic `OVERSCAN` and `mon = MON_MONO` | |
| `hdb_offset = ((64 + (128/bpp + 16 + 2) * cyc) / div) + 1` and the other three variants | `shr(64 + shl(p + 18, cyc), dv) + 1` with `p = shl(1, 7 − bl)` | The C's operation order is kept exactly; with integer truncation, reordering changes results |
| `if (HDB & 0x200) left = hdb − hbe + off − hht − 2` | `lb := lb − hht − 2` when `hdb(9)` | HDB is masked to 9 bits for the arithmetic, but bit 9 comes from the raw register, as in C |
| `leftBorderSize = left / cyc; if (<0) = 0` | `if lb > 0 then shr(lb, cyc) else 0` | C division truncates toward zero, so any negative value becomes ≤ 0 and is clamped. Clamping first and then shifting gives the same result (§10, T13) |
| `upper = vdb − vbe > 0 ? … : 0` (computed as signed `int`) | integer subtraction, clamped | The registers are `uint16_t` but promoted to `int`, so the comparison is signed |
| `if (vde >= vdb) YSize = vde − vdb; else` *(unchanged)* | else `0` | **Documented difference:** Hatari keeps the previous `YSize`. The harness `memset`s the state, so both give 0 in tests |
| `if (!(vmode & 2)) >>=1; if (vmode & 1) >>=1` (Y, upper, lower) | `vmd(1) = '0'`, `vmd(0) = '1'` halvings | Bit 1 clear means interlace / half-line units |
| `vw < 32 || vh < 32 → not drawn` | `drawable` flag | |

**Synthesis rule used throughout:** never divide or multiply by a *variable*. `shl` and `shr` are `case` statements over constant multipliers and divisors, which synthesis maps to wiring.

### 6.3 Register side effects

| Hatari | VHDL (`videl_regs`) |
|--------|---------------------|
| `VIDEL_ScreenBase_WriteByte`: on `$8201`/`$8203`, `IoMem[$820D] = 0` | After applying the byte lanes: if `$01` or `$03` was written **and `$0D` wasn't in the same access**, clear `$0D`. (A long write covering all three isn't possible, since they aren't in one longword, but the guard costs nothing) |
| `VIDEL_ST_ShiftModeWriteByte`: mask `& 3`, `bUseSTShifter = true`, write LWD and VMD from the table | Same table as a `case` on the masked value and `monitor`. Writes bank bytes `$10`/`$11` and `$C2`/`$C3`; sets `use_st`. The Sparrow TOS (`$207`) hack isn't ported |
| `VIDEL_Falcon_ShiftMode_WriteWord`: `bUseSTShifter = false` | Any byte write to `$66` or `$67` clears `use_st` |
| `Videl_ColorReg_WriteWord`: byte access copies the byte into both halves; `col &= 0xFFF` | If exactly one `be` bit is set and the offset is in `$40`–`$5F`, the byte goes to both. `& $FFF` is applied when the field is read (`st_pal(i)` takes bits 11:0) |
| `VIDEL_FalconColorRegsWrite`: `color &= 0xFCFC00FC` stored | **Not masked on store.** All 8 bits are kept, because SV modes use 8-bit palettes [S011]. The mask is applied at output (`falcon_colour` uses the top 6 bits and fills the bottom 2 from the top), which gives the same colours |
| `ST_colors`: `r = ((r & 7) << 1) | (r >> 3); r |= r << 4` | `st_colour`: nibble `n(2 downto 0) & n(3)`, then `n & n` |
| `F_COLORS`: `r = c & 0xFC; r |= r >> 6` | `falcon_colour`: `c(31 downto 26) & c(31 downto 30)` |

### 6.4 Bus model chosen for the VHDL

68060 bus semantics: one long-aligned access per `wr` pulse, `addr` = bits 23:2, `be(3)` = byte at offset 0, carried on `wdata(31:24)`. The testbench converts `b`/`w`/`l` vectors into this form (§8.2). The C harness instead models Hatari's byte/word/long handler dispatch (§3.2). Agreement between the two is part of what the test checks.

---

## 7. The GHDL sandbox

### 7.1 Why a sandbox

No VHDL simulator was installed, and installing system packages needs root. With your permission, GHDL was taken from the configured Ubuntu archive **without installing it**: the `.deb` files were downloaded and unpacked into a private directory. Nothing outside the repository was changed.

### 7.2 How it was built (and how to rebuild it)

`tools/get-ghdl.sh` does exactly this:

```sh
apt-get download ghdl-common ghdl-mcode    # no root needed
dpkg -x ghdl-common_*.deb root             # unpack only; no scripts run,
dpkg -x ghdl-mcode_*.deb  root             #   no dpkg database change
```

Packages used (Ubuntu "resolute", universe, version `5.0.1+dfsg-1ubuntu1`):

| File | SHA-256 |
|------|---------|
| `ghdl-common_5.0.1+dfsg-1ubuntu1_amd64.deb` | `4617d92b85964c0e542610273171b326a52ac3b788112944d370faef8530ab5f` |
| `ghdl-mcode_5.0.1+dfsg-1ubuntu1_amd64.deb` | `9e555a9444f484e1a271737e799cff5f1218e2f795d1578daba3c99a5d45c99b` |

- **Why only these two:** the `ghdl` metapackage depends on one backend (mcode, gcc or llvm). **mcode** is a self-contained JIT with no compiler toolchain dependency, so `ghdl-common` + `ghdl-mcode` is the minimum. `ghdl-llvm`/`ghdl-gcc` would pull in LLVM or GCC runtime libraries.
- **The sandbox is preserved** in `tools/ghdl/` (`deb/` with the original packages, `root/` unpacked, 12 MB). It's in `.gitignore`, so it stays local. On another machine or a different Ubuntu release, run `tools/get-ghdl.sh` and compare the hashes above. A different release gives a different version, which should be fine but is untested.
- The session scratchpad copy where it was first built is temporary; `tools/ghdl/` is the durable copy.

### 7.3 Running it

`tools/ghdl.sh` is a wrapper: `GHDL_PREFIX=…/root/usr/lib/ghdl/mcode/vhdl exec …/root/usr/bin/ghdl-mcode "$@"`. `hdl/videl/sim.sh` uses it automatically when `tools/ghdl/` exists; otherwise it uses `ghdl` on `PATH`, or `$GHDL` if set.

```bash
tools/ghdl.sh --version
```

That should print `GHDL 5.0.1 (Ubuntu 5.0.1+dfsg-1ubuntu1) [Dunoon edition]`.

Library-path traps (T1–T3 in §10):

- `ghdl-mcode` has no built-in knowledge of a relocated install. **`--PREFIX=` is rejected when it appears before the command** ("unknown command"). Use the `GHDL_PREFIX` environment variable instead.
- The prefix is **`…/mcode/vhdl`**, the directory containing `std/` and `ieee/` with `v08/` subdirectories. `…/usr/lib/ghdl/mcode` gives "ieee library directory … not found / cannot find "std" library". `…/usr/lib/ghdl/src` holds VHDL *sources*, not compiled libraries.

---

## 8. The VHDL testbench

`hdl/videl/tb/tb_videl_core.vhd`, VHDL-2008. By default one clock (10 ns) drives both `bus_clk` and `pix_clk`; §13.1 covers two clocks.

### 8.1 Flow per test

1. **`test` line:** set `monitor`, hold `rst` for 2 clocks, then write zeros to Falcon palette entries 0–15. The palette RAM has no reset, and Hatari's `IoMem` is zeroed (trap T9).
2. **`w` lines:** convert each to a bus access (§8.2) and pulse `wr` for one clock.
3. **`end`:**
   - wait 2 clocks for `videl_decode` to register;
   - read the next line of `expected.txt` and compare all fields (§9);
   - read one **border pixel** and compare with palette 0;
   - request **source line 1**, and check that `mem_addr = base + nextline × 2` when `mem_req` rises;
   - wait for `line_done`;
   - in bit-plane modes, read pixels 0–15 and compare colours (§8.4).
4. At end of file, report `N tests, M errors`. Fail with `severity failure` if M ≠ 0.

### 8.2 Vector-to-bus conversion

| Vector | `be` | `wdata` |
|--------|------|---------|
| `b` at offset k (= addr mod 4) | only bit `3−k` | byte in lane k: `wdata(31−8k downto 24−8k)` |
| `w` at offset 0 | `1100` | `value & x"0000"` |
| `w` at offset 2 | `0011` | `x"0000" & value` |
| `l` | `1111` | `value` |

### 8.3 Memory model

A process watches `mem_req`, asserts `mem_ack` for one clock, then streams `mem_words` words with `mem_valid`, advancing only when `mem_ready = '1'`. Word n of the line is:

- **Bit-plane modes:** plane `p = n mod (number of planes)`; bit `15 − j` set when bit p of j is set (j = 0..15). So **pixel j of every 16-pixel group has palette index j** (masked to the mode's bit count).
- **True colour:** the word equals n.

### 8.4 Pixel check

For pixel x (0..15, while x < xsize), the expected colour is `e_pal(((x + hscroll) mod 16) mod 2^bpp)`, taken from Hatari's expanded palette. This tests:

- line fetch: word count, h-scroll extra group;
- planar-to-chunky bit order;
- h-scroll skip;
- index masking;
- palette RAM byte lanes;
- ST vs Falcon palette selection;
- colour expansion, end to end.

The colours come from Hatari; only the pixel→index mapping comes from the Falcon bit-plane format.

---

## 9. Acceptance criteria

A test **passes** only if **all** of these hold. Every comparison is exact, with no tolerances:

| # | Check | Compared with |
|---|-------|---------------|
| A1 | `2^bpp_log2` = bpp | Hatari |
| A2 | xsize, left, right | Hatari |
| A3 | ysize, upper, lower | Hatari |
| A4 | nextline (LWD + LOF) | Hatari's `renderScreen` expression |
| A5 | h-scroll | Hatari register |
| A6 | use_st | Hatari `bUseSTShifter` |
| A7 | screen base | **Harness stand-in** for `Video_GetScreenBaseAddr` (§12) |
| A8 | Border pixel RGB = palette entry 0 | Hatari `VIDEL_UpdateColors` |
| A9 | Fetch address of line 1 = base + nextline × 2 | Derived from A4/A7 |
| A10 | Pixels 0–15 RGB (bit-plane modes) | Hatari palette + bit-plane format |
| A11 | Line fetch finishes (`line_done` arrives) | Hang = failure (simulation never ends) |

**The suite is accepted** when every vector passes (`N tests, 0 errors`, `PASSED`) and the **mutation sanity check** below detects injected bugs.

**Mutation check** (manual, done 2026-11-25). Each mutation was applied to `videl_pkg.vhd` alone, then the suite was run:

| Mutation | Errors |
|----------|--------|
| Falcon bit-plane `hdb_off`: `p + 18` → `p + 16` | 3 |
| HDB bit 9 term: `− hht − 2` → `− hht` | 3 |
| STE nibble order: `n(2:0) & n(3)` → `n` | 22 |
| Falcon 6-bit expansion: blue `c(7:2) & c(7:6)` → `c(7:0)` | 4 |
| `hde_off`: `p + 2` → `p + 3` | **0, not detected** |

The last one isn't detected because integer truncation in the right-border formula absorbs it for every current vector (e.g. `(66 × 2) / 16 = (67 × 2) / 16 = 8`). It's a known coverage gap; see §11.

---

## 10. Traps hit and how they were handled

| # | Trap | Symptom | Fix |
|---|------|---------|-----|
| T1 | `ghdl-mcode --PREFIX=…` before the command | `error: unknown command '--PREFIX=…'` | Use `GHDL_PREFIX` env var (`tools/ghdl.sh`) |
| T2 | Prefix set to `…/ghdl/mcode` | `ieee library directory '…/mcode/ieee/v08/' not found`, `cannot find "std" library` | Prefix is `…/ghdl/mcode/vhdl` |
| T3 | Installing the `ghdl` metapackage | Would need root and pulls in a backend with toolchain deps | `apt-get download ghdl-common ghdl-mcode` + `dpkg -x` |
| T4 | `bank(1) & bank(3) & bank(13)` where `bank` is an array of bytes, and other array-of-vector types (`bank_t`, `st_pal_t`) are visible | `can't resolve overload for operator "&"`, listing `bank_t`, `st_pal_t`, `STD_ULOGIC_VECTOR` | Concatenating elements is ambiguous: the result could be an array type of those elements. Assign to a **typed variable** (`base24 : std_logic_vector(23 downto 0) := …`). A qualified expression `std_logic_vector'(…)` around only part of the chain didn't fix it |
| T5 | Helper `function w(hi, lo) return std_logic_vector is begin return hi & lo;` | Elaborates, then fails at run time: `slice direction doesn't match index direction` | The concatenation result of an unconstrained return has an **ascending** range (0 to 15), so slicing `(8 downto 0)` fails. Return through a variable declared `(15 downto 0)` |
| T6 | `s := (others => ' ')` on an unconstrained `string` procedure parameter | `'others' choice not allowed for an aggregate in this context` | Loop over `s'range` |
| T7 | `hread` of `v32` (32 bits) from text `03` | `STD_LOGIC_1164.HREAD End of string encountered`; every value read as 0, so dozens of cascading mismatches (first run: 89 errors) | `hread` needs exactly `width/4` digits. The testbench has its own `hex()` that accepts 1–8 digits. `hread` is still used for the expected file, whose fields are always exactly 6 digits |
| T8 | Run-time noise: hundreds of `NUMERIC_STD.TO_INTEGER: metavalue detected` | Uninitialised RAM/registers read before first write | `--ieee-asserts=disable` in `sim.sh`. **Remove it when debugging** a new failure: a metavalue warning appearing *after* reset/initialisation is a real bug |
| T9 | Palette RAM has no reset; Hatari's `IoMem` is zeroed per test | Leftover palette from a previous test | The testbench zeroes entries 0–15 after each reset (only those are checked) |
| T10 | `static` decode functions in `videl.c` | Can't link to them from a separate file | `#include "videl.c"` in the harness; never copy the code |
| T11 | Hatari's `videl` struct keeps `YSize` etc. between frames | Results depend on test order (VDE < VDB keeps the stale height) | `memset(&videl, 0, …)` before `VIDEL_reset()` per test; the VHDL documents its "0" behaviour |
| T12 | Undefined symbols while building the harness: `Log_Printf`, `LOG_DEBUG`, `ConfigureParams.System`, `MACHINE_FALCON`, then link errors for `Screen_Lock`/`Screen_UnLock`/`Screen_GenConvUpdate` | Compiler/linker errors | Add exactly what's asked for, in the stubs or `videl_ref.c`. Don't stub more than needed: a missing symbol shows a dependency you should understand |
| T13 | C truncating division of negative border values | Risk of off-by-one versus a naive shift (`shift_right` of a negative is floor, not truncation) | Clamp to ≥ 0 **before** shifting. The results are identical, because any negative numerator gives a result ≤ 0 that C then clamps |
| T14 | Initial palette-lookup design registered `pal_addr` | Would deliver colours one cycle late (4-cycle path labelled as 3) | Found by review before simulation: `pal_addr` is now combinational from the line-buffer output (`idx1`), so the palette RAM's registered read lines up with `v2` |
| T15 | Planar fetch waited for a full group of plane words | Would hang when LWD isn't a multiple of the plane count | Emit a short last group when `words_left = 1` (old value of the signal = this is the last word) |
| T16 | Word count derived from `xsize × bpp / 16` | Wrong after the >2048 width cap | Added `lwd` to `videl_geom_t`; fetch `lwd` words (+ one group if h-scroll) |
| T17 | `sed` mutation on a line that appears twice in the file | Both copies mutated silently | Check with `cmp`, or make the pattern unique. Two `hde_off := shr(shl(p + 2, cyc), dv);` lines exist (Falcon and ST branches) |
| T18 | Harness `cpu_write` dispatch for words | A word write covering `$8201` must call the byte handler for the odd byte | Non-palette word writes dispatch both `a` and `a+1`. This reconstructs Hatari's `ioMemTabFalcon.c` (not in sources), see §12 |
| T19 | Shell working directory drifting between commands | Relative paths broke | `sim.sh` does `cd "$(dirname "$0")"`; testbench generics use paths relative to `hdl/videl/build/` (`../../../tools/videl_ref/…`) |
| T20 | Writing into `sources/` | The project rules forbid modifying sources | The harness only reads `sources/` through `-I`; all stubs and generated files live in `tools/` |
| T21 | `ghdl -r … -gBUS_HALF=10ns` on a `time` generic | `unhandled override for generic "BUS_HALF"` | GHDL can only override scalar generics from the command line: the clock generics are integers in ps (`BUS_HALF_PS`) |
| T22 | `-gTRACE=…` while a generate block is labelled `trace` | `identifier "trace" already used` (VHDL is case-insensitive) | Label `g_trace` |
| T23 | Function `geom_fold` and the wrapper port `geom_fold` | `can't match indexed name with type array type` | The port hides the function: renamed the function `fold_geom` |
| T24 | Ubuntu `nextpnr-ecp5` run from the sandbox | `unrecognised option '--um5g-45k'`. No device options exist at all; `--help` doesn't list them | The binary looks for its chip database only at the absolute `/usr/share/nextpnr/` and drops the device options when it isn't there. `tools/fpga.sh` lays the sandbox's `share/` over `/usr/share` in a private namespace (`unshare -rm` + read-only overlayfs). A plain bind mount fails because the mount point doesn't exist |
| T25 | No Yosys GHDL plugin package on Ubuntu | `yosys -m ghdl` unavailable | Not needed: `ghdl --synth --out=verilog` writes a Verilog netlist that Yosys reads |
| T26 | The design's one multiplier mapped to `MULT18X18D` | No simulation model in Yosys 0.52 | `synth_ecp5 -nodsp` (the multiplier goes to LUTs; timing barely moves) |
| T27 | Routed netlist simulated with Yosys's own `cells_sim.v` | Mostly x, then wrong values | Seven model problems, each found by tracing the first diverging net (§13.4). Fixed in a patched copy (`tools/ecp5_sim_compat.py`) |
| T28 | `write_verilog` without `-norename` | 27 SDF sinks not found; nextpnr's `$nextpnr_CCU2C_44$…` cells appear as `_031_` | Yosys renames `$`-names unless `-norename` is given; the SDF uses the original names |
| T29 | Icarus `$sdf_annotate` on nextpnr's SDF | `SDF ERROR: Invalid/malformed INTERCONNECT`, `Syntax error in CELL`; with that fixed, wire delays silently ignored | Icarus 12 ignores INTERCONNECT, rejects PORT and bare `.` in instance names. `tools/sdf_icarus.py` moves wire delays into the netlist and escapes names (§13.5) |
| T30 | Escaped identifier at the end of an inserted `assign` | `syntax error` at `\c_geom[118];` | An escaped identifier runs to the next whitespace and swallows the `;`. Write `\c_geom[118] ;` |
| T31 | Replay bench inputs changed 500 ps after the clock edge (later: 1000 ps) | 27 mismatches at every clock period, independent of frequency. After the pipelined design was placed differently, 1000 ps gave 243 | A hold race: the inputs reach the input registers before the delayed clock does, and the clock insertion delay depends on placement. `HOLD` now defaults to `PERIOD/2` (inputs change at the falling edge). A failure that doesn't move with the period is a hold problem, not a setup problem |
| T34 | Comparing `out_rgb` on every cycle | 3 isolated mismatches, only with wire delays, each in a cycle that writes palette entries 0–15 | The palette RAM is read on every pixel clock, even with `in_valid` = 0. A bus-side write and a pixel-side read of the same entry in the same cycle is a two-clock RAM collision: RTL returns the old value, and the gate run may return the new one, depending on clock skew. `out_rgb` is only meaningful with `out_valid`, so the bench now checks it only then |
| T32 | Expected bits that are `U` in the RTL trace (line buffer never written) | Spurious mismatches | The trace writes them as `x`, and the bench masks `x` bits |
| T33 | Comparing the first cycles after power-up | 43 mismatches before the first reset has propagated | VHDL integers start at 0, Verilog `reg`s at x: the bench ignores the first `WARMUP` = 50 cycles |

---

## 11. How to extend the work

### Adding a test

1. Add a `test … end` block to `tools/videl_ref/vectors.txt`.
2. Run `hdl/videl/sim.sh`. It rebuilds `expected.txt` from Hatari first.
3. Review the diff of `expected.txt`: **the new line is Hatari's answer; check that it makes sense.**
4. Commit both files.

Coverage worth adding next:

- **Right borders where `hde_off` matters**, to close the mutation gap in §9. Pick HBB/HDE so that `(hbb − hde − hde_off)` sits just above a multiple of the cycles per pixel, in both Falcon bit-plane (`bpp < 16`) and ST paths.
- RGB/TV with VMD `$0` (4 cycles per pixel) in Falcon modes; the 32 MHz `VCO` bit.
- `$8260 = 3`.
- A real TOS register dump for each standard `VsetMode` mode, from S031/S032 or a Hatari trace (its `TRACE_VIDEL` class, enabled through Hatari's trace option; exact flag name **unverified**).
- Byte writes to `$8266` (the harness only dispatches word writes there, which matches Hatari's handler name but is otherwise unverified).

### Adding a Hatari behaviour

Decide first whether it's **decode** (put it in `videl_decode` and add a field to `videl_geom_t`, then print and compare it in `videl_ref.c` and the testbench) or **side effect** (put it in `videl_regs`, and add the handler to `dispatch()` in the harness).

### Updating to a newer Hatari

Fetch the new files into a **new** directory named with the new commit, add a new S-ID, and point `HATARI :=` in the Makefile at it. Then run the suite. Differences in `expected.txt` are Hatari behaviour changes to review, not test failures.

### Pixel-exact checks

Fetch Hatari's `conv_gen.c` (and `video.c` for the base address) as sources, and extend the harness to call `VIDEL_renderScreen` with a real `STRam` image and a captured output buffer. Then compare whole frames, including true colour.

### Synthesis and timing

Done: see §13. After any RTL change, rerun all three levels: `sim.sh` (against Hatari), `sim.sh -gBUS_HALF_PS=10000 -gPIX_HALF_PS=3367` (two clocks), and `syn/synth.sh` followed by `syn/gatesim.sh` (netlists). New ports of `videl_core` must also be added to `syn/videl_synth_top.vhd`, the `TRACE` process in the testbench, and the port map and bit slices in `syn/tb_gate.v`, in the same order in all three.

---

## 12. What is not verified

| Item | Status |
|------|--------|
| Screen base composition (A7) | Checked against the harness stand-in, not Hatari (`video.c` not in sources) |
| Harness byte/word/long dispatch | Reconstructed; Hatari's `ioMemTabFalcon.c` and `ioMem.c` aren't in the sources |
| True-colour pixel format (RGB 5:6:5) | Not checked against anything; only the TC border colour is |
| Hatari ≠ hardware | Hatari's own comments flag h-scroll/line-offset, 1-plane, VFC and raster effects ([videl-compat.md §5](videl-compat.md#5-what-hatari-does-not-model)). Matching Hatari is necessary but not sufficient |
| Synthesis, timing, resources on ECP5 | Done for the LFE5UM5G-45F (§13). With the decode pipelined, `bus_clk` reaches 129 MHz (target 100) and `pix_clk` 236 MHz (1080p60 needs 148.5). Pin placement is automatic, not the SV-Lite pinout |
| Clock-domain crossing of the geometry | By design assumption only (changes during blanking). RTL simulation with two unrelated clocks passes (§13.1), but RTL simulation cannot show metastability, and nextpnr times the crossing as an ordinary path (4.96 ns) |
| Gate-level model fidelity | The Yosys 0.52 cell models needed 8 fixes for nextpnr 0.9 netlists (§13.4). Every fix is checked by the zero-delay routed run matching the RTL, but the `DP16KD` model covers only the configurations this design uses |
| Gate-level timing coverage | Only as good as the trace: before pipelining, the SDF run passed at 100 MHz although static timing failed at 72 MHz, because the trace doesn't exercise the slowest path. Static timing is the sign-off; the SDF run is a cross-check |


---

## 13. Two clocks, synthesis and gate-level timing simulation

Three further levels of checking sit on top of the Hatari comparison. Each depends on the level before it, and each has its own reference:

| Level | Reference | Command | Result (2026-11-26) |
|-------|-----------|---------|--------------------|
| RTL, one clock | Hatari (`expected.txt`) | `hdl/videl/sim.sh` | 9 tests, 0 errors |
| RTL, two unrelated clocks | Hatari | `hdl/videl/sim.sh -gBUS_HALF_PS=10000 -gPIX_HALF_PS=3367` | 9 tests, 0 errors (also 3367/10000 and 7000/13001) |
| Synthesis + place and route | Clock constraints | `hdl/videl/syn/synth.sh` | `pix_clk` 236 MHz (target 148.5 MHz, pass); `bus_clk` 129 MHz (target 100 MHz, pass). Before the decode was pipelined (§13.3.1): 72 MHz, fail |
| Pre-route netlist, zero delay | RTL trace | `hdl/videl/syn/gatesim.sh` (step 2) | 6,204 cycles, 0 mismatches |
| Routed netlist, zero delay | RTL trace | `gatesim.sh` (step 3) | 6,204 cycles, 0 mismatches |
| Routed netlist + SDF delays | RTL trace | `gatesim.sh [PERIOD_PS]` (step 4) | 0 mismatches at 20, 10 and 8 ns; mismatches at 6.734 ns (above `bus_clk`'s 129 MHz, §13.7) |

The tools are Yosys 0.52, nextpnr-ecp5 0.9 and Icarus Verilog 12.0, from the Ubuntu packages, unpacked into `tools/fpga/` the same way as GHDL (§7): `tools/get-fpga-tools.sh` downloads them and `tools/fpga.sh <tool> …` runs them. GHDL comes from the sandbox (§7) or a system install; `GHDL=ghdl` selects the latter.

### 13.1 Two clocks in RTL simulation

The testbench used to drive `bus_clk` and `pix_clk` from one signal. It now has two generics, `BUS_HALF_PS` and `PIX_HALF_PS` (half-periods in ps). They default to equal values, which reproduces the old single-clock run. Different values make `pix_clk` an unrelated clock. The pixel reads (`pixel()` procedure) now synchronise to `pix_clk`; everything else stays in `bus_clk`.

This checks that the core still produces Hatari's results when the line buffer and palette are written in one clock domain and read in another. It doesn't check metastability: RTL simulation can't produce it. The geometry record still crosses without synchronisers (§12).

### 13.2 The synthesis wrapper

`videl_core` is a block inside the SV-Lite FPGA, not a chip top level. Its `geom` record alone is about 120 bits, and with it the ports total about 300 bits, more than the 203 user I/O. `syn/videl_synth_top.vhd` exists only to get the core through place and route:

- every port except `geom` goes to a pin **through a register**, so all pin paths are register-to-register and nextpnr reports the core's internal timing, not pad timing;
- `geom` is XOR-folded (`fold_geom` in `videl_pkg`) into 8 registered bits. A bit that nothing reads would be optimised away together with its logic; the fold keeps all of the decode alive. It costs a few LUTs that the real design won't have.

That comes to 180 pins, including the 2 clocks; nextpnr places 180 `TRELLIS_IO`.

The registers move every core input one cycle later and every output one cycle later. `tb_gate.v` accounts for this (§13.5).

### 13.3 Synthesis and place and route (`syn/synth.sh`)

1. **GHDL → Verilog.** `ghdl --synth --std=08 --out=verilog videl_synth_top`. GHDL recognises the five RAMs (`pal0`–`pal3`, `lbuf`) and writes them as Verilog memories. No Yosys GHDL plugin is needed (T25).
2. **Yosys** `synth_ecp5 -nodsp`. `-nodsp` keeps the one multiplier out of a `MULT18X18D`, which has no simulation model (T26).
3. **nextpnr-ecp5** `--um5g-45k --package CABGA381 --speed 8` with `syn/videl.lpf`, which holds clock targets only: `bus_clk` 100 MHz (a stand-in; the CT63 bus clock is **unverified**) and `pix_clk` 148.5 MHz (1920×1080@60). Pins are placed automatically. `--timing-allow-fail` lets the flow finish and write the netlist even when timing fails, so the result is reported rather than stopping the script. Outputs: `routed.json`, `videl_routed.sdf`, `report.json`, `nextpnr.log`.
4. **Yosys** `read_json routed.json; write_verilog -noattr -norename videl_routed.v` (T28).

Resources (place and route, LFE5UM5G-45F):

| Resource | Used | Of | Note |
|----------|------|----|------|
| TRELLIS_COMB (LUT4 halves) | 2,366 | 43,848 | 5% (2,252 before pipelining) |
| TRELLIS_FF | 1,221 | 43,848 | 3%, including 178 wrapper registers (107 in, 71 out) and about 290 decode pipeline registers |
| DP16KD (18 kbit block RAM) | 7 | 108 | 4 for the line buffer, 3 for the palette |
| TRELLIS_IO | 180 | 245 | wrapper only; not the real pinout |

Timing:

- **`pix_clk`: 236 MHz, PASS** at 148.5 MHz. The worst path is the output register → `out_rgb` pad route in the wrapper, not core logic.
- **`bus_clk`: 129 MHz, PASS** at 100 MHz. The worst path now starts at a wrapper input register and ends in the line fetch (`videl_fetch`), 2.35 ns of logic and 5.40 ns of routing.

Whether 100 MHz is the right target depends on the CT63 bus clock (**unverified**). The SV-Lite design study asks for timing at 110 MHz (risk R2 in [sv-lite.md](sv-lite.md)), and 129 MHz clears that too.

#### 13.3.1 Pipelining the mode decode

The first run reached only **72 MHz** on `bus_clk`. The critical path ran from the register shadow (`videl_regs`) through `videl_decode` into the geometry register: Hatari's whole mode decode, with its variable shifts, border adders, `/2` steps and the `drawable` sum, was evaluated in one cycle.

The decode result only changes when a register is written, and the core uses one geometry per frame (§12), so extra latency costs nothing. `videl_pkg` now splits the decode into three stage functions, and `videl_core` registers between them:

| Stage | Function | Computes |
|-------|----------|----------|
| 1 | `decode_s1` | bpp, cycles per pixel and divider, X size, `hdb_off`/`hde_off`, raw vertical differences (clamped at 0), pass-through fields |
| 2 | `decode_s2` | left/right borders (`lb`/`rb`, truncation, shift by cycles per pixel), vertical halvings |
| 3 | `decode_s3` | `drawable` (the 32 × 32 test) |

`videl_decode` is now defined as `decode_s3(decode_s2(decode_s1(…)))`, so a single-cycle use of the function still gives exactly the staged result. A write takes 4 `bus_clk` cycles to reach `geom` (shadow register + 3 stages); the testbench waits 4 cycles after the last write of a test instead of 2.

Result: 72 → 129 MHz, at a cost of about 110 LUTs and 290 flip-flops. All 9 Hatari vectors still pass, with one clock and with two.

### 13.4 Making the routed netlist simulate (`tools/ecp5_sim_compat.py`)

Yosys's `share/yosys/ecp5/cells_sim.v` is the simulation library for ECP5 cells. With Yosys 0.52 and nextpnr 0.9 from Ubuntu it doesn't simulate a routed netlist correctly. The script writes a patched copy to `build/syn/cells_sim_compat.v`; the Yosys file itself is untouched.

Each problem was found by simulating the post-synthesis netlist (`synth.json` → `write_verilog`, which passes) and the routed netlist side by side, dumping both to VCD, and following the earliest diverging net back to the cell whose inputs agree and whose output doesn't:

| # | Problem | Symptom | Fix |
|---|---------|---------|-----|
| 1 | Unused fabric inputs are left unconnected; nextpnr records the needed value in `*MUX` parameters, for example `CSA0MUX="INV"` on an open pin to get 0 | `z` into a LUT → x | An open LUT input (`A`–`D`) or RAM pin reads **1**, which is what the RAMs' "INV on an open pin" settings imply. Checked both ways: reading 0 gives mismatches on every cycle, reading 1 matches |
| 1b | Open carry-in `FCI` (25 chain starts) and open LUT5 select `M` | x along carry chains | Model reads open `FCI` as 0 and open `M` as 1. **Not confirmed:** for this design every combination of 0 and 1 matches the RTL, so the trace doesn't distinguish them |
| 2 | `TRELLIS_FF` lacks nextpnr's `SD` parameter: `SD="0"` loads from `M`, `"1"` from `DI` | 421 FFs load an unconnected `DI` | `D = (SD == "0") ? M : DI` |
| 3 | `TRELLIS_IO` lacks `DATAMUX_ODDR`/`DATAMUX_MDDR` | Elaboration error | Parameters added (only `"PADDO"` is used) |
| 4 | No `DCCA` (global clock buffer) model | Elaboration error | Added |
| 5 | `DP16KD` is an empty shell (ports and parameters only) | `out_rgb` always x | Behavioural model for equal port widths 1/2/4/9/18, NOREG/OUTREG, the three write modes, CS decode, output reset, 18-bit byte enables. Non-zero `INITVAL` is reported, not loaded |
| 6 | `TRELLIS_COMB` CCU2 mode declares a local `wire FCO = …` that **shadows the `FCO` output port** | Every carry between slices is `z` | `assign FCO = …` |
| 7 | `TRELLIS_COMB` chooses its `OFX` mux (L6MUX21 or PFUMX) by `IS_Z1`, which nextpnr doesn't write | Wide-LUT outputs wrong (one `geom_fold` bit) | Use the L6MUX when `FXA`/`FXB` are connected |
| 8 | No path delays on `TRELLIS_COMB`, `DP16KD` and `DCCA`; `TRELLIS_FF`'s are conditional and name `DI` | IOPATH delays can't bind | Plain `specify` paths for every IOPATH nextpnr writes |

The script asserts that each pattern it patches is present, so a different Yosys version stops with "model changed" instead of silently producing a wrong library.

**Proof that the patched library is right for this design:** `gatesim.sh` step 3 simulates the routed netlist at zero delay against the RTL trace, and it matches on every checked cycle. Run that step first whenever the tools or the design change.

### 13.5 Trace replay (`tb_videl_core` `TRACE` → `syn/tb_gate.v`)

The VHDL testbench can't drive a Verilog netlist in Icarus, and rewriting it in Verilog would duplicate the Hatari comparison. Instead:

1. `sim.sh -gTRACE=trace` writes `build/trace_in.txt` and `build/trace_out.txt`. Each line is one `bus_clk` cycle, sampled at the falling edge: 107 input bits (what the core latches at the next rising edge) and 71 output bits (`fold_geom(geom)`, then the other outputs, in the wrapper's port order). `U` and other unknowns are written as `x`. A trace needs one clock (`BUS_HALF_PS = PIX_HALF_PS`).
2. `tb_gate.v` loads the trace with `$readmemb` and drives the **wrapper**. With clock edges numbered from 1: the pins after edge *m* carry `trace_in[m]`, which the core latches at *m*+2 after the input register; outputs read just before edge *m*+1 must equal `trace_out[m−2]`. Expected `x` bits aren't checked, nor is `out_rgb` while the expected `out_valid` is 0 (T34), nor the first `WARMUP` = 50 cycles (T33).
3. Plusargs: `+in=`, `+out=`, `+sdf=`, `+vcd=N` (dump all nets for N cycles, for debugging). Parameters: `PERIOD`, `HOLD` (default `PERIOD/2`, i.e. the falling edge, T31), `SAMPLE` (100 ps), `WARMUP`, `SHOW`. Compile the routed netlist with `-DDUT=top`, because nextpnr renames the top level.

The pre-route netlist run (step 2) needs no models. It checks both the trace alignment and that GHDL's synthesis preserved the behaviour.

### 13.6 Timing annotation (`tools/sdf_icarus.py`)

nextpnr's SDF has three kinds of entry: about 9,400 INTERCONNECT (wire delays, per sink pin), about 9,700 IOPATH (cell delays) and about 4,200 SETUPHOLD checks. Small test cases showed that Icarus 12:

- parses INTERCONNECT and **silently ignores** it;
- rejects `PORT` delays with a syntax error;
- rejects nextpnr's instance names, which contain bare `.` under `DIVIDER /`, but accepts them with the dots escaped;
- prints "Cannot find core in scope" for those escaped names and still applies the delays;
- doesn't evaluate timing checks.

So the script:

1. turns each INTERCONNECT into a delayed `assign #(rise, fall)` placed in front of that one sink pin of the netlist (`videl_routed_ic.v`);
2. writes an SDF with only the IOPATH entries, names escaped (`videl_routed_ic.sdf`);
3. picks one corner of each `(min:typ:max)` triple. The default is `max`, the setup-critical corner.

A Verilog assignment delay is inertial: pulses shorter than the wire delay disappear, which matches the usual SDF pulse-rejection default.

**Proof that the delays are applied:** at a 10 ns period with the lutperm-disabled build, wire delays alone gave 0 mismatches and wire plus cell delays gave 1. At 8 ns the figures were 3 and 13. Without the SDF, every period passes.

### 13.7 Reading the results

- `gatesim.sh` drives both clocks from one source, so a single period has to satisfy both domains. 6.734 ns (148.5 MHz) fails because of `bus_clk` paths, as static timing predicts.
- 8 ns (125 MHz) passes, matching static timing (129 MHz).
- Before the decode was pipelined, the SDF run passed at 10 ns (100 MHz) although static timing said `bus_clk` only reached 72 MHz. Static timing takes the slowest path for any data; the simulation only sees the data in the trace, which never toggled that path in a critical way. **Static timing (`nextpnr.log`) is the sign-off; the timed simulation is a cross-check** that the netlist, the delays and the clocking behave as the analysis claims.
- A failure that doesn't move when the period changes is a hold problem in the test set-up (T31), not a speed limit.

### 13.8 Reproducing

```bash
tools/get-fpga-tools.sh
```

```bash
hdl/videl/sim.sh -gBUS_HALF_PS=10000 -gPIX_HALF_PS=3367
```

```bash
hdl/videl/syn/synth.sh
```

```bash
hdl/videl/syn/gatesim.sh 20000
```

`synth.sh` takes about 80 s and `gatesim.sh` about 40 s. Extra arguments to `synth.sh` go to nextpnr (for example `--seed 3` or `--disable-router-lutperm`). The second argument to `gatesim.sh` selects the delay corner.


[S011]: ../../sources/INDEX.md
[S031]: ../../sources/INDEX.md
[S032]: ../../sources/INDEX.md
[S035]: ../../sources/INDEX.md
