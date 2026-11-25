-- videl_fetch.vhd - fetch one Videl line and convert it to chunky pixels.
--
-- On line_start, reads the source line line_y from the ST-RAM shadow:
--   address = base + line_y * nextline * 2 (nextline = LWD + LOF words)
--   words   = LWD, plus one 16-pixel group when h-scroll is non-zero
-- Bit-plane data (1/2/4/8 bpp, interleaved words as on the Falcon) is
-- converted to one palette index per pixel. True colour words are stored
-- unchanged. Pixels are written to a line buffer of 2 banks x 2048 x 16 bit,
-- skipping the first hscroll pixels (as Hatari passes hscrolloffset to its
-- converter, S035).
--
-- Memory port: a request (mem_req/mem_addr/mem_words, held until mem_ack)
-- followed by a stream of 16-bit words with valid/ready handshaking.
--
-- SPDX-License-Identifier: GPL-2.0-or-later (derived from Hatari)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.videl_pkg.all;

entity videl_fetch is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    geom       : in  videl_geom_t;
    line_start : in  std_logic;
    line_y     : in  natural range 0 to 2047;
    line_bank  : in  std_logic;
    line_done  : out std_logic;
    mem_req    : out std_logic;
    mem_addr   : out unsigned(23 downto 0);
    mem_words  : out natural range 0 to 2047;
    mem_ack    : in  std_logic;
    mem_valid  : in  std_logic;
    mem_data   : in  std_logic_vector(15 downto 0);
    mem_ready  : out std_logic;
    lb_we      : out std_logic;
    lb_addr    : out unsigned(11 downto 0);
    lb_data    : out std_logic_vector(15 downto 0)
  );
end entity;

architecture rtl of videl_fetch is
  type state_t is (IDLE, REQ, COLLECT, EMIT);
  signal state   : state_t := IDLE;
  type planes_t is array (0 to 7) of std_logic_vector(15 downto 0);
  signal planes  : planes_t;
  signal plane_n : natural range 0 to 7;
  signal pix_j   : natural range 0 to 15;
  signal words_left : natural range 0 to 2047;
  signal pc      : natural range 0 to 32767;    -- source pixel counter
  signal bank    : std_logic;
  signal g       : videl_geom_t;                -- geometry latched per line

  function nplanes(bl : natural) return natural is
  begin
    case bl is
      when 0 => return 1;
      when 1 => return 2;
      when 2 => return 4;
      when others => return 8;
    end case;
  end function;

  -- words in one 16-pixel group = bpp
  function group_words(bl : natural) return natural is
  begin
    if bl = 4 then return 16; else return nplanes(bl); end if;
  end function;
begin

  mem_ready <= '1' when state = COLLECT else '0';

  process (clk)
    variable total  : natural;
    variable idx    : std_logic_vector(7 downto 0);
    variable x      : integer;
    variable last   : boolean;
  begin
    if rising_edge(clk) then
      lb_we     <= '0';
      line_done <= '0';
      if rst = '1' then
        state   <= IDLE;
        mem_req <= '0';
      else
        case state is
          when IDLE =>
            if line_start = '1' then
              g    <= geom;
              bank <= line_bank;
              -- words to read: LWD, plus one 16-pixel group for h-scroll
              total := geom.lwd;
              if geom.hscroll /= 0 then
                total := total + group_words(geom.bpp_log2);
              end if;
              mem_addr  <= geom.base + to_unsigned(line_y * geom.nextline * 2, 24);
              mem_words <= total;
              words_left <= total;
              mem_req   <= '1';
              pc        <= 0;
              plane_n   <= 0;
              if total = 0 then
                mem_req   <= '0';
                line_done <= '1';
              else
                state <= REQ;
              end if;
            end if;

          when REQ =>
            if mem_ack = '1' then
              mem_req <= '0';
              state   <= COLLECT;
            end if;

          when COLLECT =>
            if mem_valid = '1' then
              words_left <= words_left - 1;
              if g.bpp_log2 = 4 then
                -- true colour: one word per pixel
                x := pc - g.hscroll;
                if x >= 0 and x < g.xsize then
                  lb_we   <= '1';
                  lb_addr <= bank & to_unsigned(x, 11);
                  lb_data <= mem_data;
                end if;
                pc <= pc + 1;
                if words_left = 1 then
                  state     <= IDLE;
                  line_done <= '1';
                end if;
              else
                planes(plane_n) <= mem_data;
                -- a short last group (LWD not a multiple of bpp) is emitted as is
                if plane_n = nplanes(g.bpp_log2) - 1 or words_left = 1 then
                  plane_n <= 0;
                  pix_j   <= 0;
                  state   <= EMIT;
                else
                  plane_n <= plane_n + 1;
                end if;
              end if;
            end if;

          when EMIT =>
            -- pixel j of the group: bit (15 - j) of each plane word
            idx := (others => '0');
            for p in 0 to 7 loop
              if p < nplanes(g.bpp_log2) then
                idx(p) := planes(p)(15 - pix_j);
              end if;
            end loop;
            x := pc - g.hscroll;
            if x >= 0 and x < g.xsize then
              lb_we   <= '1';
              lb_addr <= bank & to_unsigned(x, 11);
              lb_data <= x"00" & idx;
            end if;
            pc <= pc + 1;
            if pix_j = 15 then
              if words_left = 0 then
                state     <= IDLE;
                line_done <= '1';
              else
                state <= COLLECT;
              end if;
            else
              pix_j <= pix_j + 1;
            end if;
        end case;
      end if;
    end if;
  end process;

end architecture;
