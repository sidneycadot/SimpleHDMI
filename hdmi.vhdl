
library ieee;
use ieee.std_logic_1164.all;

use work.hdmi_defs.all;

entity hdmi is
    port (
        CLK_HDMI      : in std_logic;
        CLK_HDMI_x5   : in std_logic;
        --
        RESET         : in std_logic;
        --
        -- Differential HDMI signals.
        --
        HDMI_TX_CLK_P : out std_logic;
        HDMI_TX_CLK_N : out std_logic;
        HDMI_TX_P     : out std_logic_vector(0 to 2);
        HDMI_TX_N     : out std_logic_vector(0 to 2)
    );
end entity hdmi;

architecture arch of hdmi is

type StateType is record
        --
        -- Screen coordinates.
        --
        x : natural;
        y : natural;
        --
        -- outputs to TMDS channels
        --
        pixel_type : HDMI_PixelType;
        hsync      : std_logic;
        vsync      : std_logic;
        ctl        : std_logic_vector(0 to 3); -- Note: specified from 0 to 3 (ascending)!
        terc       : std_logic_vector(11 downto 0);
        red        : std_logic_vector(7 downto 0);
        green      : std_logic_vector(7 downto 0);
        blue       : std_logic_vector(7 downto 0);
     end record StateType;

constant reset_state : StateType := (
        --
        x          => 0,
        y          => 0,
        --
        pixel_type => Control,
        hsync      => '0',
        vsync      => '0',
        ctl        => "0000",
        terc       => "000000000000",
        red        => x"00",
        green      => x"00",
        blue       => x"00"
    );

type TmdsCharacterArray is array (HDMI_TDMS_Channel) of std_logic_vector(9 downto 0);
signal sig_tmds : TmdsCharacterArray;

type CombinatorialSignals is
    record
        next_state : StateType;
    end record CombinatorialSignals;

function UpdateCombinatorialSignals(current_state: in StateType) return CombinatorialSignals is

variable combinatorial : CombinatorialSignals;

variable xx : natural; -- screen coordinates.
variable yy : natural;

function boolean_to_std_logic(b : boolean) return std_logic is
begin
    if b then
        return '1';
    else
        return '0';
    end if;
end boolean_to_std_logic;

