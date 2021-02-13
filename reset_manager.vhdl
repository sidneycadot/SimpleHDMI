
library ieee;
use ieee.std_logic_1164.all;

library xpm;
use xpm.vcomponents.all;

entity reset_manager is
   port (
       CLK            : in std_logic;
       RESET_IN_ASYNC : in std_logic;
       --
       RESET_OUT_SYNC : out std_logic
    );
end entity reset_manager;

architecture arch of reset_manager is

    type StateType is
        record
            counter        : natural;
            reset_out_sync : std_logic;
        end record StateType;

constant reset_state : StateType := (
        counter        => 100,
        reset_out_sync => '1'
    );

type CombinatorialSignals is
    record
        next_state : StateType;
    end record CombinatorialSignals;

function UpdateCombinatorialSignals(current_state : in StateType; PORT_RESET : in std_logic) return CombinatorialSignals is

variable combinatorial : CombinatorialSignals;

begin
    
    combinatorial := (next_state => current_state);

    if PORT_RESET = '1' then
        combinatorial.next_state := reset_state;
    else
  
        if combinatorial.next_state.counter /= 0 then
            combinatorial.next_state.counter := combinatorial.next_state.counter - 1;
        end if;
    
        combinatorial.next_state.reset_out_sync := '0' when combinatorial.next_state.counter = 0 else '1';
    
    end if;
    
    return combinatorial;
    
end function UpdateCombinatorialSignals;

signal combinatorial : CombinatorialSignals;
signal current_state : StateType := reset_state;

signal RESET_IN_SYNCHRONIZED : std_logic;

begin

    xpm_cdc_single_instance : xpm_cdc_single
        generic map (
            DEST_SYNC_FF   => 2, -- DECIMAL; range: 2-10
            INIT_SYNC_FF   => 0, -- DECIMAL; 0=disable simulation init values, 1=enable simulation init values
            SIM_ASSERT_CHK => 0, -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            SRC_INPUT_REG  => 0  -- DECIMAL; 0=do not register input, 1=register input
        )
        port map (
            DEST_OUT => RESET_IN_SYNCHRONIZED, -- 1-bit output: src_in synchronized to the destination clock domain. This output is registered.
            DEST_CLK => CLK,                   -- 1-bit input: Clock signal for the destination clock domain.
            SRC_CLK  => '0',                   -- 1-bit input: optional; required when SRC_INPUT_REG = 1
            SRC_IN   => RESET_IN_ASYNC         -- 1-bit input: Input signal to be synchronized to dest_clk domain.
        );

    combinatorial <= UpdateCombinatorialSignals(current_state, RESET_IN_SYNCHRONIZED);

    current_state <= combinatorial.next_state when rising_edge(CLK);

    RESET_OUT_SYNC <= current_state.reset_out_sync;

end architecture arch;
