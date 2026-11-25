# Board Revisions and Availability

> Sources: Nature's 2012 documents [S001][S003][S011][S012] and a 2025 community thread [S015][S016]. Much of S015 is second-hand, so its claims are attributed individually.

## Timeline

| When | Version | Evidence |
|------|---------|----------|
| Before the CT60 shipped; full-time from 2008 | Development | "a work in progress since before the CT60 was released, but a full time project since 2008" [S012] |
| January 2009 | **Rev 1 prototype**, blue PCB | Photo with EXIF date 2009-01-16 [S003]; "prototype boards ... taken just after we got them in january 2009" [S001] |
| 2012 | **Production**, orange PCB; price €248 ex VAT / €310 with Swedish VAT | [S001] |
| 2012 | Board drawing labelled **"SuperVidel v2"** in the installation manual | [S012] p. 8 |
| — | Hardware revision readable in software: `$80010000` bit 18 = 1 on rev 1, 0 on rev 2 | [S011] |
| 2022 | **"SuperVidel v2022"** PCB layout, "designed in Sweden, made in Czech". Linked in S015 to Centuriontech's planned new batch | [S015][S016] |
| About 2021, shown 2024 | **SV3** development version based on a Xilinx Zynq 7020 | [S015] (see below) |

How "rev 1/rev 2" in S011 relates to the "v2" drawing and the production boards isn't settled yet. S015 also calls the production board "SV2".

## SuperVidel v2022 (S016)

Only a top-side PCB render is available. It isn't a schematic, and there's no BOM. Compared with the v2 drawing in S012:

- The same core placement: DDR2 at U1/U2, the FPGA at U8, and U4/U6 next to the video connector. On v2, U4 is the ADV7125 DAC, so U4/U6 are probably the DAC and the TFP410. **(unverified)**
- **Three separate regulators**, U22 (2.5 V), U23 (1.8 V) and U24 (1.2 V), instead of the single TPS75003 in S010's block diagram. **(unverified: inferred from the silkscreen voltage labels)**
- A "CT60CLK" two-pin jumper (the CT60 clock filter); J3/J4 for the CT60 headers; a 14-pin JTAG header at the bottom right; J7 at the top right; J8 along the right edge; EI0/EI1 at the left edge.
- Y1 is marked "16M". **(unverified; it may not be a frequency)**

Reference designators differ from v2 (for example J7 is the CT60 clock jumper on v2 but sits elsewhere here), so **don't use v2 jumper names on a v2022 board** without checking.

Status: per S015, Centuriontech's run started in 2022 and was postponed. The reasons given there were parts cost and availability, and the loss of work in a hard-disk crash. [S015]

## SV3

Per one S015 poster, relaying conversations with Henrik and Torbjörn Gildå:

- SV3 is based on a **Xilinx Zynq 7020** on a **Z-turn** board, with an adapter board to the CT60.
- The VHDL and adapter were "mostly ready" about four years before September 2025.
- It was reportedly shown at Sommarhack 2024 (atari-forum post p=466225, not yet fetched).
- Another poster says Nature advised waiting for the new version rather than making more of the old one.

All of this is second-hand. [S015]

## Component obsolescence

From S015 (second-hand, 2025):

- The **Spartan-3 XC3S2000** is from about 2003 and was reported discontinued in 2018. Limited stock was quoted at over €160 per unit.
- The **Xilinx configuration PROMs** are phased out with no direct replacement.
- A re-run was estimated at well over €500 per board.
- **Design files (schematics, Gerbers) and the VHDL source have never been published.** Firmware changes are only possible from Nature.

## Mechanical fit

- The 2012 documents describe extender boards to move the CT60 back, so that stacked boards clear the keyboard. [S001][S012]
- With the **CT60e**, which moves the accelerator forward and out of the keyboard's way, an SV and an EtherNat on top fit in the original Falcon case. MiKRO says he uses this setup daily. [S015]

[S001]: ../../sources/INDEX.md
[S003]: ../../sources/INDEX.md
[S011]: ../../sources/INDEX.md
[S012]: ../../sources/INDEX.md
[S015]: ../../sources/INDEX.md
[S016]: ../../sources/INDEX.md
[S010]: ../../sources/INDEX.md
