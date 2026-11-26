-- videl_synth_top.vhd - synthesis/timing wrapper for videl_core.
--
-- videl_core is a block inside the SV-Lite FPGA, not a chip top level: its
-- geom record alone is ~120 bits, so with every port on a pin it would not
-- fit the 203 user I/O of the LFE5UM5G-45F caBGA381. This wrapper exists
-- only to get the core through place and route and static timing:
--
--   * every port except geom goes to a pin, through a register, so each
--     pin-to-core and core-to-pin path is a clean register-to-register path
--     and nextpnr reports internal timing, not pad timing;
--   * geom is XOR-folded (videl_pkg.fold_geom) into 8 registered bits. That keeps all of the
--     decode logic alive (a bit nobody reads would be optimised away) at a
--     cost of a few LUTs that the real design will not have.
--
-- Pin count: 2 clocks + 62 bus + 13 line control + 18 memory in
-- + 14 pixel in + 38 memory/line out + 25 pixel out + 8 geom = 180.
--
-- SPDX-License-Identifier: GPL-2.0-or-later

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.videl_pkg.all;

entity videl_synth_top is
  port (
    bus_clk    : in  std_logic;
    pix_clk    : in  std_logic;
    rst        : in  std_logic;
    monitor    : in  std_logic_vector(1 downto 0);
    wr         : in  std_logic;
    addr       : in  std_logic_vector(23 downto 2);
    be         : in  std_logic_vector(3 downto 0);
    wdata      : in  std_logic_vector(31 downto 0);
    geom_fold  : out std_logic_vector(7 downto 0);
    line_start : in  std_logic;
    line_y     : in  std_logic_vector(10 downto 0);
    line_bank  : in  std_logic;
    line_done  : out std_logic;
    mem_req    : out std_logic;
    mem_addr   : out std_logic_vector(23 downto 0);
    mem_words  : out std_logic_vector(10 downto 0);
    mem_ack    : in  std_logic;
    mem_valid  : in  std_logic;
    mem_data   : in  std_logic_vector(15 downto 0);
    mem_ready  : out std_logic;
    in_valid   : in  std_logic;
    in_border  : in  std_logic;
    in_bank    : in  std_logic;
    in_x       : in  std_logic_vector(10 downto 0);
    out_valid  : out std_logic;
    out_rgb    : out std_logic_vector(23 downto 0)
  );
end entity;

architecture rtl of videl_synth_top is
  -- bus_clk side, registered copies
  signal r_rst, r_wr, r_line_start, r_line_bank : std_logic;
  signal r_mem_ack, r_mem_valid : std_logic;
  signal r_monitor : std_logic_vector(1 downto 0);
  signal r_addr    : std_logic_vector(23 downto 2);
  signal r_be      : std_logic_vector(3 downto 0);
  signal r_wdata   : std_logic_vector(31 downto 0);
  signal r_line_y  : std_logic_vector(10 downto 0);
  signal r_mem_data: std_logic_vector(15 downto 0);
  -- pix_clk side
  signal r_in_valid, r_in_border, r_in_bank : std_logic;
  signal r_in_x    : std_logic_vector(10 downto 0);
  -- core outputs
  signal c_geom    : videl_geom_t;
  signal c_line_done, c_mem_req, c_mem_ready, c_out_valid : std_logic;
  signal c_mem_addr: unsigned(23 downto 0);
  signal c_mem_words : natural range 0 to 2047;
  signal c_out_rgb : std_logic_vector(23 downto 0);

begin

  process (bus_clk)
  begin
    if rising_edge(bus_clk) then
      r_rst <= rst; r_wr <= wr; r_monitor <= monitor;
      r_addr <= addr; r_be <= be; r_wdata <= wdata;
      r_line_start <= line_start; r_line_y <= line_y; r_line_bank <= line_bank;
      r_mem_ack <= mem_ack; r_mem_valid <= mem_valid; r_mem_data <= mem_data;
      geom_fold <= fold_geom(c_geom);
      line_done <= c_line_done;
      mem_req   <= c_mem_req;
      mem_addr  <= std_logic_vector(c_mem_addr);
      mem_words <= std_logic_vector(to_unsigned(c_mem_words, 11));
      mem_ready <= c_mem_ready;
    end if;
  end process;

  process (pix_clk)
  begin
    if rising_edge(pix_clk) then
      r_in_valid <= in_valid; r_in_border <= in_border;
      r_in_bank <= in_bank; r_in_x <= in_x;
      out_valid <= c_out_valid;
      out_rgb   <= c_out_rgb;
    end if;
  end process;

  core : entity work.videl_core
    port map (bus_clk => bus_clk, rst => r_rst, monitor => r_monitor,
              wr => r_wr, addr => unsigned(r_addr), be => r_be,
              wdata => r_wdata, geom => c_geom,
              line_start => r_line_start,
              line_y => to_integer(unsigned(r_line_y)),
              line_bank => r_line_bank, line_done => c_line_done,
              mem_req => c_mem_req, mem_addr => c_mem_addr,
              mem_words => c_mem_words, mem_ack => r_mem_ack,
              mem_valid => r_mem_valid, mem_data => r_mem_data,
              mem_ready => c_mem_ready,
              pix_clk => pix_clk, in_valid => r_in_valid,
              in_border => r_in_border, in_bank => r_in_bank,
              in_x => to_integer(unsigned(r_in_x)),
              out_valid => c_out_valid, out_rgb => c_out_rgb);

end architecture;
