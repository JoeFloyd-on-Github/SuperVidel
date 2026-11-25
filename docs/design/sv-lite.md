# Design Study: a Low-Cost SuperVidel-Compatible Board ("SV-Lite")

> **Status:** design proposal, not built. Facts about the original SuperVidel and the CT60 are cited. **Part choices, prices and performance figures for the new board are engineering estimates and are not taken from any source in this project.** Each one is marked **(estimate)** and must be checked against current datasheets and distributor pricing before a schematic is drawn.

## 1. Goals

| # | Requirement | Where it's handled |
|---|-------------|--------------------|
| G1 | Plugs into the CT60/CT63 060 bus slot, stacks like the original | §3 |
| G2 | Register map identical to the published SV map (Rev 7) [S024], so stock SV drivers, XBIOS and CT60 TOS 3.00 work unchanged | §6 |
| G3 | HDMI output on an FPC cable to a bracket connector | §5.1 |
| G4 | Separate FPC cable carrying analogue VGA to a DB15 | §5.2 |
| G5 | FPGA that is commonly stocked; whole board under **US$100** | §2, §8 |

Non-goals for revision A: SVEthLANa Ethernet (the header is kept, the MAC is phase 2), firmware updates through the SV's SW_JTAG register (see §6.3).

## 2. Key component choices (estimate)

| Function | Original SV [S010] | SV-Lite choice | Why |
|----------|--------------------|----------------|-----|
| FPGA | Spartan-3 XC3S2000 (discontinued family) | **Lattice ECP5-5G LFE5UM5G-45F, speed grade -8, caBGA381** (203 user I/O plus 4 SERDES channels, 44K LUT, 1.9 Mbit BRAM, 72 18×18 multipliers) | Widely stocked, roughly $25–30 in single quantities. Its SERDES channels drive HDMI at 1920×1080 @ 60 **within the datasheet rating** (§5.1), and moving the TMDS lanes onto them frees general I/O. Fully supported by the open toolchain (Yosys + nextpnr-ecp5 + Project Trellis, including the SERDES/DCU primitive, plus LiteDRAM), so anyone can rebuild the bitstream without a vendor licence. The 0.8 mm ball pitch of the 381 package fans out on 6 layers (4 is possible but tight) |
| Video RAM | 2 × Micron DDR2 512 Mbit ×16 (32-bit, 128 MB) | **2 × DDR3L 1 Gbit ×16** (e.g. MT41K64M16 class), 32-bit bus, 256 MB fitted, 128 MB decoded | DDR2 is end-of-life and dearer than DDR3L. The ECP5 has DDR3 I/O primitives, and LiteDRAM supports them. A 32-bit bus keeps the original's width, which matters for the bandwidth in §4.3 |
| HDMI/DVI | TI TFP410 | **ECP5-5G SERDES as TMDS transmitter** (3 data lanes + clock lane) + TPD12S016 (ESD, DDC level shift, +5 V switch) | Saves the transmitter and ~28 pins, and stays in spec at 1080p60 |
| VGA DAC | ADV7125 | **GM7123** (ADV7123-compatible 3×8-bit, ~$1–2) | Pin-compatible clones are cheap and plentiful |
| Clock | CDCE937 programmed over I²C | **25 MHz crystal oscillator + ECP5 PLLs** (2 EHXPLLL used for the two pixel clocks, 1 for DDR3) and an optional **Si5351A** (~$1) for exact pixel clocks | The PLL registers at `$80010004`–`$80010010` [S024] are translated to ECP5 PLL settings or Si5351 writes (§6.2) |
| Bus buffers | 13 × 74LCX245 | **6 × 74LVC16245A** (16-bit) + 1 × 74LVC125 for the open-drain/strobe outputs | §3.2 |
| Config | 2 × Xilinx PROM | **1 × 64 Mbit QSPI flash** (W25Q64 class) | Holds the bitstream and leaves room for a second "golden" image |
| Power | TPS75003 from 3.3 V and 5 V | **TPS62xxx buck 5 V→1.1 V** (ECP5 core), **buck 5 V→1.35 V** (DDR3L) + DDR3 VTT/VREF (TPS51200), LDO 3.3 V→2.5 V (ECP5 VCCAUX) | §7 |

## 3. Host interface (CT60 060 bus slot)

### 3.1 Signals used

