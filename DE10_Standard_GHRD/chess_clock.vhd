-- imports
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- main func()
entity chess_clock is
    port (
            clk         : in    std_logic;
            reset_btn   : in    std_logic;
            mode1_btn   : in    std_logic;
            mode2_btn   : in    std_logic;
            mode3_btn   : in    std_logic;
            inc_btn     : in    std_logic;
            dec_btn     : in    std_logic;
            start_btn   : in    std_logic;
				pause_btn   : in    std_logic;
            player_sw   : in    std_logic;
            timeA_out   : out   std_logic_vector(15 downto 0);
            timeB_out   : out   std_logic_vector(15 downto 0);
				clock_mode	: out   std_logic_vector(2 downto 0)
        );
end chess_clock;

architecture top of chess_clock is
    component counter_16b is
        port  (
            clk         : in std_logic;
				clk_50Mhz	: in std_logic;
            reset       : in std_logic;
            enable      : in std_logic;
            up_down     : in std_logic; -- 0-up, 1-down
            load        : in std_logic;
            load_data   : in  std_logic_vector(15 downto 0);
            output      : out std_logic_vector(15 downto 0)
        );
    end component;

	 component clock_divider is
        port(
            clk_50Mhz   : in  std_logic;
            reset       : in  std_logic;
            clk_1hz     : out std_logic;
            clk_5hz     : out std_logic
        );
    end component;
	
	signal clk_1hz, clk_5hz  	: std_logic;
	signal start_pause_btn		: std_logic := '0';
	signal start_btn_prev 		: std_logic;
	signal rstA, enA, ldA		: std_logic;
	signal rstB, enB, ldB		: std_logic;
	signal lddA, lddB 	: std_logic_vector(15 downto 0);
	signal timeA, timeB 	: std_logic_vector(15 downto 0);
	signal timeoutA, timeoutB	: std_logic;
	signal adjust_time			: std_logic;

	constant TIME_MODE_CLASSIC : unsigned(15 downto 0) := to_unsigned(5400, 16); -- 90 mins
	constant TIME_MODE_FAST 	: unsigned(15 downto 0) := to_unsigned(1800, 16); -- 30 mins
	constant TIME_MODE_BITZ 	: unsigned(15 downto 0) := to_unsigned(600, 16);  -- 10 mins
	signal 	time_mode_current : unsigned(15 downto 0) := TIME_MODE_CLASSIC;
	
	type state_type is (INIT, READY, PLAYER_A, PLAYER_B, PAUSE, COMPLETE);
	signal current_state, next_state : state_type := INIT;
	signal clock_mode_reg : std_logic_vector(2 downto 0);
	
begin
	tick: clock_divider port map (
		clk_50Mhz   => clk,
		reset       => reset_btn,
		clk_1hz     => clk_1hz,
		clk_5hz		=> clk_5hz
	);
	 
	timerA: counter_16b port map(
		clk         => clk_1hz,
		clk_50Mhz	=> clk,
		reset       => rstA,
		enable      => enA,
		up_down     => '1', -- 0-up, 1-down
		load        => ldA,
		load_data   => lddA,
		output      => timeA
	);
	
	timerB: counter_16b port map(
		clk         => clk_1hz,
		clk_50Mhz	=> clk,
		reset       => rstB,
		enable      => enB,
		up_down     => '1', -- 0-up, 1-down
		load        => ldB,
		load_data   => lddB,
		output      => timeB
	);
	
	
	--Sync: Reset and state change
	process(clk)
	begin
		if (clk'event and clk = '1') then
			if reset_btn = '1' then
				current_state <= INIT;
			else
				current_state <= next_state;
			end if;
		end if;
	end process;
	
	
	--Adjust time for a chess match
	process(clk_5hz, reset_btn)
	begin
		if (clk_5hz'event and clk_5hz = '1') then
			if reset_btn = '1' then
				time_mode_current <= TIME_MODE_CLASSIC;
			elsif current_state = INIT then
				if (mode1_btn = '1') then
					time_mode_current <= TIME_MODE_CLASSIC;
				elsif (mode2_btn = '1') then
					time_mode_current <= TIME_MODE_FAST;
				elsif (mode3_btn = '1') then
					time_mode_current <= TIME_MODE_BITZ;
				else
					if (inc_btn = '1') then
						if time_mode_current < 35940 then	-- >
							time_mode_current <= time_mode_current + 60; --increase 1 min
						end if;
					elsif (dec_btn = '1') then
						if time_mode_current > 60 then
							time_mode_current <= time_mode_current - 60; --decrease 1 min
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;
	
	
	-- State machine
	process(clk)
	begin
		if (clk'event and clk = '1') then
			case current_state is
			
				when INIT =>
					enA <= '0';
					enB <= '0';
					ldA <= '1';
					ldB <= '1';
					clock_mode_reg <= "000";
					if (mode1_btn = '1') then
						lddA <= std_logic_vector(TIME_MODE_CLASSIC);
						lddB <= std_logic_vector(TIME_MODE_CLASSIC);
					elsif (mode2_btn = '1') then
						lddA <= std_logic_vector(TIME_MODE_FAST);
						lddB <= std_logic_vector(TIME_MODE_FAST);
					elsif (mode3_btn = '1') then
						lddA <= std_logic_vector(TIME_MODE_BITZ);
						lddB <= std_logic_vector(TIME_MODE_BITZ);
					else
						lddA <= std_logic_vector(time_mode_current);
						lddB <= std_logic_vector(time_mode_current);
					end if;
					-- Next state?
					if (start_btn = '1') then
						next_state <= READY;
					else
						next_state <= INIT;
					end if;
					
				when READY =>
					ldA <= '0';
					ldB <= '0';
					clock_mode_reg <= "001";
					if (player_sw = '0') then
						next_state <= PLAYER_A;
					else
						next_state <= PLAYER_B;
					end if;
					
				when PLAYER_A =>
					enA <= '1';
					enB <= '0';
					clock_mode_reg <= "010";
					-- Next state?
					if (timeoutA = '1') then
						next_state <= COMPLETE;
					elsif (pause_btn = '1') then
						next_state <= PAUSE;
					elsif (player_sw = '0') then
						next_state <= PLAYER_A;
					else
						next_state <= PLAYER_B;
					end if;

				when PLAYER_B =>
					enA <= '0';
					enB <= '1';
					clock_mode_reg <= "011";
					-- Next state?
					if (timeoutB = '1') then
						next_state <= COMPLETE;
					elsif (pause_btn = '1') then
						next_state <= PAUSE;
					elsif (player_sw = '0') then
						next_state <= PLAYER_A;
					else
						next_state <= PLAYER_B;
					end if;
				
				when PAUSE =>
					enA <= '0';
					enB <= '0';
					clock_mode_reg <= "100";
					-- Next state?
					--if (start_pause_btn = '1') then
					if (start_btn = '1') then
						if (player_sw = '0') then
							next_state <= PLAYER_A;
						else
							next_state <= PLAYER_B;
						end if;
					else
						next_state <= PAUSE;
					end if;
				
				when COMPLETE =>
					enA <= '0';
					enB <= '0';
					clock_mode_reg <= "101";
					-- Next state?
					next_state <= COMPLETE; --press Reset to start a new game
			end case;
		end if;
	end process;
	
	timeoutA  <= '1' when timeA = x"0000" else '0';
	timeoutB  <= '1' when timeB = x"0000" else '0';
	timeA_out <= timeA;
	timeB_out <= timeB;
	clock_mode <= clock_mode_reg;
	
end top;
