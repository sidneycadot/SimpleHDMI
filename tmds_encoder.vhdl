
library ieee;
use ieee.std_logic_1164.all;

use work.hdmi_defs.all;

entity tmds_encoder is
   generic (
       channel : in HDMI_TDMS_Channel
   );
   port (
       CLK_HDMI     : in std_logic;
       RESET        : in std_logic;
       --
       PIXEL_TYPE   : in HDMI_PixelType;
       CONTROL_DATA : in std_logic_vector(1 downto 0); -- for Control pixels
       TERC_DATA    : in std_logic_vector(3 downto 0); -- for Data Islands 
       VIDEO_DATA   : in std_logic_vector(7 downto 0); -- for Video Islands
       --
       TMDS_OUT     : out std_logic_vector(9 downto 0)
    );
end entity tmds_encoder;

architecture arch of tmds_encoder is

subtype BiasType is integer range -128 to 127;

type StateType is record
        bias     : BiasType; -- number of ones sent minus number of zeroes sent, at the fast clock rate. Note that this will always be even.
        tmds_out : std_logic_vector(9 downto 0);
    end record StateType;

constant reset_state : StateType := (
        bias     => 0,
        tmds_out => "0000000000"
    );

function count_zeros(x: in std_logic_vector) return BiasType is
variable count: BiasType;
begin
    count := 0;
    for i in x'range loop
        if x(i) = '0' then
            count := count + 1;
        end if;
    end loop;
    return count;
end function count_zeros;

function count_ones(x: in std_logic_vector) return BiasType is
variable count: BiasType;
begin
    count := 0;
    for i in x'range loop
        if x(i) = '1' then
            count := count + 1;
        end if;
    end loop;
    return count;
end function count_ones;

type CombinatorialSignals is
    record
        next_state : StateType;
    end record CombinatorialSignals;

function UpdateCombinatorialSignals(current_state : in StateType; PORT_RESET : in std_logic;
        PORT_PIXEL_TYPE   : in HDMI_PixelType;
        PORT_CONTROL_DATA : in std_logic_vector(1 downto 0);
        PORT_TERC_DATA    : in std_logic_vector(3 downto 0);
        PORT_VIDEO_DATA   : in std_logic_vector(7 downto 0)
    ) return CombinatorialSignals is

variable combinatorial : CombinatorialSignals;

variable q_m   : std_logic_vector(8 downto 0);
variable q_out : std_logic_vector(9 downto 0);

variable n0 : BiasType;
variable n1 : BiasType;

