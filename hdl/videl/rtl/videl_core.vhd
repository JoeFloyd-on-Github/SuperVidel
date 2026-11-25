-- videl_core.vhd - SV-Lite Videl emulation core (top level).
--
-- Snoops Videl register writes on the CT60 bus, decodes the Falcon video
-- mode the way Hatari does (S035), fetches lines from the ST-RAM shadow and
-- delivers 24-bit RGB pixels to an output scaler. Sync timing (HSS, VFT and
-- so on) is not reproduced: the SV-Lite output pipeline re-times every mode
-- to a standard VGA/HDMI timing (docs/design/videl-compat.md section 3.4).
--
-- Clock domains:
--   bus_clk : CT60 bus clock. Register snoop, mode decode and line fetch.
--   pix_clk : output pixel clock. Pixel read and colour lookup.
-- The decoded geometry crosses into pix_clk without synchronisers. It is
-- quasi-static (changes only on register writes), and the scaler should
-- latch what it needs at the start of each frame.
--
-- SPDX-License-Identifier: GPL-2.0-or-later (derived from Hatari)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.videl_pkg.all;

entity videl_core is
  generic (
    OVERSCAN : boolean := true      -- show borders (Hatari bAllowOverscan)
  );
  port (
    -- CT60 bus side (write snoop)
    bus_clk    : in  std_logic;
    rst        : in  std_logic;
    monitor    : in  std_logic_vector(1 downto 0);
    wr         : in  std_logic;
    addr       : in  unsigned(23 downto 2);
    be         : in  std_logic_vector(3 downto 0);
    wdata      : in  std_logic_vector(31 downto 0);
    geom       : out videl_geom_t;
    -- line fetch control (bus_clk)
    line_start : in  std_logic;
    line_y     : in  natural range 0 to 2047;
    line_bank  : in  std_logic;
    line_done  : out std_logic;
    -- ST-RAM shadow read port (bus_clk)
    mem_req    : out std_logic;
    mem_addr   : out unsigned(23 downto 0);
    mem_words  : out natural range 0 to 2047;
    mem_ack    : in  std_logic;
    mem_valid  : in  std_logic;
    mem_data   : in  std_logic_vector(15 downto 0);
    mem_ready  : out std_logic;
    -- pixel side
    pix_clk    : in  std_logic;
    in_valid   : in  std_logic;
    in_border  : in  std_logic;
    in_bank    : in  std_logic;
    in_x       : in  natural range 0 to 2047;
    out_valid  : out std_logic;
    out_rgb    : out std_logic_vector(23 downto 0)
  );
end entity;

architecture rtl of videl_core is
  signal regs     : videl_regs_t;
  signal g        : videl_geom_t;
  signal pal_we   : std_logic_vector(3 downto 0);
  signal pal_wa   : unsigned(7 downto 0);
  signal pal_wd   : std_logic_vector(31 downto 0);
  signal pal_ra   : unsigned(7 downto 0);
  signal pal_rd   : std_logic_vector(31 downto 0);
  signal lb_we    : std_logic;
  signal lb_wa    : unsigned(11 downto 0);
  signal lb_wd    : std_logic_vector(15 downto 0);
  signal lb_ra    : unsigned(11 downto 0);
  signal lb_rd    : std_logic_vector(15 downto 0);

  type pal8_t is array (0 to 255) of std_logic_vector(7 downto 0);
  type lb_t   is array (0 to 4095) of std_logic_vector(15 downto 0);
  signal pal0, pal1, pal2, pal3 : pal8_t := (others => (others => '0'));
  signal lbuf : lb_t;
begin

  u_regs : entity work.videl_regs
    port map (clk => bus_clk, rst => rst, monitor => monitor, wr => wr,
              addr => addr, be => be, wdata => wdata, regs => regs,
              pal_we => pal_we, pal_addr => pal_wa, pal_data => pal_wd);

  process (bus_clk)
  begin
    if rising_edge(bus_clk) then
      g <= videl_decode(regs, monitor, OVERSCAN);
    end if;
  end process;
  geom <= g;

  u_fetch : entity work.videl_fetch
    port map (clk => bus_clk, rst => rst, geom => g,
              line_start => line_start, line_y => line_y,
              line_bank => line_bank, line_done => line_done,
              mem_req => mem_req, mem_addr => mem_addr, mem_words => mem_words,
              mem_ack => mem_ack, mem_valid => mem_valid, mem_data => mem_data,
              mem_ready => mem_ready,
              lb_we => lb_we, lb_addr => lb_wa, lb_data => lb_wd);

  u_pixel : entity work.videl_pixel
    port map (clk => pix_clk, bpp_log2 => g.bpp_log2, use_st => g.use_st,
              st_pal => regs.st_pal,
              in_valid => in_valid, in_border => in_border, in_bank => in_bank,
              in_x => in_x, lb_addr => lb_ra, lb_rdata => lb_rd,
              pal_addr => pal_ra, pal_rdata => pal_rd,
              out_valid => out_valid, out_rgb => out_rgb);

  -- Falcon palette: 4 byte-wide dual-clock RAMs (byte enables from the bus).
  -- The full 8 bits are kept for SV modes; Videl modes use the top 6.
  process (bus_clk)
  begin
    if rising_edge(bus_clk) then
      if pal_we(3) = '1' then pal3(to_integer(pal_wa)) <= pal_wd(31 downto 24); end if;
      if pal_we(2) = '1' then pal2(to_integer(pal_wa)) <= pal_wd(23 downto 16); end if;
      if pal_we(1) = '1' then pal1(to_integer(pal_wa)) <= pal_wd(15 downto 8);  end if;
      if pal_we(0) = '1' then pal0(to_integer(pal_wa)) <= pal_wd(7 downto 0);   end if;
    end if;
  end process;

  process (pix_clk)
  begin
    if rising_edge(pix_clk) then
      pal_rd <= pal3(to_integer(pal_ra)) & pal2(to_integer(pal_ra)) &
                pal1(to_integer(pal_ra)) & pal0(to_integer(pal_ra));
    end if;
  end process;

  -- Line buffer: 2 banks x 2048 x 16 bit, written in bus_clk, read in pix_clk
  process (bus_clk)
  begin
    if rising_edge(bus_clk) then
      if lb_we = '1' then
        lbuf(to_integer(lb_wa)) <= lb_wd;
      end if;
    end if;
  end process;

  process (pix_clk)
  begin
    if rising_edge(pix_clk) then
      lb_rd <= lbuf(to_integer(lb_ra));
    end if;
  end process;

end architecture;
