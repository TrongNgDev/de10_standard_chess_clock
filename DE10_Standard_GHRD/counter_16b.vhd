library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity counter_16b is
	port (
		clk	 	: in std_logic;
		clk_50Mhz : in std_logic;
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
	signal output_reg  : unsigned(15 downto 0) := (others => '0');

begin

	process(clk, reset)
	begin
		if reset = '1' then
			counter_reg <= (others => '0');
		elsif (clk'event and clk = '1') then
			if load = '1' then
				counter_reg <= unsigned(load_data);
			elsif enable = '1' then
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
	
	process (clk_50Mhz)
	begin
		if (clk_50Mhz'event and clk_50Mhz = '1') then
			if load = '1' then
				output_reg <= unsigned(load_data);
			else
				output_reg <= counter_reg;
			end if;
		end if;
	end process;
	
	output <= std_logic_vector(output_reg);
	
end structure;
