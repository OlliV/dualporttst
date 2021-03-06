--------------------------------------------------------------------
-- Company : XESS Corp.
-- Engineer : Dave Vanden Bout
-- Creation Date : 06/13/2005
-- Copyright : 2005, XESS Corp
-- Tool Versions : WebPACK 6.3.03i
--
-- Description:
-- This module tests the SDRAM controller and external SDRAM chip by
-- writing a random data pattern to the SDRAM and then reading it
-- back to see if the SDRAM contains the correct pattern.
--
--  +--------------+    +---------------+      +-----------+
--  |              |    |               |      |           |
--  |              |    |               |      |           |
--  |              |    |               |      |           |
--  |    memory    |    |    SDRAM      |      |   SDRAM   |
--  |    tester    |<==>|  controller   |<====>|   chip    |
--  |              |    |               |      |           |
--  |              |    |               |      |           |
--  |              |    |               |      |           |
--  |              |    |               |      |           |
--  +--------------+    +---------------+      +-----------+
--
-- Revision:
-- 1.0.0
--
-- Additional Comments:
--
-- License:
-- This code can be freely distributed and modified as long as
-- this header is not removed.
--------------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;

package test_board_core_pckg is
  component test_board_core
    generic(
      FREQ        :       natural := 67_000;  -- frequency of operation in KHz
      PIPE_EN     :       boolean := true;  -- enable fast, pipelined SDRAM operation
      DATA_WIDTH  :       natural := 16;  -- SDRAM data width
      SADDR_WIDTH :       natural := 13;  -- SDRAM row/col address width
      NROWS       :       natural := 4096;  -- number of rows in the SDRAM
      NCOLS       :       natural := 512;  -- number of columns in each SDRAM row
      -- beginning and ending addresses for the entire SDRAM
      BEG_ADDR    :       natural := 16#00_0000#;
      END_ADDR    :       natural := 16#7F_FFFF#;
      -- beginning and ending address for the memory tester
      BEG_TEST    :       natural := 16#00_0000#;
      END_TEST    :       natural := 16#7F_FFFF#
      );
    port(
      clk         : in    std_logic;      -- main clock input from external clock source
      cke         : out   std_logic;      -- SDRAM clock-enable
      cs_n        : out   std_logic;      -- SDRAM chip-select
      ras_n       : out   std_logic;      -- SDRAM RAS
      cas_n       : out   std_logic;      -- SDRAM CAS
      we_n        : out   std_logic;      -- SDRAM write-enable
      ba          : out   std_logic_vector(1 downto 0);  -- SDRAM bank-address
      sAddr       : out   std_logic_vector(SADDR_WIDTH-1 downto 0);  -- SDRAM address bus
      sDataIn     : in    std_logic_vector(DATA_WIDTH-1 downto 0);  -- data from SDRAM
      sDataOut    : out   std_logic_vector(DATA_WIDTH-1 downto 0);  -- data to SDRAM
      sDataOutEn  : out   std_logic;      -- high when data is output to SDRAM
      dqmh        : out   std_logic;      -- SDRAM DQMH
      dqml        : out   std_logic;      -- SDRAM DQML
      progress    : out   std_logic_vector(1 downto 0); -- test progress indicator
      led         : out   std_logic_vector(15 downto 0);  -- dual seven-segment LEDs
      heartBeat   : out   std_logic       -- heartbeat status (usually sent to parallel port status pin)
      );
  end component test_board_core;
end package test_board_core_pckg;




library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use WORK.common.all;
use WORK.mem.all;
use WORK.sdram.all;

entity test_board_core is
  generic(
    FREQ        :       natural := 67_000;  -- frequency of operation in KHz
    PIPE_EN     :       boolean := true;  -- enable fast, pipelined SDRAM operation
    DATA_WIDTH  :       natural := 16;  -- SDRAM data width
    SADDR_WIDTH :       natural := 13;  -- SDRAM row/col address width
    NROWS       :       natural := 4096;  -- number of rows in the SDRAM
    NCOLS       :       natural := 512;  -- number of columns in each SDRAM row
    -- beginning and ending addresses for the entire SDRAM
    BEG_ADDR    :       natural := 16#00_0000#;
    END_ADDR    :       natural := 16#7F_FFFF#;
    -- beginning and ending address for the memory tester
    BEG_TEST    :       natural := 16#00_0000#;
    END_TEST    :       natural := 16#7F_FFFF#
    );
  port(
    clk         : in    std_logic;      -- main clock input from external clock source
    cke         : out   std_logic;      -- SDRAM clock-enable
    cs_n        : out   std_logic;      -- SDRAM chip-select
    ras_n       : out   std_logic;      -- SDRAM RAS
    cas_n       : out   std_logic;      -- SDRAM CAS
    we_n        : out   std_logic;      -- SDRAM write-enable
    ba          : out   std_logic_vector(1 downto 0);  -- SDRAM bank-address
    sAddr       : out   std_logic_vector(SADDR_WIDTH-1 downto 0);  -- SDRAM address bus
    sDataIn     : in    std_logic_vector(DATA_WIDTH-1 downto 0);  -- data from SDRAM
    sDataOut    : out   std_logic_vector(DATA_WIDTH-1 downto 0);  -- data to SDRAM
    sDataOutEn  : out   std_logic;      -- high when data is output to SDRAM
    dqmh        : out   std_logic;      -- SDRAM DQMH
    dqml        : out   std_logic;      -- SDRAM DQML
    progress    : out   std_logic_vector(1 downto 0); -- test progress indicator
    led         : out   std_logic_vector(15 downto 0);  -- dual seven-segment LEDs
    heartBeat   : out   std_logic       -- heartbeat status (usually sent to parallel port status pin)
    );
