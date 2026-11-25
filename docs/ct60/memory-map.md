# CT60 Memory Map and Registers

> Source: CT60 hardware guide, Rev 5.2 [S022], plus CT60 TOS source [S021].

## 68030 view (Falcon mode, 24-bit)

| Range | Size | Contents |
|-------|------|----------|
| `$xx000000`–`$xxDFFFFF` | 14 MB | ST-RAM |
| `$xxE00000`–`$xxEFFFFF` | 1 MB | TOS 4.0x ROM (boot) / CT60 flash in **CPU space #3** |
| `$xxF00000`–`$xxF0FFFF` | 64 KB | IDE I/O |
| `$xxF10000`–`$xxF9FFFF` | 576 KB | Falcon bus slot |
| `$xxFA0000`–`$xxFBFFFF` | 128 KB | Cartridge slot |
| `$xxFC0000`–`$xxFEFFFF` | 192 KB | Unused |
| `$xxFF0000`–`$xxFFFFFF` | 64 KB | I/O |

From the 030 the flash is read and programmed through CPU space #3. [S022]

## 68060 view (32-bit)

| Range | Size | Contents | Cache / burst |
|-------|------|----------|---------------|
| `$00000000`–`$00DFFFFF` | 14 MB | ST-RAM | cache, no burst |
| `$00E00000`–`$00EFFFFF` | 1 MB | CT60 flash (TOS) | cache, no burst |
| `$00F00000`–`$00F0FFFF` | 64 KB | IDE I/O | no cache, no burst |
| `$00F10000`–`$00F9FFFF` | 576 KB | Falcon bus slot | no cache, no burst |
| `$00FA0000`–`$00FBFFFF` | 128 KB | Cartridge slot | no cache, no burst |
| `$00FC0000`–`$00FEFFFF` | 192 KB | Unused | no cache, no burst |
| `$00FF0000`–`$00FFFFFF` | 64 KB | I/O | no cache, no burst |
| `$01000000`–`$20FFFFFF` | 512 MB | SDRAM ("TT-RAM") | **cache, burst** |
| `$21000000`–`$3FFFFFFF` | 496 MB | Reserved | cache, burst |
| `$40000000`–`$7FFFFFFF` | 1 GB | **060 bus slot**, cacheable window | **cache, burst** |
| `$80000000`–`$BFFFFFFF` | 1 GB | **060 bus slot**, non-cacheable window | no cache, no burst |
| `$C0000000`–`$EFFFFFFF` | 768 MB | Reserved | no cache, no burst |
| `$F0000000`–`$FBFFFFFF` | 192 MB | CT60 I/O (CPLD registers) | no cache, no burst |
| `$FC000000`–`$FEFFFFFF` | 48 MB | Reserved | no cache, no burst |
| `$FF000000`–`$FFFFFFFF` | 16 MB | Falcon 24-bit shadow (e.g. Videl at `$FFFF8200`) | no cache, no burst |

- From the 060 the TOS ROM chip is **not** accessible. The flash appears at the TOS addresses at boot. To program the flash from the 060, use **alternate space #3**. [S022]
- The flash TOS sets up the 060's transparent translation registers: `$00000000`–`$7FFFFFFF` copyback (except `$0`–`$FFFFFF`, which is writethrough) and `$80000000`–`$FFFFFFFF` cache-inhibited. [S022] The CT60 TOS source gives the value as **DTT0/ITT0 = `$807FE040`** and relies on accesses above `$80000000` being precise, so that an absent device raises a synchronous bus error. [S021]

### Where the SuperVidel sits

The SV's addresses (see [../hardware/memory-map.md](../hardware/memory-map.md)) are all in the CT60's **non-cacheable 060 bus slot window**:

| SV range | CT60 region |
|----------|-------------|
| `$80010000`–`$80013FFF` (registers, Ethernet MAC) | 060 bus slot, no cache / no burst |
| `$A0000000`–`$A7FFFFFF` (DDR2: ST-RAM shadow + graphics RAM) | 060 bus slot, no cache / no burst |
| `$FFFF8200…` (emulated Videl), `$FFFF9800` (palette) | Falcon 24-bit shadow, via the [hardware emulation window](bus-slot.md#hardware-emulation-window) |

The CT60 also defines a **cacheable, burst-capable** slot window at `$40000000`–`$7FFFFFFF`. Whether the SV decodes its RAM there too isn't documented. The `pmmu_boost` option of the SV drivers ("higher CPU↔VRAM bandwidth") presumably changes the 060's cache mode for VRAM through the PMMU. **(inferred)** The CT60 CPLD changelog adds that move16 bursts work on all expansion-slot addresses from the release after V5M/V5E. [S019]

## CPLD registers

All are in the CT60 I/O area and are accessed from the 060. Several are "address-encoded": the value written is chosen by which address you write to. [S022]

### SDR60

| Register | Address | Function |
|----------|---------|----------|
| EECL | write `$F0000000` → 0, write `$F0400000` → 1; read `$F0000000` → bit D1 | DIMM EEPROM I²C clock |
| EEDA | write `$F0800000` → 0, write `$F0C00000` → 1; read `$F0000000` → bit D0 | DIMM EEPROM I²C data |
| THCS | long write `$F1000000` → CS inactive (0), `$F1400000` → CS active (1) | 060 thermal ADC chip select |
| THCK | long write `$F1800000` → 0, `$F1C00000` → 1 | Thermal ADC clock |
| THDA | long read `$F1000000` → bit D0 | Thermal ADC data out |
| SDCNF | long write to `$F2xx0000`, where xx = A23..A16 encodes the config | SDRAM configuration (below) |
| IVR | read `$F3000000` | Level of the pending interrupt (see [bus-slot.md](bus-slot.md#interrupts)) |

**SDCNF address bits:** A23:A22 = chip density (`00` 8M×8/8M×16, `01` 16M×8, `10` 16M×16, `11` 32M×8/32M×16); A20 = DIMM banks (0 = 1, 1 = 2); A19:A18 = module density (`00` 64 MB, `01` 128 MB, `10` 256 MB, `11` 512 MB); A16 = refresh (0 = 15.625 µs, 1 = 7.8125 µs). The values come from the DIMM's SPD EEPROM bytes 3, 4, 5, 12 and 31. [S022]

### ABE60

| Register | Address | Function |
|----------|---------|----------|
| FWEN | write `$F9000000` → enable, `$F9800000` → disable | Flash write enable. Needed only for PowerPC writes; not needed for 030/060 writes |
| SLP | write `$FA800000` | Turn off the ATX power supply |

### Thermal sensor

The 68060's on-die sensor (THERM0/THERM1) is a resistor of about 780 Ω at 25 °C, rising by 2.8 Ω/°C: R = 780 + 2.8 × (T − 25). The CT60 reads it with a TI **TLV0831** 8-bit serial ADC (1.8 V reference, about 7 mV/step) in a 1 kΩ divider from 3.34 V. Software bit-bangs the ADC through THCS/THCK/THDA at 10–600 kHz, with CS setup ≥ 350 ns and 32 µs conversion at 250 kHz. Readings: 0 °C → 197, 25 °C → 208, 50 °C → 218, 100 °C → 236, which is **not linear**. The flash TOS wraps this in XBIOS `$C60A` (see [software.md](software.md)). [S022]

[S019]: ../../sources/INDEX.md
[S021]: ../../sources/INDEX.md
[S022]: ../../sources/INDEX.md
