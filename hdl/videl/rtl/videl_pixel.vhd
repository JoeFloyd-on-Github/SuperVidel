-- videl_pixel.vhd - line buffer pixel to 24-bit RGB, in the pixel clock domain.
--
-- The output scaler asks for one source pixel per cycle: either a graphics
-- pixel (in_x, in_bank) or a border pixel. Colour rules from Hatari's
-- VIDEL_UpdateColors (S035):
--   * ST shifter active: 16-entry STE palette, 12-bit colours
--   * Falcon modes:      256-entry Falcon palette, 6 bits per channel
--   * true colour:       pixel word itself; the border uses Falcon entry 0
--   * borders otherwise: palette entry 0
-- Latency: 3 cycles from in_valid to out_valid.
--
-- SPDX-License-Identifier: GPL-2.0-or-later (derived from Hatari)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.videl_pkg.all;

entity videl_pixel is
  port (
    clk       : in  std_logic;
    bpp_log2  : in  natural range 0 to 4;   -- quasi-static, change only in blanking
    use_st    : in  std_logic;
    st_pal    : in  st_pal_t;
    in_valid  : in  std_logic;
    in_border : in  std_logic;
    in_bank   : in  std_logic;
    in_x      : in  natural range 0 to 2047;
    lb_addr   : out unsigned(11 downto 0);
    lb_rdata  : in  std_logic_vector(15 downto 0);   -- 1-cycle read latency
    pal_addr  : out unsigned(7 downto 0);
    pal_rdata : in  std_logic_vector(31 downto 0);   -- 1-cycle read latency
    out_valid : out std_logic;
    out_rgb   : out std_logic_vector(23 downto 0)
  );
end entity;

architecture rtl of videl_pixel is
  signal v1, v2, b1, tc2 : std_logic := '0';
  signal idx1, idx2 : std_logic_vector(7 downto 0);
  signal word2 : std_logic_vector(15 downto 0);
begin

  lb_addr <= in_bank & to_unsigned(in_x, 11);

  -- palette index from the line buffer output (valid while v1 = '1'),
  -- presented to the palette RAM combinationally
  process (lb_rdata, b1, bpp_log2)
    variable idx : std_logic_vector(7 downto 0);
  begin
    idx := lb_rdata(7 downto 0);
    case bpp_log2 is
      when 0 => idx := "0000000" & idx(0);
      when 1 => idx := "000000" & idx(1 downto 0);
      when 2 => idx := "0000" & idx(3 downto 0);
      when others => null;
    end case;
    if b1 = '1' or bpp_log2 = 4 then
      idx := (others => '0');
    end if;
    idx1 <= idx;
  end process;
  pal_addr <= unsigned(idx1);

  process (clk)
  begin
    if rising_edge(clk) then
      -- cycle 1: line buffer data arrives
      v1 <= in_valid;
      b1 <= in_border;

      -- cycle 2: palette data arrives
      v2    <= v1;
      idx2  <= idx1;
      word2 <= lb_rdata;
      if bpp_log2 = 4 and b1 = '0' then tc2 <= '1'; else tc2 <= '0'; end if;

      -- cycle 3: colour out
      out_valid <= v2;
      if tc2 = '1' then
        out_rgb <= tc_colour(word2);
      elsif use_st = '1' and bpp_log2 /= 4 then
        out_rgb <= st_colour(st_pal(to_integer(unsigned(idx2(3 downto 0)))));
      else
        out_rgb <= falcon_colour(pal_rdata);
      end if;
    end if;
  end process;

end architecture;