end entity;

architecture arch of test_board_core is
  constant HADDR_WIDTH     : natural := log2(END_ADDR-BEG_ADDR+1);
  signal   rst_i           : std_logic;  -- internal reset signal
  signal   rstCnt          : natural range 0 to 511;  -- reset timer
  signal   divCnt          : unsigned(20 downto 0);  -- clock divider

  -- signals that go through the SDRAM host-side interface
  signal   begun           : std_logic;  -- SDRAM operation started indicator
  signal   earlyBegun      : std_logic;  -- SDRAM operation started indicator
  signal   done            : std_logic;  -- SDRAM operation complete indicator
  signal   rdDone          : std_logic;  -- SDRAM operation complete indicator
  signal   hAddr           : std_logic_vector(HADDR_WIDTH-1 downto 0);  -- host address bus
  signal   hDIn            : std_logic_vector(DATA_WIDTH-1 downto 0);  -- host-side data to SDRAM
  signal   hDOut           : std_logic_vector(DATA_WIDTH-1 downto 0);  -- host-side data from SDRAM
  signal   rd              : std_logic;  -- host-side read control signal
  signal   wr              : std_logic;  -- host-side write control signal
  signal   rdPending       : std_logic;  -- read operation pending in SDRAM pipeline

  -- status signals from the memory tester
  signal   progress_i      : std_logic_vector(1 downto 0);  -- internal test progress indicator
  signal   err             : std_logic;  -- test error flag

