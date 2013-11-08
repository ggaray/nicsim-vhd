NICSim-vhd: A VHDL-based modelling and simulation of NIC's buffers
--    Copyright (C) 2013 Godofredo R. Garay <godofredo_garay (-at-) gmail.com>


--    This program is free software: you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation, either version 3 of the License, or
--    (at your option) any later version.

--    This program is distributed in the hope that it will be useful,
--    but WITHOUT ANY WARRANTY; without even the implied warranty of
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--    GNU General Public License for more details.

--    You should have received a copy of the GNU General Public License
--    along with this program.  If not, see <http://www.gnu.org/licenses/>.



use std.textio.all;

library ieee;

use ieee.math_real.all; -- for uniform

use ieee.std_logic_1164.all;



entity othermaster is	

	port (

		frame		: inout		std_logic 	:= 'Z';

		pciclk		: in 		bit

	);

end othermaster;

architecture V1 of othermaster is



	---------------       Random number generator configuration   	---------------

	--Baseline

	constant	othermaster_seed1_value		: positive		:= 6;

	constant	othermaster_seed2_value		: positive		:= 31;


	--Run 1

	--constant	othermaster_seed1_value		: positive		:= 680;

	--constant	othermaster_seed2_value		: positive		:= 613;


	--Run 2

	--constant	othermaster_seed1_value		: positive		:= 700;

	--constant	othermaster_seed2_value		: positive		:= 88;


	--Run 3	

	--constant	othermaster_seed1_value		: positive		:= 47;

	--constant	othermaster_seed2_value		: positive		:= 92;


	--Run 4

	--constant	othermaster_seed1_value		: positive		:= 72;

	--constant	othermaster_seed2_value		: positive		:= 1;


	--Run 5

	--constant 	othermaster_seed1_value  	: positive		:= 37;

	--constant 	othermaster_seed2_value  	: positive		:= 41;


	--Run 6

	--constant 	othermaster_seed1_value  	: positive		:= 1;

	--constant 	othermaster_seed2_value  	: positive		:= 500;



	--Run 7

	--constant 	othermaster_seed1_value  	: positive		:= 2000;

	--constant 	othermaster_seed2_value  	: positive		:= 2001;

	--constant	othermaster_seed1_value		: positive		:= 2030;

	--constant	othermaster_seed2_value		: positive		:= 2101;

	--constant	othermaster_seed1_value		: positive		:= 2011;

	--constant	othermaster_seed2_value		: positive		:= 1970;

	--constant	othermaster_seed1_value		: positive		:= 1933;

	--constant	othermaster_seed2_value		: positive		:= 1937;

	--constant	othermaster_seed1_value		: positive		:= 73;

	--constant	othermaster_seed2_value		: positive		:= 194;

	--constant	othermaster_seed1_value		: positive		:= 3;
	
	--constant	othermaster_seed2_value		: positive		:= 101;

	--constant	othermaster_seed1_value		: positive		:= 1356;
	
	--constant	othermaster_seed2_value		: positive		:= 4;

	--constant	othermaster_seed1_value		: positive		:= 9;
	
	--constant	othermaster_seed2_value		: positive		:= 884;

	---------------       Bus arbitration latency configuration   	---------------

	constant	min_transaction_in_progress_latency 	: positive 	:= 1;

	constant	max_transaction_in_progress_latency 	: positive 	:= 80;


	---------------       Variables Declarations   	---------------

	shared 	variable	trdy_value 				: bit 		:= '1';

	shared	variable	random_cycles_count 			: integer 	:= 0;

	shared	variable	latency_cycles_count 			: integer 	:= 0;

	shared 	variable	total_acquisition_cycles 		: integer 	:= 0;

	shared 	variable	total_bus_transfer_cycles 		: integer 	:= 0;

	shared 	variable	current_transaction_cycles_count 	: integer 	:= 0;

	--shared variable		acquisition_cycles_count 		: integer 	:= 0;

	-- Variables needed for Memsub FSM

	type othermaster_fsm_state is (watching_bus_state, 

				      bus_acquired, 

				      bus_idle);

	shared variable 	state 			: othermaster_fsm_state 	:= watching_bus_state; 	--Initial state = watching_bus_state

	shared variable 	next_state 		: othermaster_fsm_state 	:= watching_bus_state;

	-- These signals are used to handle frame bidirectional port

	signal	dir 		: std_logic 	:= '0'; 	-- '0' reading, '1' driving

	signal	frame_out 	: std_logic 	:= 'Z';


