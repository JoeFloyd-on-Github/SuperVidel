-- tb_videl_core.vhd - checks videl_core against Hatari's videl.c.
--
-- Replays tools/videl_ref/vectors.txt (register writes) into the core and
-- compares the result with tools/videl_ref/expected.txt, which the golden
-- model (Hatari's own videl.c, S035) produced from the same vectors:
--   * decoded geometry (bpp, sizes, borders, line stride, h-scroll, base)
--   * fetch address of line 1
--   * colours of the first 16 pixels of a fetched line and of the border
--
-- SPDX-License-Identifier: GPL-2.0-or-later

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.videl_pkg.all;

entity tb_videl_core is
  generic (
    VECTORS  : string := "../../tools/videl_ref/vectors.txt";
    EXPECTED : string := "../../tools/videl_ref/expected.txt"
  );
end entity;

architecture sim of tb_videl_core is
  signal clk       : std_logic := '0';
  signal rst       : std_logic := '1';
  signal monitor   : std_logic_vector(1 downto 0) := MON_VGA;
  signal wr        : std_logic := '0';
  signal addr      : unsigned(23 downto 2) := (others => '0');
  signal be        : std_logic_vector(3 downto 0) := "0000";
  signal wdata     : std_logic_vector(31 downto 0) := (others => '0');
  signal geom      : videl_geom_t;
  signal line_start: std_logic := '0';
  signal line_y    : natural range 0 to 2047 := 0;
  signal line_bank : std_logic := '0';
  signal line_done : std_logic;
  signal mem_req   : std_logic;
  signal mem_addr  : unsigned(23 downto 0);
  signal mem_words : natural range 0 to 2047;
  signal mem_ack   : std_logic := '0';
  signal mem_valid : std_logic := '0';
  signal mem_data  : std_logic_vector(15 downto 0) := (others => '0');
  signal mem_ready : std_logic;
  signal in_valid  : std_logic := '0';
  signal in_border : std_logic := '0';
  signal in_bank   : std_logic := '0';
  signal in_x      : natural range 0 to 2047 := 0;
  signal out_valid : std_logic;
  signal out_rgb   : std_logic_vector(23 downto 0);
  signal done      : boolean := false;

  -- test pattern: word n of a line. For bit-plane modes, pixel j of every
  -- 16-pixel group gets palette index j; true colour words are just n.
  function pattern(n : natural; bl : natural) return std_logic_vector is
    variable w : std_logic_vector(15 downto 0) := (others => '0');
    variable planes, p : natural;
  begin
    if bl = 4 then
      return std_logic_vector(to_unsigned(n mod 65536, 16));
    end if;
    planes := 2 ** bl;
    p := n mod planes;
    for j in 0 to 15 loop
      if to_unsigned(j, 8)(p) = '1' then
        w(15 - j) := '1';
      end if;
    end loop;
    return w;
  end function;

  -- hex text of up to 8 digits to a 32-bit vector
  function hex(t : string) return std_logic_vector is
    variable r : unsigned(31 downto 0) := (others => '0');
    variable d : natural;
  begin
    for i in t'range loop
      case t(i) is
        when '0' to '9' => d := character'pos(t(i)) - character'pos('0');
        when 'a' to 'f' => d := character'pos(t(i)) - character'pos('a') + 10;
        when 'A' to 'F' => d := character'pos(t(i)) - character'pos('A') + 10;
        when others => d := 0;
      end case;
      r := shift_left(r, 4) + d;
    end loop;
    return std_logic_vector(r);
  end function;
begin

  clk <= not clk after 5 ns when not done;

  dut : entity work.videl_core
    port map (bus_clk => clk, rst => rst, monitor => monitor, wr => wr,
              addr => addr, be => be, wdata => wdata, geom => geom,
              line_start => line_start, line_y => line_y,
              line_bank => line_bank, line_done => line_done,
              mem_req => mem_req, mem_addr => mem_addr, mem_words => mem_words,
              mem_ack => mem_ack, mem_valid => mem_valid, mem_data => mem_data,
              mem_ready => mem_ready,
              pix_clk => clk, in_valid => in_valid, in_border => in_border,
              in_bank => in_bank, in_x => in_x,
              out_valid => out_valid, out_rgb => out_rgb);

  -- ST-RAM shadow model: accept a request, then stream the pattern
  mem : process
    variable n, cnt : natural;
  begin
    wait until rising_edge(clk);
    if mem_req = '1' then
      mem_ack <= '1';
      cnt := mem_words;
      wait until rising_edge(clk);
      mem_ack <= '0';
      n := 0;
      while n < cnt loop
        mem_valid <= '1';
        mem_data  <= pattern(n, geom.bpp_log2);
        wait until rising_edge(clk);
        if mem_ready = '1' then
          n := n + 1;
        end if;
      end loop;
      mem_valid <= '0';
    end if;
  end process;

  stim : process
    file fv, fe     : text;
    variable lv, le : line;
    variable tok    : string(1 to 64);
    variable tlen   : natural;
    variable c      : character;
    variable ok     : boolean;
    variable a, v   : std_logic_vector(23 downto 0);
    variable v32    : std_logic_vector(31 downto 0);
    variable size   : character;
    variable off    : natural;
    variable name   : string(1 to 64);
    variable nlen   : natural;
    variable e_bpp, e_xs, e_l, e_r, e_ys, e_u, e_lo, e_nl, e_hs, e_st : integer;
    variable e_base : std_logic_vector(23 downto 0);
    type pal_t is array (0 to 15) of std_logic_vector(23 downto 0);
    variable e_pal  : pal_t;
    variable errors, tests : natural := 0;
    variable mask   : natural;
    variable exp_rgb: std_logic_vector(23 downto 0);
    variable want   : unsigned(23 downto 0);

    procedure read_word(l : inout line; s : out string; n : out natural) is
      variable ch : character;
      variable good : boolean;
      variable k : natural := 0;
    begin
      for i in s'range loop s(i) := ' '; end loop;
      loop
        exit when l'length = 0;
        exit when l(l'left) /= ' ' and l(l'left) /= HT;
        read(l, ch);
      end loop;
      loop
        exit when l'length = 0;
        exit when l(l'left) = ' ' or l(l'left) = HT;
        read(l, ch, good);
        k := k + 1;
        s(k) := ch;
      end loop;
      n := k;
    end procedure;

    procedure check(what : string; got, expd : integer) is
    begin
      if got /= expd then
        report name(1 to nlen) & ": " & what & " = " & integer'image(got) &
               ", Hatari " & integer'image(expd) severity error;
        errors := errors + 1;
      end if;
    end procedure;

    procedure check_rgb(what : string; got, expd : std_logic_vector(23 downto 0)) is
    begin
      if got /= expd then
        report name(1 to nlen) & ": " & what & " = " & to_hstring(got) &
               ", Hatari " & to_hstring(expd) severity error;
        errors := errors + 1;
      end if;
    end procedure;

    procedure pixel(x : natural; border : std_logic; rgb : out std_logic_vector(23 downto 0)) is
    begin
      in_valid  <= '1';
      in_border <= border;
      in_bank   <= '0';
      in_x      <= x;
      wait until rising_edge(clk);
      in_valid  <= '0';
      wait until rising_edge(clk) and out_valid = '1';
      rgb := out_rgb;
    end procedure;
  begin
    file_open(fv, VECTORS, read_mode);
    file_open(fe, EXPECTED, read_mode);
    while not endfile(fv) loop
      readline(fv, lv);
      read_word(lv, tok, tlen);
      if tlen = 0 or tok(1) = '#' then
        next;
      elsif tok(1 to tlen) = "test" then
        read_word(lv, name, nlen);
        read_word(lv, tok, tlen);
        if    tok(1 to tlen) = "mono" then monitor <= MON_MONO;
        elsif tok(1 to tlen) = "rgb"  then monitor <= MON_RGB;
        elsif tok(1 to tlen) = "vga"  then monitor <= MON_VGA;
        else monitor <= MON_TV; end if;
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        rst <= '0';
        -- the palette RAM has no reset: clear the 16 entries the test reads
        for i in 0 to 15 loop
          addr  <= to_unsigned(16#FF9800# / 4 + i, 22);
          be    <= "1111";
          wdata <= (others => '0');
          wr    <= '1';
          wait until rising_edge(clk);
        end loop;
        wr <= '0';
      elsif tok(1 to tlen) = "w" then
        read_word(lv, tok, tlen);
        a := hex(tok(1 to tlen))(23 downto 0);
        read_word(lv, tok, tlen);
        size := tok(1);
        read_word(lv, tok, tlen);
        v32 := hex(tok(1 to tlen));
        off := to_integer(unsigned(a(1 downto 0)));
        addr <= unsigned(a(23 downto 2));
        case size is
          when 'b' =>
            be <= (others => '0');
            be(3 - off) <= '1';
            wdata <= (others => '0');
            wdata(31 - 8 * off downto 24 - 8 * off) <= v32(7 downto 0);
          when 'w' =>
            if off = 0 then
              be <= "1100"; wdata <= v32(15 downto 0) & x"0000";
            else
              be <= "0011"; wdata <= x"0000" & v32(15 downto 0);
            end if;
          when others =>
            be <= "1111"; wdata <= v32;
        end case;
        wr <= '1';
        wait until rising_edge(clk);
        wr <= '0';
      elsif tok(1 to tlen) = "end" then
        tests := tests + 1;
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        -- expected line
        readline(fe, le);
        read_word(le, tok, tlen);
        read(le, e_bpp); read(le, e_xs); read(le, e_l); read(le, e_r);
        read(le, e_ys); read(le, e_u); read(le, e_lo); read(le, e_nl);
        read(le, e_hs); read(le, e_st);
        hread(le, e_base);
        for i in 0 to 15 loop
          hread(le, e_pal(i));
        end loop;

        check("bpp",      2 ** geom.bpp_log2, e_bpp);
        check("xsize",    geom.xsize, e_xs);
        check("left",     geom.left, e_l);
        check("right",    geom.right, e_r);
        check("ysize",    geom.ysize, e_ys);
        check("upper",    geom.upper, e_u);
        check("lower",    geom.lower, e_lo);
        check("nextline", geom.nextline, e_nl);
        check("hscroll",  geom.hscroll, e_hs);
        if geom.use_st = '1' then check("use_st", 1, e_st); else check("use_st", 0, e_st); end if;
        check("base",     to_integer(geom.base), to_integer(unsigned(e_base)));

        -- border colour = palette entry 0
        pixel(0, '1', exp_rgb);
        check_rgb("border", exp_rgb, e_pal(0));

        -- fetch source line 1 and check the address
        line_y <= 1;
        line_bank <= '0';
        line_start <= '1';
        wait until rising_edge(clk);
        line_start <= '0';
        if geom.lwd > 0 then
          wait until rising_edge(clk) and mem_req = '1';
          want := unsigned(e_base) + to_unsigned(e_nl * 2, 24);
          check("line 1 address", to_integer(mem_addr), to_integer(want));
        end if;
        wait until rising_edge(clk) and line_done = '1';

        -- first 16 pixels of the line (bit-plane modes)
        if geom.bpp_log2 < 4 then
          mask := 2 ** (2 ** geom.bpp_log2) - 1;
          for x in 0 to 15 loop
            if x < geom.xsize then
              pixel(x, '0', exp_rgb);
              check_rgb("pixel " & integer'image(x), exp_rgb,
                        e_pal(((x + e_hs) mod 16) mod (mask + 1)));
            end if;
          end loop;
        end if;
      end if;
    end loop;

    report integer'image(tests) & " tests, " & integer'image(errors) & " errors"
      severity note;
    assert errors = 0 report "FAILED" severity failure;
    report "PASSED" severity note;
    done <= true;
    wait;
  end process;

end architecture;
