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
| **CT60 TOS 3.00** (github.com/mikrosk/ct60tos, release tag `3.00`) | CT60 TOS with `SV_XBIOS` built in (under 100 lines of integration code), plus fixes inherited from CT60 TOS 1.03f; SV settings via `CT60CONF.CPX` | [S013][S020] |
| **FreeMiNT SVEthLANa driver** | New network driver, ported from the Linux driver, in FreeMiNT snapshots | [S013] |
| **Linux 7.3** | SVEthLANa support (mostly configuration of the existing OpenCores MAC driver) plus framebuffer fixes, sent upstream | [S013] |

### SuperVidel Drivers 1.00 package [S014]

Released 2026-09-18 by MiKRO. It's mainly a bug-fix release of PeP's drivers.

| File | Size | Notes |
|------|------|-------|
| `auto/sv_xbios.prg` | 101,910 | Banner "SuperVidel XBIOS Extensions"; reports a revision and build date. Says "Hardware not found" when there's no SV |
| `gemsys/svscreen.sys` | 6,888 | NVDI screen driver. Reads `SV.INF` and loads the colour-depth driver it needs: NVDI's own `NVDIDRV1/2/4/8/H.SYS` for bitplane and Falcon high-colour modes, or `SV_BPS8C/16/32.SYS`. It also names an `SV_BPS24.SYS`, which isn't in the package |
| `gemsys/sv_bps8c.sys` | 6,571 | "SuperVidel 256 colours (Packed)", i.e. 8-bit chunky |
| `gemsys/sv_bps16.sys` | 6,928 | "SuperVidel 32768 colours" |
| `gemsys/sv_bps32.sys` | 7,642 | "SuperVidel 16M colours" |
| `assign.sys` | 677 | Example: `SVSCREEN.SYS` for devices 01–05 and 07, with Monaco fonts |
| `sv.inf` | 1,188 | Configuration file (see below) |
| `readme.txt` | 1,215 | Changelog |

All the binaries are standard GEMDOS executables (they start with `$601A`). [S014]

**Changes in 1.00** (from `readme.txt`) [S014]:

- `Vsync()` now really waits for vertical sync. However, the `$70` VBL vector is still driven by the motherboard Videl's VBL, not by the SV.
- Many fixes to the desktop video dialog; the odd 61 Hz modes were removed.
- The bottom of the screen is cleared properly, for example when a `.TOS` program starts and during boot.
- `VsetMode()` clears `$FFFF820E`, as TOS and EmuTOS do.
- `svscreen.sys` now uses the cleaner code from PeP's "v4nvdi" proof of concept (`svscreen2.zip`, 2023).
- The Atari boot logo and other things are fixed in 32 bpp.
- The console code was reworked to use NVDI's console code.
- Many other code errors were fixed.

### `SV.INF` configuration [S014]

Keys are case-sensitive and must be lower case. Keys marked [FLASH] are read from flash rather than from this file when `SV_XBIOS` is in ROM (as in CT60 TOS 3.00).

| Section | Key | Example | Meaning |
|---------|-----|---------|---------|
| `[VDI]` | `default` | `$401c` | Default resolution if the AES doesn't specify one |
| | `forced` | `$4018` (commented out) | Overrides the AES resolution |
| | `dual` | `off` | Dual-screen desktop. `svscreen.sys` also contains the words `vertical` and `horizontal`, presumably the other values **(unverified)** |
| | `vdi_bps8c` | `false` | [FLASH] Allow 8-bit chunky in the TOS VDI |
| | `vdi_bps32` | `false` | [FLASH] Allow 32-bit true colour in the TOS VDI |
| | `restrict_x`, `restrict_y` | `0` | Limit the VDI screen width/height (0 = off) |
| `[XBIOS]` | `bootmode` | `$401a` | [FLASH] Resolution used at boot |
| | `primary` | `vga` | [FLASH] Primary output |
| | `clone` | `true` | [FLASH] Send the screen to both the primary and secondary outputs |
| `[HACKS]` | `rezdialog` | `true` | [FLASH] Extended desktop video dialog |
| | `fast_videl` | `true` | [FLASH] Accelerate Videl resolutions in GEM |
| | `kill_videl` | `false` | [FLASH] Turn the Videl off in SV resolutions ("do not use") |
| | `pmmu_boost` | `true` | [FLASH] Higher CPU↔VRAM bandwidth (presumably via the 68060 PMMU cache mode for VRAM) **(unverified)** |

