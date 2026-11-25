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

  function videl_decode(r : videl_regs_t; mon : std_logic_vector(1 downto 0);
                        overscan : boolean) return videl_geom_t;

  function st_colour(c : std_logic_vector(11 downto 0)) return std_logic_vector;
  function falcon_colour(c : std_logic_vector(31 downto 0)) return std_logic_vector;
  function tc_colour(w : std_logic_vector(15 downto 0)) return std_logic_vector;

end package;

package body videl_pkg is

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

  function videl_decode(r : videl_regs_t; mon : std_logic_vector(1 downto 0);
                        overscan : boolean) return videl_geom_t is
    variable g       : videl_geom_t;
    variable bl      : natural range 0 to 4;
    variable cyc     : natural range 0 to 2;    -- log2(cycles per pixel)
    variable dv      : natural range 0 to 4;    -- log2(divider)
    variable vdm     : std_logic_vector(1 downto 0);
    variable xs      : natural;
    variable p       : integer;                 -- 128 / bpp
    variable hdb_off : integer;
    variable hde_off : integer;
    variable lb, rb  : integer;
    variable ub, lw  : integer;
    variable ys      : integer;
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
    g.bpp_log2 := bl;

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

    -- X size = LWD * 16 / bpp, halved while above 2048
    xs := shl(to_integer(r.lwd), 4 - bl);
    for i in 1 to 3 loop
      if xs > 2048 then xs := xs / 2; end if;
    end loop;
    g.xsize := xs;

    -- Horizontal borders (VIDEL_getScreenWidth)
    if (not overscan) or mon = MON_MONO then
      g.left := 0; g.right := 0;
    else
      p := shl(1, 7 - bl);
      if r.use_st = '0' then
        if bl < 4 then
          hdb_off := shr(64 + shl(p + 18, cyc), dv) + 1;
          hde_off := shr(shl(p + 2, cyc), dv);
        else
          hdb_off := shr(64 + shl(16, cyc), dv) + 1;
          hde_off := 0;
        end if;
      else
        hdb_off := shr(128 + shl(p + 2, cyc), dv) + 1;
        hde_off := shr(shl(p + 2, cyc), dv);
      end if;
      lb := to_integer(r.hdb(8 downto 0)) - to_integer(r.hbe) + hdb_off;
      if r.hdb(9) = '1' then
        lb := lb - to_integer(r.hht) - 2;
      end if;
      rb := to_integer(r.hbb) - hde_off - to_integer(r.hde);
      -- C truncates toward zero, then negative sizes are clamped to 0.
      if lb > 0 then g.left := shr(lb, cyc); else g.left := 0; end if;
      if rb > 0 then g.right := shr(rb, cyc); else g.right := 0; end if;
    end if;

    -- Vertical (VIDEL_getScreenHeight); units are half-lines
    if mon = MON_MONO or not overscan then
      ub := 0; lw := 0;
    else
      ub := to_integer(r.vdb) - to_integer(r.vbe);
      lw := to_integer(r.vbb) - to_integer(r.vde);
      if ub < 0 then ub := 0; end if;
      if lw < 0 then lw := 0; end if;
    end if;
    if r.vde >= r.vdb then
      ys := to_integer(r.vde) - to_integer(r.vdb);
    else
      ys := 0;   -- Hatari keeps the previous value here
    end if;
    if r.vmd(1) = '0' then          -- not set: interlace / half-line units
      ys := ys / 2; ub := ub / 2; lw := lw / 2;
    end if;
    if r.vmd(0) = '1' then          -- line doubling
      ys := ys / 2; ub := ub / 2; lw := lw / 2;
    end if;
    g.ysize := ys; g.upper := ub; g.lower := lw;

    g.lwd      := to_integer(r.lwd);
    g.nextline := to_integer(r.lwd) + to_integer(r.lof);
    g.hscroll  := to_integer(r.hscroll);
    g.use_st   := r.use_st;
    g.base     := r.vbase;
    g.drawable := (g.left + g.xsize + g.right >= 32) and (ub + ys + lw >= 32);
    return g;
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
