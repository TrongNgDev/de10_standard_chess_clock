library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity counter_16b is
	port (
		clk	 	: in std_logic; -- 50Mhz clock
		reset		: in std_logic;
		enable	: in std_logic;
		up_down  : in std_logic; -- 0-up, 1-down
		load     : in std_logic;
		load_data	: in  std_logic_vector(15 downto 0);
		output   	: out std_logic_vector(15 downto 0)
	);
end counter_16b;


architecture structure of counter_16b is
	signal counter_reg : unsigned(15 downto 0) := (others => '0');
	signal counter_1s  : integer 	 := 0;
	signal tick_1s     : std_logic := '0';
begin
   -- Generate 1Hz tick from 50MHz clock
   process(clk, reset)
   begin
		if reset = '1' then
			counter_1s <= 0;
			tick_1s <= '0';
		elsif (clk'event and clk = '1') then
			if counter_1s = 49_999_999 then
				counter_1s <= 0;
				tick_1s <= '1';
			else
				counter_1s <= counter_1s + 1;
				tick_1s <= '0';
			end if;
       end if;
   end process;

	-- Counter up/down each 1s
	process(clk, reset)
	begin
		if reset = '1' then
			counter_reg <= (others => '0');
		elsif (clk'event and clk = '1') then
			if load = '1' then
				counter_reg <= unsigned(load_data);
			elsif enable = '1' and tick_1s = '1' then
				if up_down = '0' then
					if counter_reg < x"FFFF" then
						counter_reg <= counter_reg + 1;
					end if;
				else
					if counter_reg > 0 then
						counter_reg <= counter_reg - 1;
					end if;
				end if;
			end if;
		end if;
	end process;
	
	output <= std_logic_vector(counter_reg);
	
end structure;