begin

  ------------------------------------------------------------------------
  -- internal reset flag is set active right after configuration is done
  -- because the reset counter starts at zero, and then gets reset after
  -- the counter reaches its upper threshold.
  ------------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if rstCnt /= 100 then
        rst_i   <= '1';
        rstCnt  <= rstCnt + 1;
      else
        rst_i   <= '0';  -- remove reset once counter reaches its threshold
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------
  -- Instantiate a memory tester that supports memory pipelining if that option is enabled
  ------------------------------------------------------------------------
  gen_fast_memtest : if PIPE_EN generate
    fast_memtest        : memTest
      generic map(
        PIPE_EN    => PIPE_EN,
        DATA_WIDTH => DATA_WIDTH,
        ADDR_WIDTH => HADDR_WIDTH,
        BEG_TEST   => BEG_TEST,
        END_TEST   => END_TEST
        )
      port map(
        clk        => clk,              -- master internal clock
        rst        => rst_i,            -- reset
        doAgain    => NO,               -- run the test once
        begun      => earlyBegun,       -- SDRAM controller operation started
        done       => rdDone,           -- SDRAM controller operation complete
        dIn        => hDOut,            -- host-side data from SDRAM goes to memory tester
        rdPending  => rdPending,        -- tell the memory tester if the SDRAM has pending reads
        rd         => rd,               -- host-side SDRAM read control from memory tester
        wr         => wr,               -- host-side SDRAM write control from memory tester
        addr       => hAddr,            -- host-side address from memory tester
        dOut       => hDIn,             -- host-side data to SDRAM comes from memory tester
        progress   => progress_i,       -- current phase of memory test
        err        => err               -- memory test error flag
        );
  end generate;

  ------------------------------------------------------------------------
  -- Instantiate memory tester without memory pipelining if that option is disabled
  ------------------------------------------------------------------------
  gen_slow_memtest : if not PIPE_EN generate
    slow_memtest        : memTest
      generic map(
        PIPE_EN    => PIPE_EN,
        DATA_WIDTH => DATA_WIDTH,
        ADDR_WIDTH => HADDR_WIDTH,
        BEG_TEST   => BEG_TEST,
        END_TEST   => END_TEST
        )
      port map(
        clk        => clk,              -- master internal clock
        rst        => rst_i,            -- reset
        doAgain    => NO,               -- run the test once
        begun      => begun,            -- SDRAM controller operation started
        done       => done,             -- SDRAM controller operation complete
        dIn        => hDOut,            -- host-side data from SDRAM goes to memory tester
        rdPending  => rdPending,        -- tell the memory tester if the SDRAM has pending reads
        rd         => rd,               -- host-side SDRAM read control from memory tester
        wr         => wr,               -- host-side SDRAM write control from memory tester
        addr       => hAddr,            -- host-side address from memory tester
        dOut       => hDIn,             -- host-side data to SDRAM comes from memory tester
        progress   => progress_i,       -- current phase of memory test
        err        => err               -- memory test error flag
        );
  end generate;

  progress <= progress_i;

  ------------------------------------------------------------------------
  -- Instantiate the SDRAM controller that connects to the memory tester
  -- module and interfaces to the external SDRAM chip.
  ------------------------------------------------------------------------
  u1 : sdramCntl
    generic map(
      FREQ         => FREQ,
      IN_PHASE     => false,
      PIPE_EN      => PIPE_EN,
      MAX_NOP      => 10000,
      DATA_WIDTH   => DATA_WIDTH,
      NROWS        => NROWS,
      NCOLS        => NCOLS,
      HADDR_WIDTH  => HADDR_WIDTH,
      SADDR_WIDTH  => SADDR_WIDTH
      )
    port map(
      clk          => clk,           -- master clock from external clock source (unbuffered)
      lock         => YES,           -- no DLLs, so frequency is always locked
      rst          => rst_i,         -- reset
      rd           => rd,            -- host-side SDRAM read control from memory tester
      wr           => wr,            -- host-side SDRAM write control from memory tester
      earlyOpBegun => earlyBegun,    -- early indicator that memory operation has begun
      opBegun      => begun,         -- indicates memory read/write has begun
      rdPending    => rdPending,     -- read operation to SDRAM is in progress
      done         => done,          -- SDRAM memory read/write done indicator
      rdDone       => rdDone,        -- indicates SDRAM memory read operation is done
      hAddr        => hAddr,         -- host-side address from memory tester to SDRAM
      hDIn         => hDIn,          -- test data pattern from memory tester to SDRAM
      hDOut        => hDOut,         -- SDRAM data output to memory tester
      status       => open,          -- SDRAM controller state (for diagnostics)
      cke          => cke,           -- SDRAM clock enable
      ce_n         => cs_n,          -- SDRAM chip-select
      ras_n        => ras_n,         -- SDRAM RAS
      cas_n        => cas_n,         -- SDRAM CAS
      we_n         => we_n,          -- SDRAM write-enable
      ba           => ba,            -- SDRAM bank address
      sAddr        => sAddr,         -- SDRAM address
      sDIn         => sDataIn,       -- data in from SDRAM
      sDOut        => sDataOut,      -- data out to SDRAM
      sDOutEn      => sDataOutEn,    -- high when data is sent to SDRAM
      dqmh         => dqmh,          -- SDRAM DQMH
      dqml         => dqml           -- SDRAM DQML
      );

  ------------------------------------------------------------------------
  -- Indicate the phase of the memory tester on the segments of the 
  -- seven-segment LED.  The phases of the memory test are
  -- indicated as shown below (|=LED OFF; *=LED ON):
  -- 
  --       ----*           *****            *****           ******           ******
  --      |    *          |    *           |    *           *    *           *    |
  --       ----*          ******            *****           *----*           ******
  --      |    *          *    |           |    *           *    *           *    |
  --       ----*          *****             *****           ******           ******
  --  Initialization  Writing pattern  Reading pattern    Memory test  or  Memory test
  --      Phase          to memory       from memory        passed           failed
  ------------------------------------------------------------------------
  led <= "0000000000000110" when progress_i = "00" else  -- "1" during initialization
         "0000000001011011" when progress_i = "01" else  -- "2" when writing to memory
         "0000000001001111" when progress_i = "10" else  -- "3" when reading from memory
         "0000000001111001" when err = YES         else  -- "E" if memory test failed
         "0000000000111111";                             -- "O" if memory test passed

  ------------------------------------------------------------------------
  -- Generate some slow signals from the master clock.
  ------------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      divCnt <= divCnt+1;
    end if;
  end process;

  ------------------------------------------------------------------------
  -- Send a heartbeat signal back to the PC to indicate
  -- the status of the memory test:
  --   50% duty cycle -> test in progress
  --   75% duty cycle -> test passed
  --   25% duty cycle -> test failed
  ------------------------------------------------------------------------
  heartBeat   <= divCnt(16)               when progress_i/="11" else  -- test in progress
                 divCnt(16) or divCnt(15) when err = NO         else  -- test passed
                 divCnt(16) and divCnt(15);                           -- test failed                              

end architecture;
