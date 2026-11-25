# Drivers, Firmware and Tools

> Sources: the original 2012 documents [S010][S012] and a 2026 article on the revived drivers [S013]. Version history is still incomplete.

## Without drivers

The SV needs no drivers to work: it emulates whatever Videl mode is set. However, the TOS built-in VDI draws with the motherboard BLiTTER, whose writes the SV can't see, so the screen shows garbage. NVDI doesn't use the BLiTTER and avoids the problem. The SV drivers go further: they stop using the old BLiTTER, put the screen in SV graphics RAM, and accelerate drawing with the SuperBlitter. [S012]

## Original driver set (2012, Nature / Peter Persson)

Peter Persson (PeP) wrote the XBIOS, VDI and NVDI drivers and patches. [S012]

| File | Where it goes | Function | Ref |
|------|---------------|----------|-----|
| `SV_XBIOS.PRG` | AUTO folder, run first | Extends the VDI, XBIOS and GEM Desktop with the new modes, fast video RAM and SuperBlitter acceleration. Replaces the TOS resolution selector with one offering SuperVidel, Videl and ST modes | [S010][S012] |
| `SVSCREEN.SYS`, `SV_BPS16.SYS`, `SV_BPS32.SYS`, `SV_BPS8C.SYS` | `GEMSYS` | Accelerated NVDI 5 drivers. In `ASSIGN.SYS`, change `05p SCREEN.SYS` to `05 SVSCREEN.SYS` | [S010][S012] |
| `CHGRES.PRG` | — | Resolution switcher for MagiC | [S010][S012] |
| `SV-JTAG.TTP` | — | Firmware updater (see below) | [S010][S012] |

The file names suggest `SV_BPS8C` is the 8-bit chunky driver and `SV_BPS16`/`SV_BPS32` are the 16- and 32-bit drivers. **(unverified)**

## Revived drivers (2026)

In spring 2019 PeP gave MiKRO access to his `sv_drivers` git repository. It was a snapshot of the 2019 code with no history. In 2026 MiKRO got it building with a cross-compiler, first checking that it produced builds identical to the last official release, and then fixed a series of bugs. [S013]

| Release | Contents | Ref |
|---------|----------|-----|
| **SuperVidel Drivers 1.00** (`sv260918.zip`, from mikro.naprvyraz.sk) | Bug-fixed driver set; unpack and replace the existing files | [S013] |
| **CT60 TOS 3.00** (github.com/mikrosk/ct60tos, release tag `3.00`) | CT60 TOS with `SV_XBIOS` built in (under 100 lines of integration code), plus fixes inherited from CT60 TOS 1.03f | [S013] |
| **FreeMiNT SVEthLANa driver** | New network driver, ported from the Linux driver, in FreeMiNT snapshots | [S013] |
| **Linux 7.3** | SVEthLANa support (mostly configuration of the existing OpenCores MAC driver) plus framebuffer fixes, sent upstream | [S013] |

A commenter on S013 said CT60 TOS 1.05 would be rebased and later merged with 3.00. That was a stated plan, not a release. [S013]

S013 says the SuperBlitter is used for VDI blitting. Text rendering doesn't use it yet. [S013]

## Firmware

- Firmware is shipped as **XSVF** files. `SV-JTAG.TTP <path to .xsvf>` erases and programs the two Xilinx configuration PROMs. It must run in **68060 mode**, was tested mostly under MiNT, and should also work under TOS and MagiC. It prints a percentage; there's a pause at 47% while the second PROM is erased. [S010][S012]
- **Don't cut power during an update.** A half-programmed SV will be dead until it's reprogrammed with a Xilinx Platform USB cable and the Xilinx WebPACK software. [S012]
- The new firmware takes effect after a power cycle. [S001]
- Known firmware versions: **FW009** and **FW010**. FW010 changed the SVEthLANa driver model to send packets by DMA. [S013] Release dates and changelogs are still to be found.

## SVEthLANa networking

