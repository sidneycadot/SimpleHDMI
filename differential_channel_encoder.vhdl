
library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

entity differential_channel_encoder is
   port (
       CLK_HDMI    : in std_logic;
       CLK_HDMI_x5 : in std_logic;
       RESET       : in std_logic;
       --
       PIXEL_CHAR  : in std_logic_vector(9 downto 0);
       OUTPUT_P    : out std_logic;
       OUTPUT_N    : out std_logic
    );
end entity differential_channel_encoder;

architecture arch of differential_channel_encoder is

signal slave_to_master : std_logic_vector(1 to 2);
signal FAST_OUTPUT     : std_logic;

begin

    -- We use two OSERDES instances in a Master/Slave configuration to make a 10-bit word channel encoder.

    OSERDESE2_master_instance : OSERDESE2
        generic map (
            DATA_RATE_OQ   => "DDR",               -- DDR, SDR
            DATA_RATE_TQ   => "BUF",               -- DDR, BUF, SDR
            DATA_WIDTH     => 10,                  -- Parallel data width (2-8, 10, 14)
            INIT_OQ        => '0',                 -- Initial value of OQ output (1'b0, 1'b1)
            INIT_TQ        => '0',                 -- Initial value of TQ output (1'b0, 1'b1)
            SERDES_MODE    => "MASTER",            -- MASTER, SLAVE
            SRVAL_OQ       => '0',                 -- OQ output value when SR is used (1'b0, 1'b1)
            SRVAL_TQ       => '0',                 -- TQ output value when SR is used (1'b0, 1'b1)
            TBYTE_CTL      => "FALSE",             -- Enable tristate byte operation (FALSE, TRUE)
            TBYTE_SRC      => "FALSE",             -- Tristate byte source (FALSE, TRUE)
            TRISTATE_WIDTH => 1                    -- 3-state converter width (1, 4)
        )
        port map (
            OQ             => FAST_OUTPUT,         -- 1-bit output: Data path output
            OFB            => open,                -- 1-bit output: Feedback path for data
            -- SHIFTOUT1 / SHIFTOUT2: 1-bit (each) output: Data output expansion (1-bit each)
            SHIFTOUT1      => open,                -- (unused)
            SHIFTOUT2      => open,                -- (unused)
            TBYTEOUT       => open,                -- 1-bit output: Byte group tristate
            TFB            => open,                -- (unused)
            TQ             => open,                -- (unused)
            CLK            => CLK_HDMI_x5,         -- 1-bit input: High speed clock
            CLKDIV         => CLK_HDMI,            -- 1-bit input: Divided clock
            -- D1 - D8: 1-bit (each) input: Parallel data inputs (1-bit each)
            D1             => PIXEL_CHAR(0),       -- lower 8 bits of PIXEL_CHAR
            D2             => PIXEL_CHAR(1),       -- lower 8 bits of PIXEL_CHAR
            D3             => PIXEL_CHAR(2),       -- lower 8 bits of PIXEL_CHAR
            D4             => PIXEL_CHAR(3),       -- lower 8 bits of PIXEL_CHAR
            D5             => PIXEL_CHAR(4),       -- lower 8 bits of PIXEL_CHAR
            D6             => PIXEL_CHAR(5),       -- lower 8 bits of PIXEL_CHAR
            D7             => PIXEL_CHAR(6),       -- lower 8 bits of PIXEL_CHAR
            D8             => PIXEL_CHAR(7),       -- lower 8 bits of PIXEL_CHAR
            OCE            => '1',                 -- 1-bit input: Output data clock enable
            RST            => RESET,               -- 1-bit input: Reset
            -- SHIFTIN1 / SHIFTIN2: 1-bit (each) input: Data input expansion (1-bit each)
            SHIFTIN1       => slave_to_master(1),  -- 1-bit input: width expansion
            SHIFTIN2       => slave_to_master(2),  -- 1-bit input: width expansion
            -- T1 - T4: 1-bit (each) input: Parallel 3-state inputs
            T1             => '0',                 -- (unused)
            T2             => '0',                 -- (unused)
            T3             => '0',                 -- (unused)
            T4             => '0',                 -- (unused)
            TBYTEIN        => '1',                 -- 1-bit input: Byte group tristate
            TCE            => '1'                  -- 1-bit input: 3-state clock enable
        );

    OSERDESE2_slave_instance : OSERDESE2
        generic map (
            DATA_RATE_OQ   => "DDR",               -- DDR, SDR
            DATA_RATE_TQ   => "BUF",               -- DDR, BUF, SDR
            DATA_WIDTH     => 10,                  -- Parallel data width (2-8, 10, 14)
            INIT_OQ        => '0',                 -- Initial value of OQ output (1'b0, 1'b1)
            INIT_TQ        => '0',                 -- Initial value of TQ output (1'b0, 1'b1)
            SERDES_MODE    => "SLAVE",             -- MASTER, SLAVE
            SRVAL_OQ       => '0',                 -- OQ output value when SR is used (1'b0, 1'b1)
            SRVAL_TQ       => '0',                 -- TQ output value when SR is used (1'b0, 1'b1)
            TBYTE_CTL      => "FALSE",             -- Enable tristate byte operation (FALSE, TRUE)
            TBYTE_SRC      => "FALSE",             -- Tristate byte source (FALSE, TRUE)
            TRISTATE_WIDTH => 1                    -- 3-state converter width (1, 4)
        )
        port map (
            OQ        => open,                     -- 1-bit output: Data path output
            OFB       => open,                     -- 1-bit output: Feedback path for data
            -- SHIFTOUT1 / SHIFTOUT2: 1-bit (each) output: Data output expansion (1-bit each)
            SHIFTOUT1 => slave_to_master(1),       -- width expansion
            SHIFTOUT2 => slave_to_master(2),       -- width expansion
            TBYTEOUT  => open,                     -- 1-bit output: Byte group tristate
            TFB       => open,                     -- (unused)
            TQ        => open,                     -- (unused)
            CLK       => CLK_HDMI_x5,              -- 1-bit input: High speed clock
            CLKDIV    => CLK_HDMI,                 -- 1-bit input: Divided clock
            -- D1 - D8: 1-bit (each) input: Parallel data inputs (1-bit each)
            D1        => '0',                      -- (unused)
            D2        => '0',                      -- (unused)
            D3        => PIXEL_CHAR(8),            -- upper 2 bits of PIXEL_CHAR (width expansion)
            D4        => PIXEL_CHAR(9),            -- upper 2 bits of PIXEL_CHAR (width expansion)
            D5        => '0',                      -- (unused)
            D6        => '0',                      -- (unused)
            D7        => '0',                      -- (unused)
            D8        => '0',                      -- (unused)
            OCE       => '1',                      -- 1-bit input: Output data clock enable
            RST       => RESET,                    -- 1-bit input: Reset
            -- SHIFTIN1 / SHIFTIN2: 1-bit (each) input: Data input expansion (1-bit each)
            SHIFTIN1 => '0',                       -- (unused)
            SHIFTIN2 => '0',                       -- (unused)
            -- T1 - T4: 1-bit (each) input: Parallel 3-state inputs
            T1       => '0',                       -- (unused)
            T2       => '0',                       -- (unused)
            T3       => '0',                       -- (unused)
            T4       => '0',                       -- (unused)
            TBYTEIN  => '1',                       -- 1-bit input: Byte group tristate
            TCE      => '1'                        -- 1-bit input: 3-state clock enable
        );

    OBUFDS_instance : OBUFDS
        generic map (
            IOSTANDARD => "TMDS_33", -- Specify the output I/O standard
            SLEW       => "FAST"     -- Specify the output slew rate
        )
        port map (
            I  => FAST_OUTPUT, -- Buffer input 
            O  => OUTPUT_P,    -- Diff_p output
            OB => OUTPUT_N     -- Diff_n output
        );

end architecture arch;
