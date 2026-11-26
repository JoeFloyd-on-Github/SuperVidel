-- videl_pkg.vhd - types and mode decode for the SV-Lite Videl core.
--
-- The decode rules are a hardware translation of Hatari's Videl emulation
-- (src/falcon/videl.c, commit 36a8acf; SuperVidel docs source S035):
-- VIDEL_getScreenBpp, Videl_GetPixelCyclesAndDivider, VIDEL_getScreenWidth,
-- VIDEL_getScreenHeight and VIDEL_UpdateColors.
--
-- SPDX-License-Identifier: GPL-2.0-or-later
-- (derived from Hatari, which is GPL-2.0-or-later)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package videl_pkg is

  -- $FFFF8006 bits 7:6 (videl.c header comment)
  constant MON_MONO : std_logic_vector(1 downto 0) := "00";
  constant MON_RGB  : std_logic_vector(1 downto 0) := "01";
  constant MON_VGA  : std_logic_vector(1 downto 0) := "10";
  constant MON_TV   : std_logic_vector(1 downto 0) := "11";

  type st_pal_t is array (0 to 15) of std_logic_vector(11 downto 0);

  -- Shadow of the Videl registers the core needs (write-only snoop).
  type videl_regs_t is record
    vbase    : unsigned(23 downto 0);          -- $8201/$8203/$820D
    lof      : unsigned(8 downto 0);           -- $820E, 9 bits
    lwd      : unsigned(9 downto 0);           -- $8210, 10 bits
    st_shift : unsigned(1 downto 0);           -- $8260
    hscroll  : unsigned(3 downto 0);           -- $8265
    spshift  : std_logic_vector(15 downto 0);  -- $8266
    hht      : unsigned(8 downto 0);           -- $8282
    hbb      : unsigned(8 downto 0);           -- $8284
    hbe      : unsigned(8 downto 0);           -- $8286
    hdb      : unsigned(9 downto 0);           -- $8288, bit 9 = start in previous half-line
    hde      : unsigned(8 downto 0);           -- $828A
    vbb      : unsigned(10 downto 0);          -- $82A4
    vbe      : unsigned(10 downto 0);          -- $82A6
    vdb      : unsigned(10 downto 0);          -- $82A8
    vde      : unsigned(10 downto 0);          -- $82AA
    vco      : std_logic_vector(15 downto 0);  -- $82C0
    vmd      : std_logic_vector(15 downto 0);  -- $82C2
    use_st   : std_logic;                      -- last shifter written was $8260
    st_pal   : st_pal_t;                       -- $8240-$825E, 12 bits each
  end record;

  -- Decoded picture geometry (what Hatari passes to ConvGen_Convert).
  type videl_geom_t is record
    bpp_log2 : natural range 0 to 4;       -- 1, 2, 4, 8 or 16 bpp
    xsize    : natural range 0 to 2048;    -- graphics width in pixels
    left     : natural range 0 to 1023;    -- border widths in pixels
    right    : natural range 0 to 1023;
    ysize    : natural range 0 to 2047;    -- graphics height in lines
    upper    : natural range 0 to 2047;    -- border heights in lines
    lower    : natural range 0 to 2047;
    lwd      : natural range 0 to 1023;    -- words fetched per line
    nextline : natural range 0 to 1535;    -- words from line start to line start
    hscroll  : natural range 0 to 15;
    use_st   : std_logic;
    base     : unsigned(23 downto 0);
    drawable : boolean;                    -- Hatari skips screens < 32x32
  end record;

  -- The decode in three pipeline stages (videl_core registers between
  -- them, so the bus-clock path is one stage deep). videl_decode is their
  -- composition, so the combined result cannot drift from the staged one.
  type videl_dec1_t is record
    g        : videl_geom_t;               -- bpp, xsize, lwd, nextline, hscroll, use_st, base
    cyc      : natural range 0 to 2;       -- log2(cycles per pixel)
    horiz    : boolean;                    -- borders shown horizontally
    hdb_off  : natural range 0 to 1023;
    hde_off  : natural range 0 to 1023;
    hdb      : unsigned(9 downto 0);
    hbe, hht : unsigned(8 downto 0);
    hbb, hde : unsigned(8 downto 0);
    ys, ub, lw : natural range 0 to 2047;  -- raw half-line counts
    vmd      : std_logic_vector(1 downto 0);
  end record;

  function decode_s1(r : videl_regs_t; mon : std_logic_vector(1 downto 0);
                     overscan : boolean) return videl_dec1_t;
  function decode_s2(d : videl_dec1_t) return videl_geom_t;
  function decode_s3(g : videl_geom_t) return videl_geom_t;
  function videl_decode(r : videl_regs_t; mon : std_logic_vector(1 downto 0);
                        overscan : boolean) return videl_geom_t;

  -- XOR-fold of the whole geometry record into 8 bits. Not part of the
  -- Videl model: used by syn/videl_synth_top.vhd to bring geom out on few
  -- pins, and by the testbench trace that checks the gate-level netlist.
  function fold_geom(g : videl_geom_t) return std_logic_vector;

  function st_colour(c : std_logic_vector(11 downto 0)) return std_logic_vector;
  function falcon_colour(c : std_logic_vector(31 downto 0)) return std_logic_vector;
  function tc_colour(w : std_logic_vector(15 downto 0)) return std_logic_vector;

