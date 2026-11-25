-- videl_regs.vhd - write-snoop shadow of the Falcon Videl registers.
--
-- The CT60 lets a slot card latch a write to a Falcon address without
-- asserting /TA, so the real Videl receives it as well (CT60 manual, S022).
-- This block only latches; the real Videl answers all reads.
--
-- Write side effects follow Hatari's videl.c (S035):
--   * writing $8201 or $8203 clears $820D (VIDEL_ScreenBase_WriteByte)
--   * writing $8260 switches to the ST palette and sets LWD and VMD
--     from the monitor type (VIDEL_ST_ShiftModeWriteByte)
--   * writing $8266 switches back to the Falcon palette
--   * a single-byte write to an ST colour register is copied into both
--     bytes of that register (Videl_ColorReg_WriteWord)
--
-- Bus port: one long-aligned access per wr pulse. addr is the CPU address
-- bits 23:2 (the caller has already decoded A31:24 = $FF). be(3) enables
-- the byte at offset 0, carried on wdata(31:24), as on the 68060 bus.
--
-- SPDX-License-Identifier: GPL-2.0-or-later (derived from Hatari)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.videl_pkg.all;

entity videl_regs is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    monitor  : in  std_logic_vector(1 downto 0);   -- $FFFF8006 bits 7:6
    wr       : in  std_logic;
    addr     : in  unsigned(23 downto 2);
    be       : in  std_logic_vector(3 downto 0);
    wdata    : in  std_logic_vector(31 downto 0);
    regs     : out videl_regs_t;
    -- Falcon palette ($FFFF9800-$FFFF9BFF) write port, to a 256 x 32 RAM
    pal_we   : out std_logic_vector(3 downto 0);
    pal_addr : out unsigned(7 downto 0);
    pal_data : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of videl_regs is
  type bank_t is array (0 to 255) of std_logic_vector(7 downto 0);
  signal bank   : bank_t := (others => (others => '0'));
  signal use_st : std_logic := '0';

  constant BLK_8200 : unsigned(23 downto 8) := x"FF82";
  constant BLK_9800 : unsigned(23 downto 10) := to_unsigned(16#FF98# / 4, 14);
begin

  process (clk)
    variable b        : bank_t;
    variable off      : natural range 0 to 255;
    variable nbytes   : natural range 0 to 4;
    variable wrote    : std_logic_vector(255 downto 0);
    variable st       : std_logic_vector(1 downto 0);
    variable lwd, vmd : std_logic_vector(15 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        bank   <= (others => (others => '0'));
        use_st <= '0';
      elsif wr = '1' and addr(23 downto 8) = BLK_8200 then
        b := bank;
        wrote := (others => '0');
        nbytes := 0;
        for i in 0 to 3 loop
          if be(3 - i) = '1' then nbytes := nbytes + 1; end if;
        end loop;

        for i in 0 to 3 loop
          if be(3 - i) = '1' then
            off := to_integer(addr(7 downto 2)) * 4 + i;
            b(off) := wdata(31 - 8 * i downto 24 - 8 * i);
            wrote(off) := '1';
            -- ST colour registers: a lone byte goes to both bytes
            if off >= 16#40# and off < 16#60# and nbytes = 1 then
              if off mod 2 = 0 then
                b(off + 1) := wdata(31 - 8 * i downto 24 - 8 * i);
              else
                b(off - 1) := wdata(31 - 8 * i downto 24 - 8 * i);
              end if;
            end if;
          end if;
        end loop;

        -- Base hi or mid written (without lo): clear lo
        if (wrote(16#01#) = '1' or wrote(16#03#) = '1') and wrote(16#0D#) = '0' then
          b(16#0D#) := (others => '0');
        end if;

        -- ST shift mode
        if wrote(16#60#) = '1' then
          st := b(16#60#)(1 downto 0);
          b(16#60#) := "000000" & st;
          case st is
            when "00" =>
              lwd := x"0050";
              if monitor = MON_VGA then vmd := x"0005"; else vmd := x"0000"; end if;
            when "01" =>
              lwd := x"0050";
              if monitor = MON_VGA then vmd := x"0009"; else vmd := x"0004"; end if;
            when "10" =>
              lwd := x"0028";
              if monitor = MON_MONO then vmd := x"0000";
              elsif monitor = MON_VGA then vmd := x"0008";
              else vmd := x"0006"; end if;
            when others =>
              lwd := x"0050"; vmd := x"0000";
          end case;
          b(16#10#) := lwd(15 downto 8); b(16#11#) := lwd(7 downto 0);
          b(16#C2#) := vmd(15 downto 8); b(16#C3#) := vmd(7 downto 0);
          use_st <= '1';
        elsif wrote(16#66#) = '1' or wrote(16#67#) = '1' then
          use_st <= '0';
        end if;

        bank <= b;
      end if;
    end if;
  end process;

  -- Falcon palette: pass the write straight to the palette RAM
  pal_addr <= addr(9 downto 2);
  pal_data <= wdata;
  pal_we   <= be when wr = '1' and addr(23 downto 10) = BLK_9800 else "0000";

  -- Field view of the shadow
  process (bank, use_st)
    function w(hi, lo : std_logic_vector(7 downto 0)) return std_logic_vector is
      variable v : std_logic_vector(15 downto 0);
    begin
      v := hi & lo;
      return v;
    end function;
    variable r : videl_regs_t;
    variable base24 : std_logic_vector(23 downto 0);
  begin
    base24     := w(bank(16#01#), bank(16#03#)) & bank(16#0D#);
    r.vbase    := unsigned(base24);
    r.lof      := unsigned(w(bank(16#0E#), bank(16#0F#))(8 downto 0));
    r.lwd      := unsigned(w(bank(16#10#), bank(16#11#))(9 downto 0));
    r.st_shift := unsigned(bank(16#60#)(1 downto 0));
    r.hscroll  := unsigned(bank(16#65#)(3 downto 0));
    r.spshift  := w(bank(16#66#), bank(16#67#));
    r.hht      := unsigned(w(bank(16#82#), bank(16#83#))(8 downto 0));
    r.hbb      := unsigned(w(bank(16#84#), bank(16#85#))(8 downto 0));
    r.hbe      := unsigned(w(bank(16#86#), bank(16#87#))(8 downto 0));
    r.hdb      := unsigned(w(bank(16#88#), bank(16#89#))(9 downto 0));
    r.hde      := unsigned(w(bank(16#8A#), bank(16#8B#))(8 downto 0));
    r.vbb      := unsigned(w(bank(16#A4#), bank(16#A5#))(10 downto 0));
    r.vbe      := unsigned(w(bank(16#A6#), bank(16#A7#))(10 downto 0));
    r.vdb      := unsigned(w(bank(16#A8#), bank(16#A9#))(10 downto 0));
    r.vde      := unsigned(w(bank(16#AA#), bank(16#AB#))(10 downto 0));
    r.vco      := w(bank(16#C0#), bank(16#C1#));
    r.vmd      := w(bank(16#C2#), bank(16#C3#));
    r.use_st   := use_st;
    for i in 0 to 15 loop
      r.st_pal(i) := w(bank(16#40# + 2 * i), bank(16#41# + 2 * i))(11 downto 0);
    end loop;
    regs <= r;
  end process;

end architecture;
