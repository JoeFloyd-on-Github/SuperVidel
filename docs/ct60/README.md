# CT60 / CT63 Accelerator

The SuperVidel isn't a stand-alone card. It plugs into the **060 bus slot** of a CT60-family 68060 accelerator, and it depends on that board's bus, memory map, CPLD firmware and TOS. This section documents the CT60 as far as it affects SuperVidel development.

| Page | Contents |
|------|----------|
| [Overview](overview.md) | Features, CPU variants, SDRAM, power, family members, CPLD firmware versions |
| [Memory map and registers](memory-map.md) | 68030 and 68060 views, cache/burst attributes, SDR60/ABE60 registers |
| [060 bus slot](bus-slot.md) | The connector the SV plugs into: signals, pinout, **hardware emulation window**, interrupts, burst timing |
| [Software interface](software.md) | TOS in flash, cookies, CT60 XBIOS calls (`$C60A`–`$C60D`), flash parameters, keyboard shortcuts, JTAG/Flash Tool |

## Coverage and gaps

The main source is the CT60 manual (v1.03c) with Rodolphe Czuba's hardware guide (Rev 5.2, 2004) [S022]. Material on the CPLD updates and CT60 TOS comes from [S019]–[S021].

**Not yet covered by any source:**

- **CT63** and **CT60e**: how they differ from the CT60. S019 says the CT60 CPLD firmware is "compatible with CT63", and S015 says the CT60e moves the board forward, out of the keyboard's way.
- The CT60-100 / CT63 bus clock options beyond the manual's 66/100 MHz.
- The schematics. The manual's block diagram and board images exist only as GEM `.img` files in S021 and haven't been converted yet.

[S015]: ../../sources/INDEX.md
[S019]: ../../sources/INDEX.md
[S021]: ../../sources/INDEX.md
[S022]: ../../sources/INDEX.md