**Extended mode words:** `default`, `forced` and `bootmode` take 16-bit `VsetMode()`-style values such as `$401A`, `$401C` and `$4018`, and the desktop dialog shows a "Modecode". Bit 14 (`$4000`) appears to mark SuperVidel modes. **(unverified)** How the other bits are laid out in SV modes isn't documented yet. The `sv_xbios` source or CT60 TOS 3.00 should settle it.

### Software identifiers seen in `sv_xbios.prg` [S014]

These were found with `strings`; their purpose is inferred, not documented.

- `XBRASupV`: the driver hooks vectors using the XBRA protocol with ID **`SupV`**.
- The driver installs a **`SupV` cookie**. This is confirmed by CT60 TOS 3.00, which defines `SV_COOKIE` as `'SupV'`, and by `CT60CONF.CPX`, which looks the cookie up. [S021] See [../programming/detection.md](../programming/detection.md).
- `MagX`: the driver checks for MagiC.

### CT60 TOS compatibility warning

In September 2025 MiKRO wrote that the SV "has a serious issue which is probably never going to be fixed" without the VHDL source. He said it works with CT60 TOS 1.03c "just by chance" and doesn't work with 1.05. [S015]

Nine months later, the CT60 TOS **1.03e** release notes (2026-06-21) include: *"Don't try to detect internal and external video clocks when SuperVidel is present (hopefully good enough to work around the SuperVidel lockup on early boot)"*, citing atari-forum post p=439917. [S020] This is very probably the same issue: an **SV lockup early in boot, triggered by TOS's video-clock detection**, worked around in TOS rather than fixed in the SV. **(inferred; the two sources don't refer to each other)** 1.03f and 3.00 build on 1.03e. [S020]

For developers: avoid probing the Falcon's internal/external video clocks (the Videl clock-detection that TOS does at boot) when an SV is present. The details of what TOS 1.03c/1.05 do differently are in the CT60 TOS source, which hasn't been examined yet.

### CT60 TOS releases relevant to the SV [S020]

