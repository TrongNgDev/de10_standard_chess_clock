library IEEE ;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity LCD_controller_test is
	port (clk			: in  std_logic;
			rst_btn		: in  std_logic;
			start_btn	: in 	std_logic;
			player_sel	: in	std_logic;
			time_A 		: out std_logic_vector(15 downto 0);
			time_B 		: out std_logic_vector(15 downto 0)
			);
end LCD_controller_test;

architecture test of LCD_controller_test is
	signal counter_A 	: integer := 0;
	signal counter_B 	: integer := 0;
	signal clk_count 	: integer := 0;
	signal counter_en	: std_logic := '0';
begin

	process (clk, rst_btn, start_btn)
	begin
		-- reset
		if rst_btn = '1' then
			counter_A <= 5400;
			counter_B <= 30;
			clk_count <= 0;
			counter_en <= '0';
		
		-- start/pause
		elsif start_btn = '1' then
			counter_en <= not counter_en;
		
		-- count down the clock
		elsif (clk'event and clk = '1') then
			if counter_en = '1' then
				clk_count <= clk_count + 1;
				if (clk_count > (49999999)) then
					if player_sel = '0' then 
						if counter_A > 0 then
							counter_A <= counter_A - 1;
						end if;
					else
						if counter_B > 0 then
							counter_B <= counter_B - 1;
						end if;
					end if;
					clk_count <= 0;
				end if;
			end if;
		end if;
	end process;
	
   time_A <= std_logic_vector(to_unsigned(counter_A, 16));
   time_B <= std_logic_vector(to_unsigned(counter_B, 16));
	
end test;