S013 confirms that the Ethernet MAC in the FPGA is the **OpenCores** Ethernet MAC, which is why Linux support was mostly configuration. [S013] This agrees with S011's references to `eth_speci.pdf` and `eth_design_document.pdf` (see [../hardware/memory-map.md](../hardware/memory-map.md)).

### FW010 DMA hardware issues

S013 reports **four hardware issues** in SVEthLANa transmit DMA in FW010, found by capturing corrupted packets with tcpdump. The one example given: if a packet lies on a 1 KB boundary, 64 bytes of the previous packet are repeated in the current one. The cause seems to be that FW010's DMA isn't protected from other accesses to the same memory, by the CPU or even by video fetch. The new FreeMiNT driver works around all four. The Linux driver prepares packets differently, so the bugs show up less there, but it doesn't contain the workarounds. [S013]

**Video mode affects networking:** in 32 bpp (tested at 1920×1080) the DMA problems are much more visible than in 16 bpp. Retransmissions cost about 200 KB/s in each direction. [S013] This fits the shared DDR2 arbiter shown in [../hardware/architecture.md](../hardware/architecture.md), since 32 bpp scan-out takes more DDR2 bandwidth.

The details of the four issues aren't documented yet. They're probably in the FreeMiNT driver source.

### Throughput (as reported in S013)

Upload = Atari → PC; download = PC → Atari.

| Driver | Upload | Download |
|--------|--------|----------|
| Linux-m68k (current kernel, FW010) | 700 KB/s | 1.4 MB/s |
| FW009 driver | 3274 KB/s | 710 KB/s (limited by a driver bug) |
| FW010 driver by Nature | 135 KB/s | 1.6 MB/s |
| Linux driver ported to FreeMiNT, before fixes | 42 KB/s | 3 MB/s |
| Ported driver with the 4 DMA workarounds | 4 MB/s | 3 MB/s |

## Performance notes for programmers

These are MiKRO's figures from the S013 comment thread, on a CT60/CT63 system:

| Transfer | Speed |
|----------|-------|
| TT-RAM → SV RAM, SV RAM → TT-RAM (`move16`) | about 30 MB/s each way, similar to TT-RAM → TT-RAM |
| SV RAM → SV RAM by CPU | about 20 MB/s (use the SuperBlitter instead) |
| CTPCI graphics, TT-RAM → VRAM / VRAM → TT-RAM (for comparison) | about 30 MB/s / about 9 MB/s |
| `movem.l` instead of `move16` | usually about 50% of the `move16` rate |
| SuperBlitter, VRAM → VRAM | "around 1 GB/s". Stated from memory without a measurement; **(unverified)** |

**SuperBlitter limitation:** in the chunky transparent-copy mode, the transparent byte value can't be set; it is always 0. [S013] This matches blit mode `%0001` in [../hardware/registers.md](../hardware/registers.md).

## PC tools

- **CDCE925 ClockFinder:** a .NET program that calculates clock-chip register values for a target frequency from the 25 MHz crystal. The values go into the PLL registers at `$80010004`–`$80010010`. C source that compiles and runs on the Atari is also available. [S010]

## Sources to look for

- The SuperVidel Drivers 1.00 archive (`sv260918.zip`) and the `ct60tos` 3.00 source on GitHub.
- The FreeMiNT SVEthLANa driver source, which should describe the DMA workarounds.
- The Linux 7.3 SVEthLANa and framebuffer code.
- Firmware XSVF files and changelogs (FW009, FW010, any later versions).
- The OpenCores Ethernet MAC documents (`eth_speci.pdf`, `eth_design_document.pdf`).
- The SVEthLANa installation manual and the CT60 extender-board manual, both mentioned in S012.

[S001]: ../../sources/INDEX.md
[S010]: ../../sources/INDEX.md
[S011]: ../../sources/INDEX.md
[S012]: ../../sources/INDEX.md
[S013]: ../../sources/INDEX.md
