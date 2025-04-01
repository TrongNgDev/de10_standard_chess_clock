library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity clock_divider is
	port(
		clk_50Mhz	: in  std_logic;	-- Input clock 50 MHz
		reset			: in  std_logic;
		clk_1hz     : out std_logic;  -- Output clock 1 Hz
		clk_5hz     : out std_logic  -- Output clock 5 Hz
		);
end clock_divider;


architecture behavior of clock_divider is
	signal clk_1_out 	: std_logic := '0';
	signal clk_5_out 	: std_logic := '0';
	signal count1 		: integer 	:= 0;
	signal count2 		: integer 	:= 0;

begin

	process (clk_50Mhz, reset)
	begin
		if reset = '1' then
			count1 <= 0;
			count2 <= 0;
			clk_1_out  <= '0';
			clk_5_out  <= '0';
			
		elsif (clk_50Mhz'event and clk_50Mhz = '1') then
		
			count1 <= count1 + 1;
			count2 <= count2 + 1;
			
			if count1 = 24_999_999 then
				clk_1_out <= not clk_1_out;
				count1 <= 0;
			end if;
			
			if count2 = 4_999_999 then
				clk_5_out <= not clk_5_out;
				count2 <= 0;
			end if;
		end if;
	end process;
	
	clk_1hz  <= clk_1_out;
	clk_5hz  <= clk_5_out;
	
end behavior;
