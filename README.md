# SuperVidel Documentation

Technical documentation for the **SuperVidel**, a graphics card add-on for the Atari Falcon030 (used with CT60/CT63 accelerators).

**Audience:** hardware and software developers. The aim is to describe how the card works and how to program it: hardware architecture, registers, memory map, drivers, firmware and programming interfaces.

## Repository layout

| Path | Contents |
|------|----------|
| [`docs/`](docs/) | Documentation written for this project |
| [`docs/hardware/`](docs/hardware/) | Architecture, bus interface, memory map, registers, video timing, connectors |
| [`docs/software/`](docs/software/) | Drivers, firmware, configuration and OS integration |
| [`docs/programming/`](docs/programming/) | Programming guides and example code |
| [`docs/ct60/`](docs/ct60/) | The CT60/CT63 host accelerator: memory map, 060 bus slot, hardware emulation window, XBIOS |
| [`sources/`](sources/) | Original source material, kept as received ([index](sources/INDEX.md)) |
| [`tools/`](tools/) | Scripts used to extract or analyse source material |

## Sources

Material is added as it's found. Each item goes in `sources/` unchanged and gets an entry in [`sources/INDEX.md`](sources/INDEX.md) recording where it came from. The pages in `docs/` cite these entries by ID.

## Status

Gathering sources. Hardware register reference and driver overview drafted from the 2012 Nature documents and a 2026 article (S001–S013).