begin

    combinatorial := CombinatorialSignals'(
        next_state => StateType'(
            x          => current_state.x,
            y          => current_state.y,
            pixel_type => Control,
            hsync      => boolean_to_std_logic((current_state.x < H_SYNC_WIDTH) xor (H_SYNC_POLARITY = NegativePolarity)),
            vsync      => boolean_to_std_logic((current_state.y < V_SYNC_WIDTH) xor (V_SYNC_POLARITY = NegativePolarity)),
            ctl        => "0000",
            terc       => (others => '-'),
            red        => (others => '-'),
            green      => (others => '-'),
            blue       => (others => '-')
        ));

    if combinatorial.next_state.y = 0 then

        -- We're at line #0. We'll put a Data Island here (the Standard says we need to have at least one every 2 fields.)

        if H_SYNC_WIDTH + H_BACK_PORCH - 10 <= combinatorial.next_state.x and combinatorial.next_state.x < H_SYNC_WIDTH + H_BACK_PORCH - 2 then
            -- See HDMI Standard, Section 5.2.1.1.
            -- We're in the control area, and we should emit the "preamble" to announce that a Data Insland Period is coming.
            combinatorial.next_state.ctl := "1010"; -- announce the coming Data Insland Period.
        elsif H_SYNC_WIDTH + H_BACK_PORCH - 2 <= combinatorial.next_state.x and combinatorial.next_state.x < H_SYNC_WIDTH + H_BACK_PORCH then
            -- We're in the Leading DataGuardBand (2 pixels before the actual Data Island will be sent)
            -- See HDMI Standard, Section 5.2.2.
            combinatorial.next_state.pixel_type := DataIslandGuardBand;
            combinatorial.next_state.terc(3 downto 0) := "11" & combinatorial.next_state.vsync & combinatorial.next_state.hsync;
        elsif H_SYNC_WIDTH + H_BACK_PORCH <= combinatorial.next_state.x and combinatorial.next_state.x < H_SYNC_WIDTH + H_BACK_PORCH + 32 then
            combinatorial.next_state.pixel_type := DataIsland;
            if combinatorial.next_state.x = H_SYNC_WIDTH + H_BACK_PORCH then
                combinatorial.next_state.terc(3 downto 0) := "00" & combinatorial.next_state.vsync & combinatorial.next_state.hsync;
            else
                combinatorial.next_state.terc(3 downto 0) := "10" & combinatorial.next_state.vsync & combinatorial.next_state.hsync;
            end if;
        elsif H_SYNC_WIDTH + H_BACK_PORCH + 32 <= combinatorial.next_state.x and combinatorial.next_state.x < H_SYNC_WIDTH + H_BACK_PORCH + 34 then
            combinatorial.next_state.pixel_type := DataIslandGuardBand;
            combinatorial.next_state.terc(3 downto 0) := "11" & combinatorial.next_state.vsync & combinatorial.next_state.hsync;
        end if;

    elsif V_SYNC_WIDTH + V_BACK_PORCH <= combinatorial.next_state.y and combinatorial.next_state.y < V_SYNC_WIDTH + V_BACK_PORCH + V_PIXELS then

        -- Vertically, we're in the active video area.

        if H_SYNC_WIDTH + H_BACK_PORCH - 10 <= combinatorial.next_state.x and combinatorial.next_state.x < H_SYNC_WIDTH + H_BACK_PORCH - 2 then
            -- See HDMI Standard, Section 5.2.1.1.
            -- We're in the control area, and we should emit the "preamble" to announce that a Video Data Period is coming.
            combinatorial.next_state.ctl := "1000"; -- announce the coming Video Data Period.
        elsif H_SYNC_WIDTH + H_BACK_PORCH - 2 <= combinatorial.next_state.x and combinatorial.next_state.x < H_SYNC_WIDTH + H_BACK_PORCH then
            -- We're in the VideoLeadingGuardBand (2 pixels before the actual Video Data will be sent)
            -- See HDMI Standard, Section 5.2.2.
            combinatorial.next_state.pixel_type := VideoIslandLeadingGuardBand;
        elsif H_SYNC_WIDTH + H_BACK_PORCH <= combinatorial.next_state.x and combinatorial.next_state.x < H_SYNC_WIDTH + H_BACK_PORCH + H_PIXELS then
            -- We're in the active video area, both vertically and horizontally.
            combinatorial.next_state.pixel_type := VideoIslandData;

            xx := combinatorial.next_state.x - (H_SYNC_WIDTH + H_BACK_PORCH);
            yy := combinatorial.next_state.y - (V_SYNC_WIDTH + V_BACK_PORCH);

            -- Determine the pixel color.

            if xx >= H_PIXELS / 2 then
                combinatorial.next_state.red := x"ff";
            end if;

            if yy >= V_PIXELS / 2 then
                combinatorial.next_state.blue := x"ff";
            end if;

            if (xx = 0 or xx = H_PIXELS - 1 or yy = 0 or yy = V_PIXELS - 1) then
                combinatorial.next_state.red   := x"ff";
                combinatorial.next_state.green := x"ff";
                combinatorial.next_state.blue  := x"ff";
            end if;

            if (xx - H_PIXELS / 2) * (xx - H_PIXELS / 2) + (yy - V_PIXELS / 2) * (yy - V_PIXELS / 2) <= (V_PIXELS / 2) * (V_PIXELS / 2) then
                combinatorial.next_state.red   := not combinatorial.next_state.red;
                combinatorial.next_state.green := not combinatorial.next_state.green;
                combinatorial.next_state.blue  := not combinatorial.next_state.blue;
            end if;

        end if;
    end if;

    -- We increase combinatorial.next_state.x and combinatorial.next_state.y at the end.
    -- This helps to shorten combinatorial paths, increasing the amount of work we can do per CLK_HDMI clock cycle.

    if combinatorial.next_state.x /= H_TOTAL - 1 then
        combinatorial.next_state.x := combinatorial.next_state.x + 1;
    else
        combinatorial.next_state.x := 0;
        if combinatorial.next_state.y /= V_TOTAL - 1 then
            combinatorial.next_state.y := combinatorial.next_state.y + 1;
        else
            combinatorial.next_state.y := 0;
        end if;
    end if;

    return combinatorial;