From [../ct60/bus-slot.md](../ct60/bus-slot.md) [S022]. The SV is a bus **slave** only, so arbitration lines pass through untouched.

| Group | Signals | FPGA pins |
|-------|---------|-----------|
| Address | A31–A0 (input only) | 32 |
| Data | D31–D0 (bidirectional) | 32 |
| Strobes in | /TS, R/W, SIZ1–0, TT1–0, TM2–0, /BS3–0, CLK, /RST | 15 |
| Outputs | /TA, /TEA, /I6 (open-drain via '125) | 3 |
| Buffer control | data DIR, data /OE ×2, addr /OE | 4 |
| **Total** | | **86** |

/BR, /BG, /BB and /INT are passed through to the upper headers and not connected to the FPGA.

### 3.2 Buffering

The CT60 bus is 3.3 V (the slot supplies +3.3 V and the CT60 runs its JTAG cable from 3.3 V [S022]), the same as ECP5 VCCIO, so buffers aren't needed for level shifting. They are kept because:

- Other boards (EtherNat, CTPCI) stack on the same headers, and the CT60 manual warns that each board adds load and reflections. [S012] One buffer input per line is a lighter load than a BGA ball with its stub and ESD diode.
- A failed FPGA configuration must leave the bus free. While the FPGA isn't configured, the buffer /OE pins are pulled inactive.

Layout: address in through 2 × '16245 (fixed direction). Data through 2 × '16245, direction = R/W, enabled only while the SV is answering a read. Strobes in through 1 × '16245 (spare channels). Outputs through the '125 (/TA, /TEA and /I6 driven low or tri-stated). The CLK input gets a 33 Ω series resistor. Copy the original's **J7 clock-filter jumper**, fitted only when the board is lowest in the stack. [S012]

### 3.3 Bus timing

The FPGA samples the bus on the CT60 clock (66–100 MHz, up to the 060 clock [S022]). Its budget:

| Access | Requirement | SV-Lite design |
|--------|-------------|----------------|
| SV registers `$80010000`… | No hard limit (own address) | /TA in cycle 2–3 from flops |
| Emulated Videl `$FFFF82xx`, palette `$FFFF9800` | **Reads must assert /TA by the end of cycle 6** to override the motherboard. **Writes are latched without /TA**, so they also reach the real Videl. [S022] | Both live in block RAM, so /TA comes at cycle 2–3 |
| ST-RAM shadow (snooped writes to `$00000000`–`$00DFFFFF`) | Latch the write, don't assert /TA | Write goes into a 512-entry snoop FIFO and from there into DDR3 at `$A0000000`+addr |
| Graphics RAM `$A0000000`–`$A7FFFFFF` | Own address; wait states allowed | Reads: a 4-line read cache plus prefetch; first /TA after about 8–12 cycles on a miss. Writes: posted into a write FIFO, /TA at cycle 2. Burst (move16, line) transfers answer 4 beats [S019] |

The emulation window behaviour (latch without /TA) is how the CT60 manual says a card shadows a Falcon chip. [S022] Whether the original SV snoops ST-RAM writes in exactly this way is **(unverified)** ([../hardware/memory-map.md](../hardware/memory-map.md)).

### 3.4 Interrupts

/I6 is driven when the SuperBlitter finishes or a VGA/HDMI VSync arrives. In the interrupt-acknowledge cycle the board returns vector `$C6`, `$C7` or `$C8`. [S011] That the original works this way is **(inferred)** in [../ct60/bus-slot.md](../ct60/bus-slot.md#interrupts); confirm by scoping an original board before relying on it.

## 4. FPGA architecture

### 4.1 Blocks

```
              CT60 bus (CLK domain)
   ┌──────────────┬───────────┴────────────┬────────────────┐
   │ Bus slave FSM│  Videl regs + palette  │  SV regs       │
   │ (decode, TA) │  (BRAM, 2 read ports)  │  $80010000-83  │
   └──────┬───────┴───────────┬────────────┴───────┬────────┘
          │ CPU rd/wr FIFOs   │ translated timing  │ blit cmds (FIFO $80010080)
          ▼                   ▼                    ▼
   ┌────────────────────────────────────────────────────────┐
   │          DDR3 arbiter (priority: scan-out > CPU > blit) │
   │          LiteDRAM controller, 32-bit DDR3L-800          │
   └───────┬──────────────────┬─────────────────┬───────────┘
           ▼                  ▼                 ▼
     HDMI pipeline      VGA pipeline       SuperBlitter
   (fetch FIFO, palette, (fetch FIFO,      (src1/src2/dst
    TMDS encoder,        palette, RGB24     engines, alpha,
    HDMI clock)          → GM7123, VGA clk) mask)
```

This matches the original's split into separate VGA and DVI pipelines, each with its own clock and multiplexer, and a shared DDR arbiter. [S010] The "DVI" register block (`$80010034`–`$80010050`) drives the HDMI output.

### 4.2 Resource estimate (estimate)

| Block | LUT4 | BRAM (18 Kbit) |
|-------|------|----------------|
| LiteDRAM DDR3 + arbiter | 4,500 | 4 |
| Bus slave + FIFOs + read cache | 1,500 | 6 |
| SV regs | 800 | 0 |
| Videl core (register file, timing generator, planar/chunky/true-colour fetch; §6.4) | 3,000 | 4 |
| Palette (2 ports × 256 × 24) | 100 | 2 |
| 2 × video pipelines (fetch FIFO, mode decode 1/2/4/8 bpp planar, 8-bit chunky, 16/24/32 bpp) | 3,000 | 8 |
| TMDS encoder ×3 + SERDES (DCU) wrapper | 800 | 0 |
| SuperBlitter | 4,000 | 6 |
| **Total** | **~17,700 of 44,000** | **30 of 108** |

That leaves ample room for the OpenCores Ethernet MAC [S013] in phase 2 (about 3–4K LUT) and for a fuller blitter. It also keeps placement uncongested, which helps close timing on the 100+ MHz bus and the 148.5 MHz pixel clock.

### 4.3 Memory bandwidth (estimate)

32-bit DDR3L at 800 MT/s gives 3.2 GB/s peak. Assume about 65 % efficiency with this arbiter, so about 2.1 GB/s usable.

| Load | MB/s |
|------|------|
| HDMI 1920×1080 @ 60, 32 bpp | 498 |
| VGA 1920×1080 @ 60, 8 bpp | 124 |
| CPU (060 at 100 MHz, worst case) | ~200 |
| SuperBlitter | remainder (~1,200) |

The original was limited to 8-bit in dual-screen mode [S001]; SV-Lite should handle a 32 bpp single screen with plenty of headroom.

### 4.4 I/O count

| Use | Pins |
|-----|------|
| Host bus (§3.1) | 86 |
| DDR3L 32-bit | 66 |
| HDMI TMDS | 0 (on dedicated SERDES pins) |
| HDMI HPD + DDC SCL/SDA + CEC | 4 |
| VGA DAC: full 24-bit data + clock + /BLANK + /SYNC; HSYNC/VSYNC direct | 29 |
| Si5351 I²C, config flash (dedicated), LED, 25 MHz in | 4 |
| SVEthLANa FPC (MII + MDIO, 18 data lines as on the original [S010]) | 18 |
| **Total** | **~187 of 203** |

That leaves about 16 spare pins for debug headers or a logic-analyser port (useful for §6.3), with full 24-bit VGA and the Ethernet connector wired from rev A.

## 5. Video outputs and cables

### 5.1 HDMI: on-board receptacle plus flex

- On-board: a **right-angle HDMI type-A receptacle** (SMT/through-hole hybrid, about $0.80–1.50 **(estimate)**) at the board edge. This is the board's only HDMI connector, so the TMDS lanes see a single, impedance-controlled load.
- **Flex option:** an off-the-shelf "FPV/HDMI flex" kit, HDMI-A **male** → 20-pin 0.5 mm flex → HDMI-A **female** bracket end (about $5–8 **(estimate)**). It plugs straight into the receptacle and brings HDMI out to a bracket or case hole. Because the flex attaches through a standard HDMI-A plug, no vendor-specific FPC pinout is involved. Where the board is reachable (e.g. a CT60e in a tower case), plug the monitor cable in directly instead.
- Signals: 4 TMDS pairs, DDC SCL/SDA, HPD, CEC, +5 V (fused, 55 mA as HDMI requires), GND.
- TMDS comes from **SERDES channels** of the LFE5UM5G-45F: 3 data lanes at 10× pixel clock (1.485 Gbit/s for 1920×1080 @ 60 with CEA timing, 148.5 MHz) and the clock lane as a fourth channel sending a `1111100000` pattern. That is far below the 5G SERDES limit, so the mode is **within spec** **(estimate; confirm SERDES TMDS compliance and AC-coupling scheme against the Lattice ECP5-5G datasheet and the HDMI 1.4 electrical spec)**. The SERDES CML outputs are AC-coupled to TMDS with pull-ups to 3.3 V on the connector side.
- The pixel clock reference for the SERDES comes from the Si5351, so 1080p CEA timing (148.5 MHz) and reduced-blanking timing (138.5 MHz) are both exact.
- A TPD12S016 handles ESD, DDC level shifting and the +5 V switch.
- **Height:** the receptacle is about 6 mm tall. Place it in the area the original's DVI-I connector occupied [S010][S012], so it doesn't add to the stack height elsewhere.
- **The output is DVI-compatible HDMI.** Add HDMI audio infobox packets later only if the Falcon's sound is to be routed (out of scope).

### 5.2 VGA flex

- On-board: a **16-pin 1.0 mm FFC connector** (sturdier pitch for analogue).
- Pinout: R, G, B each with its own return (6 pins), HSYNC, VSYNC (through 74LVC1G125s with 33 Ω series, 5 V tolerant), DDC SCL/SDA, +5 V (fused), 3 × GND.
- The 75 Ω source termination stays on the main board beside the GM7123. A small 2-layer **DB15 breakout board** (designed with SV-Lite) carries only the DB15 and an ESD array.
- Keep the FFC under 30 cm; at 1920×1080 (~150 MHz pixel clock) longer unshielded flex degrades the picture.

The original had one DVI-I connector carrying both signals. [S010] SV-Lite splits them: HDMI from a real receptacle (with an optional flex extension) and VGA on its own flex, so each can go to its own bracket hole.

## 6. Register compatibility

### 6.1 What is implemented as published

Every register in [../hardware/registers.md](../hardware/registers.md) [S024] at the same address, width and long-only access rule, including:

- `$80010000` general settings/status: SV mode, VGA/DVI protect, and status bits. Bits that report hardware presence (motherboard clock valid, board revision bit 18 [S011]) read as a v2 board with no motherboard clock.
- The VGA and DVI timing blocks (`$80010014`–`$80010050`), with screen addresses as 27-bit offsets from `$A0000000`. [S024]
- The SuperBlitter at `$80010058`–`$80010078` and its FIFO at `$80010080`. [S024]
- The palette at `$FFFF9800`, the copy of the SV-mode bit at `$FFFF82C0` bit 8 [S011], and the emulated Videl registers.

### 6.2 Registers that need translation

| Register | Original target | SV-Lite behaviour |
|----------|-----------------|-------------------|
| `$80010004`–`$80010010` PLL | CDCE925/937 over I²C [S010][S011] | Decode the CDCE M/N/P values into a frequency, then program the Si5351 (or reconfigure the ECP5 PLL by dynamic port) for the same frequency. A small table is enough for the modes the drivers actually use |
| `$80010054` JTAG | Drives SW_JTAG to reprogram the Xilinx PROMs [S010] | **Reads back a "no chain" value; writes are ignored.** This makes the stock updater fail safely instead of streaming a Spartan-3 bitstream into an ECP5 |
| `$8001007C` version | Firmware revision, bits 9:0 [S024] | Report the revision whose behaviour is implemented (FW 10 or later, so the drivers use the FIFO and DDR Ethernet buffers). Put an SV-Lite marker in the unused high bits, if the drivers ignore them **(unverified)** |

SV-Lite gets its own updater: a small TOS program that writes the QSPI flash through a separate, unlisted register range (proposed: `$80011000`–`$800110FF`, which the published map leaves unused [S024]).

### 6.3 Behaviour not documented anywhere

Matching the register *addresses* is easy. Matching *behaviour* needs the following, none of which is in the sources yet; see the open questions in [../hardware/registers.md](../hardware/registers.md#open-questions):

- how the SV maps Videl modes onto its own outputs (the Videl itself is covered by §6.4);
- the extended mode-word layout and the 8-bit chunky control bit [S001];
- the exact blit-mode semantics (alpha, masks, pixel formats) beyond the table in registers.md;
- whether SuperBlitter addresses are DDR offsets;
- the DMA layout of the FW010 Ethernet buffers.

Plan for these: run the stock drivers on an original board with a bus logic analyser on the 060 slot (the ECP5 board itself, configured as a passive sniffer, can do this) and on Hatari/ARAnyM traces where they exist.

### 6.4 Videl emulation: open-source core

The SV decodes Videl register writes and translates them into its own timing ("Videl regs and translation" [S010]), and Falcon software that never touches the SV registers depends on it. SV-Lite takes this from existing open work instead of writing it from scratch:

- **Hatari** emulates the Falcon Videl in software [S035], and the **Re-Falcon** project is building a Videl FPGA core (stated by the project owner, 2026-11-25; **TODO:** add the Re-Falcon repository as a source). The detailed scope, based on Hatari's code, is in [videl-compat.md](videl-compat.md). A first VHDL implementation, checked against Hatari in simulation, is in [`hdl/videl/`](../../hdl/videl/README.md).
- **Plan:** use the Re-Falcon Videl core as the Videl block, with three adaptations:
  1. **Register front end:** connect it to the SV-Lite bus slave, which latches Videl writes in the emulation window without asserting /TA (§3.3), so the real Videl still gets them [S022].
  2. **Memory back end:** fetch from the ST-RAM shadow at `$A0000000` in DDR3 rather than from Falcon ST-RAM.
  3. **Output mux:** feed its pixels and timing into the VGA and HDMI muxes, controlled by the SV mode and VGA/DVI protect bits [S011], as in the original's architecture [S010]. For HDMI, scale or re-time low Videl modes (e.g. 320×200) to a legal HDMI timing. Not every monitor accepts the original 15/31 kHz Videl timings over HDMI.
- **Reference model:** use Hatari's Videl code as the golden reference. Run the same register sequences through Hatari and through the core in simulation (Verilator) and compare frame buffers.
- **Licensing:** Hatari is GPL. A core derived from its code is probably a GPL derivative, and so would SV-Lite's gateware be. Check the Re-Falcon core's licence before combining it with other gateware (LiteDRAM is BSD-2, the OpenCores Ethernet MAC is LGPL) **(unverified)**.

### 6.5 Open-source toolchain

All gateware is built with open tools, so the board can be rebuilt and modified without vendor licences:

| Step | Tool |
|------|------|
| HDL | Verilog/SystemVerilog, or Amaranth/Migen (LiteX) for the SoC glue; VHDL cores through GHDL + ghdl-yosys-plugin |
| Synthesis | Yosys (`synth_ecp5`) |
| Place and route | nextpnr-ecp5 with Project Trellis, including the DCU (SERDES) primitive |
| Bitstream and flashing | ecppack, openFPGALoader (over JTAG, or from the Atari through the updater in §6.2) |
| DDR3 controller | LiteDRAM (ECP5 DDR3 PHY) |
| Simulation | Verilator and cocotb, with Hatari as the Videl reference model (§6.4) |
| PCB | KiCad |

## 7. Power (estimate)

| Rail | Source | Load |
|------|--------|------|
| 1.1 V ECP5 core | buck from slot +5 V | ~1.0 A |
| 1.1 V / 1.2 V SERDES supplies (VCCA, VCCHRX/HTX) | filtered from a separate LDO | ~0.3 A |
| 1.35 V DDR3L | buck from +5 V | ~0.5 A |
| 0.675 V VTT/VREF | TPS51200 | ~0.2 A |
| 2.5 V VCCAUX | LDO from 3.3 V | 0.1 A |
| 3.3 V VCCIO, DAC, buffers | slot +3.3 V direct | ~0.4 A |

That's about 4 W in total, well within the slot's 6 A per pin [S022]. The CT60 needs an ATX supply rated for 3.3 V at 8 A or more [S022], so check the user's PSU margin when another card is stacked.

## 8. Bill of materials (estimate, single-board build, late-2026 pricing to be checked)

| Item | Qty | Unit $ | $ |
|------|-----|--------|---|
| LFE5UM5G-45F-8BG381C | 1 | 28.00 | 28.00 |
| DDR3L 1 Gbit ×16 | 2 | 3.00 | 6.00 |
| GM7123 video DAC | 1 | 1.50 | 1.50 |
| Si5351A + 25 MHz oscillator | 1 | 1.50 | 1.50 |
| 74LVC16245A ×6, 74LVC125, 74LVC1G125 ×2 | — | — | 4.00 |
| QSPI flash 64 Mbit | 1 | 0.60 | 0.60 |
| Regulators (2 buck, TPS51200, LDO) + inductors | — | — | 5.00 |
| TPD12S016 HDMI ESD/level | 1 | 1.20 | 1.20 |
| HDMI type-A receptacle, right-angle | 1 | 1.20 | 1.20 |
| FPC connector, 16-pin 1.0 mm (VGA) | 1 | 0.50 | 0.50 |
| SVEthLANa 45-pin FPC connector [S010] | 1 | 0.80 | 0.80 |
| 2×25 HE13 stacking headers (long-tail, pass-through), ×2 | 2 | 2.50 | 5.00 |
| Passives, LED, J7 jumper | — | — | 4.00 |
| 6-layer PCB, ~100 × 80 mm, ENIG, impedance control (5-off order, per board) | 1 | 14.00 | 14.00 |
| SMT assembly, incl. BGA X-ray (per board, 5-off) | 1 | 25.00 | 25.00 |
| HDMI flex kit (A-male → flex → A-female bracket), optional | 1 | 7.00 | 7.00 |
| VGA FFC + DB15 breakout PCB | 1 | 5.00 | 5.00 |
| **Total, 5-off build, both cables** | | | **≈ $110** |

The larger FPGA and 6-layer board add about $20 over the previous 25F plan. Paths back under $100 per board:

| Change | Saving |
|--------|--------|
| Build 10 or more (assembly and PCB set-up spread wider) | about $10–15 |
| Leave out the optional HDMI flex kit when the receptacle is reachable | $7 |
| Hand-solder the through-hole headers instead of paying for THT assembly | about $3 |

So a 10-off batch comes to about **$95–100** with both cables, and a 5-off batch is under $100 without the HDMI flex kit. The FPGA price is the biggest single swing factor; check it before committing.

## 9. Risks

| # | Risk | Mitigation |
|---|------|------------|
| R1 | SERDES-as-TMDS is less common than TMDS on general I/O, and the open toolchain's DCU support is less exercised than the vendor's | Prototype on an ECP5-5G evaluation board first. Fallback: the same FPGA's general-purpose DDR outputs give 1280×1024 / 1680×1050 RB within spec. This fallback needs no board change |
| R2 | Bus timing at 100 MHz through buffers (CT60-100, overclocked CTCM boards [S022]) | Time the design at 110 MHz. Register the buffer /OE and the /TA outputs in the I/O cells |
| R3 | Undocumented SV behaviour (§6.3) | Phase plan below; logic-analyser capture of an original |
| R4 | Physical fit: stacked height, the CTCM clock module [S012], and keyboard clearance on a non-"e" CT60 [S015] | Copy the original board outline and header positions; keep every part on the top side under 3 mm except the headers |
| R5 | Driver/XBIOS checks for a specific firmware revision | Version register strategy in §6.2 |

## 10. Development phases

1. **Bus bring-up:** register file, version register, a bus-error-free probe [../programming/detection.md](../programming/detection.md). Success: `SupV` detection passes and register reads and writes match.
2. **Graphics RAM + one output:** DDR3, `$A1000000` access, the HDMI pipeline with SV-mode timings. Success: stock driver boots CT60 TOS 3.00 to 1920×1080×32 bpp [S020].
3. **Second output + Videl core + palette:** VGA, the open Videl core (§6.4) for Falcon modes, ST-RAM shadow. Success: TOS desktop and Falcon demos in Videl modes on both outputs.
4. **SuperBlitter + FIFO:** NVDI/fVDI acceleration through the stock drivers.
5. **Ethernet (SVEthLANa):** OpenCores MAC with the FW010 DDR buffer layout.

## 11. Open decisions for the project owner

- Whether the Re-Falcon Videl core's licence and interfaces allow it to be used directly, or only as a reference (§6.4).
- Whether the board must stay under $100 at 5-off (drop the HDMI flex kit) or at 10-off with everything included.

[S001]: ../../sources/INDEX.md
[S010]: ../../sources/INDEX.md
[S011]: ../../sources/INDEX.md
[S012]: ../../sources/INDEX.md
[S013]: ../../sources/INDEX.md
[S015]: ../../sources/INDEX.md
[S019]: ../../sources/INDEX.md
[S020]: ../../sources/INDEX.md
[S022]: ../../sources/INDEX.md
[S024]: ../../sources/INDEX.md
[S035]: ../../sources/INDEX.md