begin
    if PORT_RESET = '1' then
        combinatorial.next_state := reset_state;
    else
        combinatorial.next_state := current_state;

        case PORT_PIXEL_TYPE is
            when Control =>
                -- See HDMI Standard, Section 5.4.2.
                case PORT_CONTROL_DATA is
                    when "00"   => combinatorial.next_state.tmds_out := "1101010100";
                    when "01"   => combinatorial.next_state.tmds_out := "0010101011";
                    when "10"   => combinatorial.next_state.tmds_out := "0101010100";
                    when others => combinatorial.next_state.tmds_out := "1010101011";
                end case;
                combinatorial.next_state.bias := 0;
            when DataIslandGuardBand =>
                -- See HDMI Standard, Section 5.2.3.3.
                case channel is
                    when Ch0 =>
                        case to_bv(PORT_TERC_DATA) is
                            when "0000" => combinatorial.next_state.tmds_out := "1010011100";
                            when "0001" => combinatorial.next_state.tmds_out := "1001100011";
                            when "0010" => combinatorial.next_state.tmds_out := "1011100100";
                            when "0011" => combinatorial.next_state.tmds_out := "1011100010";
                            when "0100" => combinatorial.next_state.tmds_out := "0101110001";
                            when "0101" => combinatorial.next_state.tmds_out := "0100011110";
                            when "0110" => combinatorial.next_state.tmds_out := "0110001110";
                            when "0111" => combinatorial.next_state.tmds_out := "0100111100";
                            when "1000" => combinatorial.next_state.tmds_out := "1011001100";
                            when "1001" => combinatorial.next_state.tmds_out := "0100111001";
                            when "1010" => combinatorial.next_state.tmds_out := "0110011100";
                            when "1011" => combinatorial.next_state.tmds_out := "1011000110";
                            when "1100" => combinatorial.next_state.tmds_out := "1010001110"; -- should be one of these four.
                            when "1101" => combinatorial.next_state.tmds_out := "1001110001"; -- should be one of these four.
                            when "1110" => combinatorial.next_state.tmds_out := "0101100011"; -- should be one of these four.
                            when "1111" => combinatorial.next_state.tmds_out := "1011000011"; -- should be one of these four.
                        end case;
                    when Ch1 => combinatorial.next_state.tmds_out := "0100110011";
                    when Ch2 => combinatorial.next_state.tmds_out := "0100110011";
                end case;
                combinatorial.next_state.bias := 0;
            when DataIsland =>
                -- See HDMI Standard, Section 5.4.3.
                case PORT_TERC_DATA is
                    when "0000" => combinatorial.next_state.tmds_out := "1010011100";
                    when "0001" => combinatorial.next_state.tmds_out := "1001100011";
                    when "0010" => combinatorial.next_state.tmds_out := "1011100100";
                    when "0011" => combinatorial.next_state.tmds_out := "1011100010";
                    when "0100" => combinatorial.next_state.tmds_out := "0101110001";
                    when "0101" => combinatorial.next_state.tmds_out := "0100011110";
                    when "0110" => combinatorial.next_state.tmds_out := "0110001110";
                    when "0111" => combinatorial.next_state.tmds_out := "0100111100";
                    when "1000" => combinatorial.next_state.tmds_out := "1011001100";
                    when "1001" => combinatorial.next_state.tmds_out := "0100111001";
                    when "1010" => combinatorial.next_state.tmds_out := "0110011100";
                    when "1011" => combinatorial.next_state.tmds_out := "1011000110";
                    when "1100" => combinatorial.next_state.tmds_out := "1010001110";
                    when "1101" => combinatorial.next_state.tmds_out := "1001110001";
                    when "1110" => combinatorial.next_state.tmds_out := "0101100011";
                    when others => combinatorial.next_state.tmds_out := "1011000011";
                end case;
                combinatorial.next_state.bias := 0;
            when VideoIslandLeadingGuardBand =>
                -- See HDMI Standard, Section 5.2.2.1.
                case channel is
                    when Ch0 => combinatorial.next_state.tmds_out := "1011001100"; -- 5 ones, 5 zeros. Bias does not change.
                    when Ch1 => combinatorial.next_state.tmds_out := "0100110011"; -- 5 ones, 5 zeros. Bias does not change.
                    when Ch2 => combinatorial.next_state.tmds_out := "1011001100"; -- 5 ones, 5 zeros. Bias does not change.
                end case;
                combinatorial.next_state.bias := 0;
            when VideoIslandData =>
                -- See HDMI Standard, Section 5.4.4.1.

                n1 := count_ones(PORT_VIDEO_DATA);

                if (n1 > 4) or (n1 = 4 and PORT_VIDEO_DATA(0) = '0') then
                    q_m(0) :=             PORT_VIDEO_DATA(0);
                    q_m(1) := q_m(0) xnor PORT_VIDEO_DATA(1);
                    q_m(2) := q_m(1) xnor PORT_VIDEO_DATA(2);
                    q_m(3) := q_m(2) xnor PORT_VIDEO_DATA(3);
                    q_m(4) := q_m(3) xnor PORT_VIDEO_DATA(4);
                    q_m(5) := q_m(4) xnor PORT_VIDEO_DATA(5);
                    q_m(6) := q_m(5) xnor PORT_VIDEO_DATA(6);
                    q_m(7) := q_m(6) xnor PORT_VIDEO_DATA(7);
                    q_m(8) := '0';
                else
                    q_m(0) :=             PORT_VIDEO_DATA(0);
                    q_m(1) := q_m(0) xor  PORT_VIDEO_DATA(1);
                    q_m(2) := q_m(1) xor  PORT_VIDEO_DATA(2);
                    q_m(3) := q_m(2) xor  PORT_VIDEO_DATA(3);
                    q_m(4) := q_m(3) xor  PORT_VIDEO_DATA(4);
                    q_m(5) := q_m(4) xor  PORT_VIDEO_DATA(5);
                    q_m(6) := q_m(5) xor  PORT_VIDEO_DATA(6);
                    q_m(7) := q_m(6) xor  PORT_VIDEO_DATA(7);
                    q_m(8) := '1';
                end if;

                n1 := count_ones (q_m(7 downto 0));
                n0 := count_zeros(q_m(7 downto 0));

                if combinatorial.next_state.bias = 0 or n1 = n0 then
                    q_out(9) := not q_m(8);
                    q_out(8) :=     q_m(8);
                    if q_m(8) = '1' then
                        q_out(7 downto 0) :=     q_m(7 downto 0);
                    else
                        q_out(7 downto 0) := not q_m(7 downto 0);
                    end if;

                    if q_m(8) = '0' then
                        combinatorial.next_state.bias := combinatorial.next_state.bias + (n0 - n1);
                    else
                        combinatorial.next_state.bias := combinatorial.next_state.bias + (n1 - n0);
                    end if;

                elsif (combinatorial.next_state.bias > 0 and n1 > n0) or (combinatorial.next_state.bias < 0 and n0 > n1) then
                    q_out(9) := '1';
                    q_out(8) := q_m(8);
                    q_out(7 downto 0) := not q_m(7 downto 0); -- invert
                    if q_m(8) = '1' then
                        combinatorial.next_state.bias := combinatorial.next_state.bias + 2 + (n0 - n1);
                    else
                        combinatorial.next_state.bias := combinatorial.next_state.bias     + (n0 - n1);
                    end if;
                else
                    q_out(9) := '0';
                    q_out(8) := q_m(8);
                    q_out(7 downto 0) := q_m(7 downto 0); -- do not invert
                    if q_m(8) = '0' then
                        combinatorial.next_state.bias := combinatorial.next_state.bias - 2 + (n1 - n0);
                    else
                        combinatorial.next_state.bias := combinatorial.next_state.bias     + (n1 - n0);
                    end if;
                end if;

                combinatorial.next_state.tmds_out := q_out;

        end case;

    end if;

    return combinatorial;

end function UpdateCombinatorialSignals;

signal current_state : StateType := reset_state;

signal combinatorial : CombinatorialSignals;

begin

    combinatorial <= UpdateCombinatorialSignals(current_state, RESET, PIXEL_TYPE, CONTROL_DATA, TERC_DATA, VIDEO_DATA);

    current_state <= combinatorial.next_state when rising_edge(CLK_HDMI);

    TMDS_OUT <= current_state.tmds_out;

end architecture arch;