| Release | Date | SV-relevant changes |
|---------|------|---------------------|
| 1.03c (`ct60_404.lzh`) | (uploaded 2016-12-03) | Original CT60 TOS; per S015, works with the SV "just by chance" |
| 1.03d | 2017-04-10 | The CT60e build of 1.03c (flash ID check relaxed); no SV changes noted |
| 1.03e | 2026-06-21 | Skips video-clock detection when an SV is present (early-boot lockup workaround); no longer corrupts the Atari logo on SV (code from insane's CT60 TOS 1.05); fixes the double-line/interlace flag when switching between RGB and VGA. Also: **`060sp.prg` is now required under FreeMiNT/MagiC** |
| 1.03f | 2026-09-18 | "Further Videl safety fixes"; base for the SV flavour |
| **3.00** | 2026-09-18 | **SV XBIOS built in**: boots in 1920×1080×32bpp. **`CT60CONF.CPX` replaces `SV.INF`** for SV XBIOS settings, because SV.INF can't be read before the hard disk is available. Boot picture and boot delay removed. Still runs on CT6x boards without an SV (without the boot picture) |

Notes from the 3.00 release:

- shoggoth77 connected the SV's capabilities to TOS's existing 8/16/32 bpp chunky routines, which might make CTPCI support straightforward later. [S020]
- The `[FLASH]` keys in `SV.INF` (see above) are the settings that 3.00 keeps in flash and edits through `CT60CONF.CPX`. **(inferred from S014 + S020)**

A commenter on S013 said CT60 TOS 1.05 would be rebased and later merged with 3.00. That was a stated plan, not a release. [S013]

S013 says the SuperBlitter is used for VDI blitting. Text rendering doesn't use it yet. [S013]

## Firmware

- Firmware is shipped as **XSVF** files. `SV-JTAG.TTP <path to .xsvf>` erases and programs the two Xilinx configuration PROMs. It must run in **68060 mode**, was tested mostly under MiNT, and should also work under TOS and MagiC. It prints a percentage; there's a pause at 47% while the second PROM is erased. [S010][S012]
- **Don't cut power during an update.** A half-programmed SV will be dead until it's reprogrammed with a Xilinx Platform USB cable and the Xilinx WebPACK software. [S012]
- The new firmware takes effect after a power cycle. [S001]
- **Later updater:** by 2013, Nature's firmware note refers to an Atari updater called **`SVUPDxxx.APP`**, apparently named after the firmware version, in place of `SV-JTAG.TTP`. [S018] A 2022 post mentions an "FW11 update app". [S018]

### Known firmware versions

Firmware versions appear in the sources in two forms: three-digit ("v005", "FW010") and short ("v7", "FW11").

| Version | Date | Notes | Ref |
|---------|------|-------|-----|
| v005 | 2013-08-27 | Released as **MCS** files for Xilinx Impact, for recovering a bricked SV | [S018] |
| v7 | — | Mentioned as a version a user was running in 2022 | [S018] |
| FW009 | — | SVEthLANa driver without transmit DMA | [S013] |
| FW010 (v10) | — | SVEthLANa transmit DMA (with hardware bugs); mentioned in a "FW 010 → crash" thread | [S013][S018] |
| FW11 | — | Referenced only as "FW11 update app" (forum post p=369936, not yet fetched) | [S018] |

Release dates, changelogs and the latest version are still to be found.

The installed firmware revision is shown on the Atari, for example by the updater or the drivers. After a bad JTAG flash, one user saw it reported as "000". [S018] Which register holds the revision isn't in S011's 2012 register map.

### Recovery over JTAG (Xilinx Impact)

Use this when the Atari-side updater can't be used, i.e. the SV is "bricked". It is pieced together from Nature's v005 release note (as quoted in S018) and users' reports in S018.

1. **Hardware:** a Xilinx Platform Cable USB and its **2 mm-pitch 14-pin flat cable**, connected to **JP2 near the DVI connector**. Mind the key on the cable, and don't press on the chips on the underside of the SV while plugging it in. [S018]
2. **Software:** Xilinx ISE 14.7 iMPACT. Nature mentions WinXP or later, or Ubuntu. MiKRO recommends Arch Linux with the AUR packages `xilinx-ise` and `xilinx-usb-drivers`, which also need a Xilinx licence and `Xilinx_ISE_DS_Lin_14.7_1015_1.tar` from Xilinx. [S018]
3. **Power:** the cable needs the target's reference voltage, so the SV must be powered. MiKRO (2023) left the SV in the Falcon with the machine running throughout, and others flashed in 68060 mode. An earlier memory of flashing with the SV off the CT60 wasn't confirmed. [S018]
4. **File order matters.** iMPACT shows the two PROMs in the JTAG chain: put **`*_1.mcs` on the left device and `*_0.mcs` on the right**. Swapping them gives a board that reports firmware 000. [S018]
5. iMPACT warns that the MCS files aren't configuration files. Two users ignored the warning and the flash worked. [S018]
6. Erase, blank-check, program and verify each PROM, then power-cycle. [S018]

Nature's note also refers to "the instructions manual for updating the ABE+SDR" (the CT60's CPLDs) as the base procedure. That is the CT60 update page [S019], which programs the CPLDs with iMPACT and a Xilinx cable, and points to a PC walkthrough at nokturnal.pl (not yet fetched). The exxoshost CT60 flash page linked from S018 covers the same procedure (not yet fetched).

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

- The `sv_drivers` source (PeP's repository, as revived by MiKRO). CT60 TOS 3.00 includes the SV XBIOS only as a binary (`nonfree/sv_xbios.bin`) [S021], so the mode-word format and the Videl emulation details still need the driver source.
- The FreeMiNT SVEthLANa driver source, which should describe the DMA workarounds.
- The Linux 7.3 SVEthLANa and framebuffer code.
- Firmware XSVF files and changelogs (FW009, FW010, any later versions).
- The OpenCores Ethernet MAC documents (`eth_speci.pdf`, `eth_design_document.pdf`).
- Nature's firmware release page (v005 and later notes, MCS/XSVF files, `SVUPDxxx.APP`), and the atari-forum posts linked from S018 (p=370890, 369936, 297790).
- The atari-forum threads linked from S015 (p=332511, 332633, 466225 on SV3, 466543).
- The SVEthLANa installation manual and the CT60 extender-board manual, both mentioned in S012.

[S001]: ../../sources/INDEX.md
[S010]: ../../sources/INDEX.md
[S011]: ../../sources/INDEX.md
[S012]: ../../sources/INDEX.md
[S013]: ../../sources/INDEX.md
[S014]: ../../sources/INDEX.md
[S015]: ../../sources/INDEX.md
[S018]: ../../sources/INDEX.md
[S019]: ../../sources/INDEX.md
[S020]: ../../sources/INDEX.md
[S021]: ../../sources/INDEX.md