-- ****** In the future, constant pcilck_period should be removed a function based on the pciclk signal should be implemented

	--constant	pciclk_period 	: time 		:= 0.03030303 us; 	-- PCI 33 

	--constant	pciclk_period 	: time 		:= 0.015151515 us; 	-- PCI-X 66

	constant	pciclk_period 	: time 		:= 0.007518797 us; 	-- PCI-X 133 

	--constant	pciclk_period 	: time 		:= 0.003759398 us;  	-- PCI-X 266 

	--constant	pciclk_period 	: time 		:= 0.001876173 us; 	-- PCI-X 533



	--constant tpd : time := 1 ns;  ****** To be removed

begin

	frame <= frame_out when (dir = '1') else 'Z';


	othermaster_fsm: process 

	begin

		wait until pciclk'event and pciclk = '1';

		case state is



			when watching_bus_state =>

				--gnt_value := '1';

				--bus_transfer_cycles_counter := 0;

				--latency_cycles_count := 0;

				--This wait cycle allows us avoiding bus contention among the NIC and othermaster

				wait for pciclk_period;

				dir <= '0';

				if	frame = '0' 

				then	--dir <= '0' ;

					next_state := watching_bus_state;

				elsif	frame = 'Z' 

				then	dir <= '1';

					frame_out <= '0';

					current_transaction_cycles_count := random_cycles_count;

					--latency_cycles_count := generate_random_latency_in_cycles;

					--acquisition_cycles_count := random_cycles_count;

					--total_acquisition_cycles := total_acquisition_cycles + acquisition_cycles_count;

					--bus_transfer_cycles_counter := dma_burst_size_in_cycles;

					--total_bus_transfer_cycles = total_bus_transfer_cycles + bus_transfer_cycles_counter;

					assert false 

					report "othermaster_fsm: bus_acquired" 
	
					severity note;

					next_state := bus_acquired;

				elsif	frame = '1' 

				then	dir <= '0';

					assert false 

					report "othermaster_fsm: bus_acquired" 
	
					severity note;

					next_state := bus_acquired;

				end if;



			when bus_acquired =>

					dir <= '1';

					frame_out <= '0';

				if	current_transaction_cycles_count > 0 	

				then	current_transaction_cycles_count := current_transaction_cycles_count - 1;

					next_state := bus_acquired;

				elsif	current_transaction_cycles_count = 0

				then 	dir <= '1';

					frame_out <= '1';

					assert false 

					report "othermaster_fsm: bus_idle" 
	
					severity note;

					next_state := bus_idle;		

				end if;	



			when bus_idle =>

					dir <= '0';

					assert false 

					report "othermaster_fsm: watching_bus_state" 
	
					severity note;

					next_state := watching_bus_state;

		end case;	

		state := next_state;

	end process othermaster_fsm;




	random_number_generator_fsm: process 

		type generator_state is (generating_random_number, waiting);
	
		variable state 						: generator_state 		:= generating_random_number;

		variable next_state 					: generator_state 		:= generating_random_number;

		variable random_number 					: integer 			:= 1;

		variable seed1 						: positive 			:= othermaster_seed1_value;

		variable seed2 						: positive 			:= othermaster_seed2_value;

		variable rand						: real;

		file random_current_transaction_cycles_count_file 	: text open write_mode is "random_current_transaction_cycles_count.out";

		variable output_line 					: line;

	begin

		case state is



			when	generating_random_number =>

				-- Since rand values are in the interval 0..1, the values are multiplicated by 1000 and rounded. 
				-- This way, an integer random value in the interval 1..1000 is obtained

				uniform(seed1, seed2, rand);

				random_number := integer(round(rand*1000.0));

				--random_number := 5; 

				if	random_number >= min_transaction_in_progress_latency

					and random_number <= max_transaction_in_progress_latency

				then	random_cycles_count := random_number;

					write(output_line, random_cycles_count);

					writeline(random_current_transaction_cycles_count_file, output_line);

					assert false 

					report "random_number_generator_fsm: waiting" 
	
					severity note;

					next_state := waiting;

				else	next_state := generating_random_number;

				end if;



			when	waiting =>

				wait until frame_out'event and frame_out = '0';

		 		assert false 

				report "random_number_generator_fsm: generating random acquisition latency" 
	
				severity note;

				next_state := generating_random_number;

		end case;	

		state := next_state;

	end process random_number_generator_fsm;



--	output_signals_driver: process 

--	begin

--		wait until pciclk'event and pciclk = '1'; 

--		frame <= frame_value;

--	end process output_signals_driver;



end V1;

