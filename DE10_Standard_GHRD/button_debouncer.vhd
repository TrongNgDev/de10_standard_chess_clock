library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity button_debouncer is
	port (
	  clk       	: in  std_logic; -- 50MHz
	  btn_in    	: in  std_logic;
	  btn_out   	: out std_logic
	);
end button_debouncer;

architecture behavior of button_debouncer is
	constant DEBOUNCE_TIME	: unsigned(19 downto 0) := to_unsigned(500000, 20); -- 10ms
	signal ff					: std_logic_vector(1 downto 0) := (others => '0');
	signal counter				: unsigned(19 downto 0) := (others => '0');
	signal button_stable		: std_logic := '0';
begin

	process(clk)
	begin
		if (clk'event and clk = '1') then
			ff(0) <= btn_in;
			ff(1) <= ff(0);
			if ff(1) /= button_stable then
				counter <= counter + 1;
				if counter < DEBOUNCE_TIME then
					button_stable <= ff(1);
					counter <= (others => '0');
				end if;
			else
				counter <= (others => '0');
			end if;
		end if;
	end process;
	
	btn_out <= button_stable;
	
end behavior;