end package;

package body videl_pkg is

  function fold_geom(g : videl_geom_t) return std_logic_vector is
    variable v : std_logic_vector(7 downto 0) := (others => '0');
    procedure mix(x : unsigned) is
    begin
      for i in x'range loop
        v(i mod 8) := v(i mod 8) xor x(i);
      end loop;
    end procedure;
  begin
    mix(to_unsigned(g.bpp_log2, 3));
    mix(to_unsigned(g.xsize, 12));
    mix(to_unsigned(g.left, 10));
    mix(to_unsigned(g.right, 10));
    mix(to_unsigned(g.ysize, 11));
    mix(to_unsigned(g.upper, 11));
    mix(to_unsigned(g.lower, 11));
    mix(to_unsigned(g.lwd, 10));
    mix(to_unsigned(g.nextline, 11));
    mix(to_unsigned(g.hscroll, 4));
    mix(g.base);
    v(0) := v(0) xor g.use_st;
    if g.drawable then v(1) := not v(1); end if;
    return v;
  end function;

  -- x * 2**n and x / 2**n for small n, written as constant multiplies and
  -- divides so synthesis turns them into shifts.
  function shl(x : integer; n : natural) return integer is
  begin
    case n is
      when 0 => return x;
      when 1 => return x * 2;
      when 2 => return x * 4;
      when 3 => return x * 8;
      when 4 => return x * 16;
      when 5 => return x * 32;
      when 6 => return x * 64;
      when others => return x * 128;
    end case;
  end function;

  function shr(x : natural; n : natural) return natural is
  begin
    case n is
      when 0 => return x;
      when 1 => return x / 2;
      when 2 => return x / 4;
      when 3 => return x / 8;
      when others => return x / 16;
    end case;
  end function;

  -- Stage 1: mode bits, X size, border offsets, raw vertical differences.
  function decode_s1(r : videl_regs_t; mon : std_logic_vector(1 downto 0);
                     overscan : boolean) return videl_dec1_t is
    variable d   : videl_dec1_t;
    variable bl  : natural range 0 to 4;
    variable cyc : natural range 0 to 2;
    variable dv  : natural range 0 to 4;    -- log2(divider)
    variable vdm : std_logic_vector(1 downto 0);
    variable xs  : natural;
    variable p   : integer;                 -- 128 / bpp
  begin
    -- VIDEL_getScreenBpp: SPSHIFT bits 10 > 8 > 4, else ST shifter.
    if r.spshift(10) = '1' then bl := 0;
    elsif r.spshift(8) = '1' then bl := 4;
    elsif r.spshift(4) = '1' then bl := 3;
    elsif r.use_st = '0' then bl := 2;
    elsif r.st_shift = 0 then bl := 2;
    elsif r.st_shift = 1 then bl := 1;
    else bl := 0;
    end if;
    d.g.bpp_log2 := bl;

    -- Videl_GetPixelCyclesAndDivider
    vdm := r.vmd(3 downto 2);
    if vdm = "00" then cyc := 2; elsif vdm = "01" then cyc := 1; else cyc := 0; end if;
    if mon = MON_VGA then
      if vdm = "00" then dv := 2; else dv := 1; end if;
    elsif r.use_st = '1' then
      dv := 4;
    else
      dv := cyc;
    end if;
    d.cyc := cyc;

    -- X size = LWD * 16 / bpp, halved while above 2048
    xs := shl(to_integer(r.lwd), 4 - bl);
    for i in 1 to 3 loop
      if xs > 2048 then xs := xs / 2; end if;
    end loop;
    d.g.xsize := xs;

    -- Horizontal border offsets (VIDEL_getScreenWidth)
    d.horiz := overscan and mon /= MON_MONO;
    p := shl(1, 7 - bl);
    if r.use_st = '0' then
      if bl < 4 then
        d.hdb_off := shr(64 + shl(p + 18, cyc), dv) + 1;
        d.hde_off := shr(shl(p + 2, cyc), dv);
      else
        d.hdb_off := shr(64 + shl(16, cyc), dv) + 1;
        d.hde_off := 0;
      end if;
    else
      d.hdb_off := shr(128 + shl(p + 2, cyc), dv) + 1;
      d.hde_off := shr(shl(p + 2, cyc), dv);
    end if;
    d.hdb := r.hdb; d.hbe := r.hbe; d.hht := r.hht;
    d.hbb := r.hbb; d.hde := r.hde;

    -- Vertical (VIDEL_getScreenHeight); units are half-lines
    if mon = MON_MONO or not overscan then
      d.ub := 0; d.lw := 0;
    else
      if r.vdb > r.vbe then d.ub := to_integer(r.vdb - r.vbe); else d.ub := 0; end if;
      if r.vbb > r.vde then d.lw := to_integer(r.vbb - r.vde); else d.lw := 0; end if;
    end if;
    if r.vde >= r.vdb then
      d.ys := to_integer(r.vde - r.vdb);
    else
      d.ys := 0;   -- Hatari keeps the previous value here
    end if;
    d.vmd := r.vmd(1 downto 0);

    d.g.lwd      := to_integer(r.lwd);
    d.g.nextline := to_integer(r.lwd) + to_integer(r.lof);
    d.g.hscroll  := to_integer(r.hscroll);
    d.g.use_st   := r.use_st;
    d.g.base     := r.vbase;
    d.g.left := 0; d.g.right := 0;
    d.g.ysize := 0; d.g.upper := 0; d.g.lower := 0;
    d.g.drawable := false;
    return d;
  end function;

  -- Stage 2: border widths and vertical sizes.
  function decode_s2(d : videl_dec1_t) return videl_geom_t is
    variable g      : videl_geom_t := d.g;
    variable lb, rb : integer;
    variable ys, ub, lw : natural range 0 to 2047;
  begin
    if d.horiz then
      lb := to_integer(d.hdb(8 downto 0)) - to_integer(d.hbe) + d.hdb_off;
      if d.hdb(9) = '1' then
        lb := lb - to_integer(d.hht) - 2;
      end if;
      rb := to_integer(d.hbb) - d.hde_off - to_integer(d.hde);
      -- C truncates toward zero, then negative sizes are clamped to 0.
      if lb > 0 then g.left := shr(lb, d.cyc); else g.left := 0; end if;
      if rb > 0 then g.right := shr(rb, d.cyc); else g.right := 0; end if;
    else
      g.left := 0; g.right := 0;
    end if;

    ys := d.ys; ub := d.ub; lw := d.lw;
    if d.vmd(1) = '0' then          -- not set: interlace / half-line units
      ys := ys / 2; ub := ub / 2; lw := lw / 2;
    end if;
    if d.vmd(0) = '1' then          -- line doubling
      ys := ys / 2; ub := ub / 2; lw := lw / 2;
    end if;
    g.ysize := ys; g.upper := ub; g.lower := lw;
    return g;
  end function;

  -- Stage 3: Hatari skips screens smaller than 32 x 32.
  function decode_s3(g : videl_geom_t) return videl_geom_t is
    variable r : videl_geom_t := g;
  begin
    r.drawable := (g.left + g.xsize + g.right >= 32) and
                  (g.upper + g.ysize + g.lower >= 32);
    return r;
  end function;

  function videl_decode(r : videl_regs_t; mon : std_logic_vector(1 downto 0);
                        overscan : boolean) return videl_geom_t is
  begin
    return decode_s3(decode_s2(decode_s1(r, mon, overscan)));
  end function;

  -- STE 12-bit colour: each nibble is (bit3 = LSB, bits 2:0 = upper bits).
  function st_colour(c : std_logic_vector(11 downto 0)) return std_logic_vector is
    variable o : std_logic_vector(23 downto 0);
    variable n : std_logic_vector(3 downto 0);
  begin
    for k in 0 to 2 loop
      n := c(11 - 4 * k downto 8 - 4 * k);
      n := n(2 downto 0) & n(3);
      o(23 - 8 * k downto 16 - 8 * k) := n & n;
    end loop;
    return o;
  end function;

  -- Falcon palette long RRRRRRxx GGGGGGxx -------- BBBBBBxx: 6 bits per
  -- channel, low 2 bits filled from the top 2 (Hatari: c & $FC | c >> 6).
  function falcon_colour(c : std_logic_vector(31 downto 0)) return std_logic_vector is
    variable o : std_logic_vector(23 downto 0);
  begin
    o(23 downto 16) := c(31 downto 26) & c(31 downto 30);
    o(15 downto 8)  := c(23 downto 18) & c(23 downto 22);
    o(7 downto 0)   := c(7 downto 2)   & c(7 downto 6);
    return o;
  end function;

  -- Falcon true colour word, taken as RGB 5:6:5 (bit 5 is also the overlay
  -- bit). The format is not in S035; check against the hardware docs.
  function tc_colour(w : std_logic_vector(15 downto 0)) return std_logic_vector is
    variable o : std_logic_vector(23 downto 0);
  begin
    o(23 downto 16) := w(15 downto 11) & w(15 downto 13);
    o(15 downto 8)  := w(10 downto 5)  & w(10 downto 9);
    o(7 downto 0)   := w(4 downto 0)   & w(4 downto 2);
    return o;
  end function;

end package body;