end function UpdateCombinatorialSignals;

signal current_state : StateType := reset_state;

signal combinatorial : CombinatorialSignals;

begin

    combinatorial <= UpdateCombinatorialSignals(current_state);

    current_state <= combinatorial.next_state when rising_edge(CLK_HDMI);

    -- For Control-signal assignment, see HDMI Standard, Section 5.4.2.

    tmds_encoder_ch0 : entity work.tmds_encoder
        generic map (
            channel => Ch0
        )
        port map (
            CLK_HDMI     => CLK_HDMI,
            RESET        => RESET,
            PIXEL_TYPE   => current_state.pixel_type,
            CONTROL_DATA => current_state.vsync & current_state.hsync,
            TERC_DATA    => current_state.terc(3 downto 0),
            VIDEO_DATA   => current_state.blue,
            TMDS_OUT     => sig_tmds(Ch0)
        );

    tmds_encoder_ch1 : entity work.tmds_encoder
        generic map (
            channel => Ch1
        )
        port map (
            CLK_HDMI     => CLK_HDMI,
            RESET        => RESET,
            PIXEL_TYPE   => current_state.pixel_type,
            CONTROL_DATA => current_state.ctl(1) & current_state.ctl(0),
            TERC_DATA    => current_state.terc(7 downto 4),
            VIDEO_DATA   => current_state.green,
            TMDS_OUT     => sig_tmds(Ch1)
        );

    tmds_encoder_ch2 : entity work.tmds_encoder
        generic map (
            channel => Ch2
        )
        port map (
            CLK_HDMI     => CLK_HDMI,
            RESET        => RESET,
            PIXEL_TYPE   => current_state.pixel_type,
            CONTROL_DATA => current_state.ctl(3) & current_state.ctl(2),
            TERC_DATA    => current_state.terc(11 downto 8),
            VIDEO_DATA   => current_state.red,
            TMDS_OUT     => sig_tmds(Ch2)
        );

    channel_encoder_ch0 : entity work.differential_channel_encoder
        port map (
            CLK_HDMI     => CLK_HDMI,
            CLK_HDMI_x5  => CLK_HDMI_x5,
            RESET        => RESET,
            --
            PIXEL_CHAR   => sig_tmds(Ch0),
            OUTPUT_P     => HDMI_TX_P(0),
            OUTPUT_N     => HDMI_TX_N(0)
    );

    channel_encoder_ch1 : entity work.differential_channel_encoder
        port map (
            CLK_HDMI     => CLK_HDMI,
            CLK_HDMI_x5  => CLK_HDMI_x5,
            RESET        => RESET,
            --
            PIXEL_CHAR   => sig_tmds(Ch1),
            OUTPUT_P     => HDMI_TX_P(1),
            OUTPUT_N     => HDMI_TX_N(1)
    );

    channel_encoder_ch2 : entity work.differential_channel_encoder
        port map (
            CLK_HDMI     => CLK_HDMI,
            CLK_HDMI_x5  => CLK_HDMI_x5,
            RESET        => RESET,
            --
            PIXEL_CHAR   => sig_tmds(Ch2),
            OUTPUT_P     => HDMI_TX_P(2),
            OUTPUT_N     => HDMI_TX_N(2)
    );

    channel_encoder_clk : entity work.differential_channel_encoder
        port map (
            CLK_HDMI     => CLK_HDMI,
            CLK_HDMI_x5  => CLK_HDMI_x5,
            RESET        => RESET,
            --
            PIXEL_CHAR   => "0000011111",
            OUTPUT_P     => HDMI_TX_CLK_P,
            OUTPUT_N     => HDMI_TX_CLK_N
    );

end architecture arch;
