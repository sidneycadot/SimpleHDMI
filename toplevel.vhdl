
library ieee;
use ieee.std_logic_1164.all;

use work.hdmi_defs.all;

entity toplevel is
    port (
        XTAL_CLK : in  std_logic;
        --
        CPU_RESETN_ASYNC : in std_logic;
        --
        -- Differential HDMI signals.
        --
        HDMI_TX_CLK_P : out std_logic;
        HDMI_TX_CLK_N : out std_logic;
        HDMI_TX_P     : out std_logic_vector(0 to 2);
        HDMI_TX_N     : out std_logic_vector(0 to 2)
    );
end entity toplevel;

architecture arch of toplevel is

signal CLK_HDMI    : std_logic;
signal CLK_HDMI_x5 : std_logic;

signal RESET : std_logic;

begin

    clocksynth_instance : entity work.clocksynth
        port map (
            CLK_100MHz  => XTAL_CLK,
            CLK_HDMI    => CLK_HDMI,
            CLK_HDMI_x5 => CLK_HDMI_x5
        );

    reset_manager : entity work.reset_manager
        port map (
            CLK            => CLK_HDMI,
            RESET_IN_ASYNC => not CPU_RESETN_ASYNC,
            RESET_OUT_SYNC => RESET
        );

    hdmi_instance : entity work.hdmi
        port map (
            CLK_HDMI    => CLK_HDMI,
            CLK_HDMI_x5 => CLK_HDMI_x5,
            --
            RESET => RESET,
            --
            -- Differential HDMI signals.
            --
            HDMI_TX_CLK_P => HDMI_TX_CLK_P,
            HDMI_TX_CLK_N => HDMI_TX_CLK_N,
            HDMI_TX_P     => HDMI_TX_P,
            HDMI_TX_N     => HDMI_TX_N
        );

end architecture arch;
