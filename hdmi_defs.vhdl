library ieee;
use ieee.std_logic_1164.all;

package hdmi_defs is

    type HDMI_SyncPolarity is (NegativePolarity, PositivePolarity);
    type HDMI_PixelType    is (Control, VideoIslandLeadingGuardBand, VideoIslandData, DataIslandGuardBand, DataIsland);
    type HDMI_TDMS_Channel is (Ch0, Ch1, Ch2);

    -- Parameters for 1920x1080 at 60 Hz are as follows:

    -- H_SYNC_WIDTH is followed by H_BACK_PORCH is followed by H_PIXELS is followed by H_FRONT_PORCH.

    constant H_SYNC_WIDTH  : natural :=   44;
    constant H_BACK_PORCH  : natural :=  148;
    constant H_PIXELS      : natural := 1920;
    constant H_FRONT_PORCH : natural :=   88;
    
    constant H_TOTAL       : natural := H_SYNC_WIDTH + H_BACK_PORCH + H_PIXELS + H_FRONT_PORCH;
    
    constant H_SYNC_POLARITY : HDMI_SyncPolarity := PositivePolarity;
    
    -- V_SYNC_WIDTH is followed by V_BACK_PORCH is followed by V_PIXELS is followed by V_FRONT_PORCH.

    constant V_SYNC_WIDTH  : natural :=    5;
    constant V_BACK_PORCH  : natural :=   36;
    constant V_PIXELS      : natural := 1080;
    constant V_FRONT_PORCH : natural :=    4;
    
    constant V_TOTAL       : natural := V_SYNC_WIDTH + V_BACK_PORCH + V_PIXELS + V_FRONT_PORCH;
    
    constant V_SYNC_POLARITY : HDMI_SyncPolarity := PositivePolarity;

end package hdmi_defs;
