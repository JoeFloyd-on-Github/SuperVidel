# Videl Backwards Compatibility: Scope for SV-Lite

> Based on Hatari's Videl emulation (`src/falcon/videl.c`, commit `36a8acf`) [S035], read against the SV and CT60 documentation. Hatari's code originally came from ARAnyM and is GPL-2.0-or-later [S035]. This page uses it as a **behaviour reference**. It describes what Hatari does, which isn't always what the hardware does; Hatari's own comments flag several approximations, listed in §5.

## 1. The key simplification: SV-Lite only has to snoop writes

On the CT60 a slot card can take over Falcon addresses, or it can latch a write **without** asserting /TA, so the write also reaches the real chip. [S022] The original SV works this way for the Videl ([../ct60/bus-slot.md](../ct60/bus-slot.md#hardware-emulation-window)). So in SV-Lite the **real Videl stays in the machine and answers all its own reads**: counters, monitor type and so on. SV-Lite only needs to:

1. keep a **write-only shadow** of the Videl registers;
2. decode that shadow into a mode (§3);
3. produce the picture from the ST-RAM shadow, re-timed for VGA and HDMI.

Exceptions where SV-Lite must answer reads itself:

| Address | Why |
|---------|-----|
| `$FFFF82C0` bit 8 | Carries the SV-mode bit [S011] |
| `$FFFF9800`–`$FFFF9BFF` palette | The SV palette is 8 bits per channel [S011]. The real Videl keeps only the top 6 (Hatari masks writes with `$FCFC00FC` [S035]), so a pass-through read would lose bits in SV modes **(inferred)** |
| `$80010000`… SV registers | Own address range |

Everything else, such as video counter reads at `$FFFF8205`/`07`/`09`, VFC at `$FFFF82A0` and the read-only monitor type at `$FFFF8006` [S035], comes from the real chip, with exactly the real timing, at no cost.

## 2. Registers to shadow

From Hatari's register list and handlers [S035]:

| Address | Name | Used for |
|---------|------|----------|
| `$FFFF8201`, `$8203`, `$820D` | Video base hi/mid/lo | Screen start. Writing hi or mid **clears** lo (STE compatibility) |
| `$FFFF8205`/`07`/`09` | Video counter (writeable) | Writing restarts the scan address mid-frame |
| `$FFFF820A` | Sync mode | Shadowed only |
| `$FFFF820E` | Line offset (LOF, 9 bits) | Words skipped at end of line |
| `$FFFF8210` | Line width (LWD, 10 bits) | Words per line; width = LWD × 16 / bpp |
| `$FFFF8240`–`$825E` | ST/STE palette (16 × 12-bit) | Used after a `$8260` write. Byte writes are duplicated into both bytes |
| `$FFFF8260` | ST shift mode | Writing it **switches to ST-compatible mode** and sets LWD and VMD (§3.2) |
| `$FFFF8264`/`8265` | Horizontal scroll (4 bits) | Pixel offset |
| `$FFFF8266` | Falcon shift mode (SPSHIFT) | bpp selection (§3.1) |
| `$FFFF8280`–`$8290` | HHC, HHT, HBB, HBE, HDB, HDE, HSS, HFS, HEE | Horizontal timing and borders |
| `$FFFF82A0`–`$82AC` | VFC, VFT, VBB, VBE, VDB, VDE, VSS | Vertical timing and borders |
| `$FFFF82C0` | VCO | Bit 2: 25.175 vs 32 MHz clock |
| `$FFFF82C2` | VMD | Bits 3:2 pixel clock divide; bit 1 interlace (inverted); bit 0 line doubling |
| `$FFFF9800`–`$98FC` | Falcon palette, 256 longs | Colours in Falcon modes; entry 0 is the border colour in true colour |

That's about 40 registers: a few hundred flip-flops, or one small BRAM.

## 3. Mode decode (Hatari's model)

### 3.1 Bits per pixel [S035]

In priority order:

| Condition | bpp |
|-----------|-----|
| SPSHIFT bit 10 | 1 (Falcon 2-colour) |
| SPSHIFT bit 8 | 16 (true colour) |
| SPSHIFT bit 4 | 8 (8 bit-planes) |
| Last shifter written was SPSHIFT | 4 |
| `$8260` = 0 / 1 / 2 | 4 / 2 / 1 (ST modes) |

All the Falcon modes except true colour are **interleaved bit-planes**, which SV-Lite's fetch unit must convert to chunky. The SV's own 8-bit **chunky** mode [S001] is a separate path.

### 3.2 ST-shifter compatibility writes [S035]

Writing `$FFFF8260` makes Hatari set LWD and VMD to match the ST mode and the monitor type:

| `$8260` | LWD | VMD (VGA) | VMD (RGB/TV) |
|---------|-----|-----------|--------------|
| 0 (320, 4 planes) | `$50` | `$5` | `$0` |
| 1 (640, 2 planes) | `$50` | `$9` | `$4` |
| 2 (640, mono) | `$28` | `$8` | `$6` (mono monitor: `$0`) |

On real hardware the Videl does this itself. Since SV-Lite shadows writes, it must **repeat this side effect** in its own shadow, because the CPU never writes those LWD/VMD values. This needs the monitor type, which SV-Lite can learn once by reading `$FFFF8006` through the real Videl at reset (it passes through, §1).

### 3.3 Geometry [S035]

- **Visible width** = left border + LWD × 16 / bpp + right border. The borders come from HBB, HBE, HDB, HDE and HHT minus a pipeline offset that depends on bpp, the clock divider and ST vs Falcon mode. HDB bit 9 moves the start into the previous half-line.
- **Height** = VDE − VDB (half-lines). Halve it if VMD bit 1 = 0 (not interlaced), and halve it again if VMD bit 0 (line doubling) is set. The borders are VDB − VBE and VBB − VDE.
- **Pixel clock:** VCO bit 2 selects 25.175 or 32 MHz. VMD bits 3:2 = `00`/`01`/`10` give 4, 2 or 1 clock cycles per pixel; `11` is invalid. On a mono monitor there are no borders.
- **Line advance** = LWD + LOF words, plus the horizontal scroll.

### 3.4 Output for SV-Lite

The SV maps Videl modes onto a fixed VGA/HDMI timing; it doesn't reproduce 15 kHz RGB timing. So SV-Lite needs the Videl's **geometry** (size, borders, bpp, palette, start address) but not its **sync timing** (HSS, HFS, VSS, VFT and so on). A reasonable implementation:

1. Decode the geometry once per frame from the shadow registers, as Hatari does at each VBL [S035].
2. Fetch and convert lines from the ST-RAM shadow into a line or frame buffer in DDR3.
3. Scale it into a standard mode (e.g. 320×200 ×2 or ×3 in a 640×480/1280×1024/1920×1080 frame, with the border colour around it).

This is the same frame-level model Hatari uses, so Hatari can serve directly as the simulation reference (§6).

## 4. The real compatibility limit: what reaches the ST-RAM shadow

The decode in §3 is small and well understood. **Getting the screen data is the hard part.** SV-Lite sees only accesses that cross the CT60 bus. [S022] Writes into ST-RAM by Falcon-side bus masters never reach it:

| Writer | Seen by SV-Lite? | Effect |
|--------|------------------|--------|
| 68060 (CPU) writes | Yes, snooped | Works |
| Falcon BLiTTER | **No** [S012] | Garbage on screen. TOS VDI is affected unless NVDI or the SV drivers are used [S012] |
| DSP DMA / SDMA / ACSI/SCSI DMA loading screens | **No (inferred)** | Pictures loaded from disk straight to the screen, or written by the DSP, are missing |
| Writes made in 030 mode | No | Not relevant: the SV is a 060-mode device |

Options, from cheapest to most complete:

| Option | Cost | Coverage |
|--------|------|----------|
| A. Snoop CPU writes only (the original SV's model, **inferred**) | None | Same as the original SV |
| B. Also **re-read the visible ST-RAM screen** over the Falcon bus as a bus master (the slot can be a master [S022]) during each frame | Bus-master logic and arbitration. Bandwidth: a 320×200×16 bpp screen is 128 KB per frame, 6.4 MB/s at 50 Hz, more than the 4.55–5.5 MB/s the CT60 manual measured for a stock Falcon's memory [S022]. If CT60-to-ST-RAM reads are similar (**unverified**), refresh would have to be partial (dirty regions) or at a lower rate | Catches BLiTTER and DMA writes, with lag. Slows the CPU's own ST-RAM access |
| C. Tap the Falcon's **video output** instead: digitise the real Videl's RGB/VGA signal and re-scale it | ADC + sync capture | Perfect compatibility for anything the real Videl shows, including raster tricks. Analogue quality only |

Recommendation: implement **A** for rev A (parity with the original SV) and keep **B** as an option behind a register bit. Run the bandwidth tests on real hardware before relying on it. **C** is out of scope.

## 5. What Hatari does not model

Hatari's comments mark these as approximate or unknown [S035]. They are equally uncertain for SV-Lite, and Re-Falcon's work or hardware tests should settle them:

- **Line offset with horizontal scroll:** the render is "naive". The exact skip rule when `$8264`/`$8265` is non-zero, and its meaning in true colour, aren't clear.
- **1-bitplane mode** "seems to behave like the 4 bit planes mode" on a real Falcon.
- **VFC** advances every half-line on hardware but every line in Hatari.
- **Mid-frame changes:** Hatari renders the whole frame at VBL from the final register values. Raster effects (palette or mode changes per line) aren't shown. SV-Lite can do better by latching the palette and the scan address per line, at the cost of a line-based pipeline. Real demand for this is mostly demos.
- **Width cap:** Hatari halves widths above 2048 pixels; the largest known real Videl width is about 1600.
- The `$FFFF820A` sync mode is stored but has no effect.

## 6. Verification plan

1. **Golden model:** build Hatari's `videl.c` mode-decode functions (§3) as a small C library and call it from a Verilator/cocotb testbench. Feed both the same register write sequence and compare width, height, borders, bpp and the decoded frame.
2. **Register traces:** log Videl writes from Hatari (it has a `TRACE_VIDEL` trace class [S035]) while it runs TOS, games and demos, and replay them into the testbench.
3. **On hardware:** use a logic-analyser port (the spare FPGA pins in [sv-lite.md](sv-lite.md#44-io-count)) to capture the original SV and SV-Lite side by side.

## 7. Implementation

A first VHDL core following this page is in [`hdl/videl/`](../../hdl/videl/README.md). It passes the golden-model comparison against Hatari's unmodified `videl.c` from step 1 above [S035], and it is simulation-only so far.

## 8. Licence

Hatari is GPL-2.0-or-later. [S035] Using it as a test reference doesn't affect SV-Lite's licence. Translating its logic into HDL probably makes the result a GPL derivative **(unverified; not legal advice)**. Either release the SV-Lite gateware under the GPL, or implement the decode from the hardware documentation (e.g. S031, S032) and use Hatari only to test against.

[S001]: ../../sources/INDEX.md
[S011]: ../../sources/INDEX.md
[S012]: ../../sources/INDEX.md
[S022]: ../../sources/INDEX.md
[S031]: ../../sources/INDEX.md
[S032]: ../../sources/INDEX.md
[S035]: ../../sources/INDEX.md
