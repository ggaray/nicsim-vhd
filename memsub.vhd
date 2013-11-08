--    NICSim-vhd: A VHDL-based modelling and simulation of NIC's buffers
--    Copyright (C) 2013 Godofredo R. Garay <godofredo.garay (-at-) gmail.com>

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

entity memsub is

	port (

		irdy						: in		bit;

		trdy						: out		bit		:= '1';

		frame						: inout		std_logic	:= 'Z';

		AD						: in		bit;

		target_latency_cycles_counter_out		: out		integer		:= 0;	-- Always equals to 1 cycle

		pciclk						: in 		bit

	);

end memsub;

architecture V1 of memsub is


	---------------       Variables Declarations   	---------------

	signal 		 	trdy_value	 			: bit 		:= '1';

	shared	variable 	random_cycles_count 			: integer 	:= 0;

	shared variable 	target_latency_cycles_count 		: integer 	:= 0;


	-- Variables needed for Memsub FSM

	type 			memsub_state is (waiting_memory_write_transaction_start, target_ready);

	shared variable 	state 			: memsub_state 		:= waiting_memory_write_transaction_start; --Initial state = idle

	shared variable 	next_state 		: memsub_state 		:= waiting_memory_write_transaction_start;


begin

	trdy <= trdy_value;

	memsub_fsm: process 

	begin

		wait until pciclk'event and pciclk = '1';

		case state is

			when waiting_memory_write_transaction_start =>

				if	frame = '1'

					or (frame = '0'

					and AD = '1')

				then	trdy_value <= '1';

					next_state := waiting_memory_write_transaction_start;

				elsif	frame = '0' 	

					and AD = '0'

				then	trdy_value <= '0';

					assert false 

					report "memsub_fsm: target_ready" 
	
					severity note;

					next_state := target_ready;

				end if; 	


	
			when target_ready =>

				if	frame = '0'

				then	trdy_value <= '0';

					next_state := target_ready;

				elsif	frame = '1'

				then	trdy_value <= '1';

					assert false 

					report "memsub_fsm: waiting_memory_write_transaction_start" 
	
					severity note;

					next_state := waiting_memory_write_transaction_start;

				end if;

		end case;	

		state := next_state;

	end process memsub_fsm;




	target_latency_cycles_counter_fsm: process 

	-- Variables needed for target_latency_cycles_counter_fsm

		type 		target_latency_cycles_counter_fsm_state is 

								(idle, incrementing_target_latency_cycles_count, waiting_transaction_end);

		variable 	state 		: target_latency_cycles_counter_fsm_state 	:= idle;

		variable 	next_state 	: target_latency_cycles_counter_fsm_state 	:= idle;

	begin

		wait until pciclk'event and pciclk = '1';

		case state is



			when idle =>

				target_latency_cycles_count := 0;

				if	frame = '1' 

				then	next_state := idle;

				elsif	frame = '0' 

					and AD = '0'

				then	target_latency_cycles_count := target_latency_cycles_count + 1;

					assert false 

					report "target_latency_cycles_counter_fsm: incrementing_target_latency_cycles_count" 
	
					severity note;

					next_state := incrementing_target_latency_cycles_count;

				end if;



			when incrementing_target_latency_cycles_count =>

				if	frame = '0' 

					and AD = '0'

					and trdy_value = '1'

				then	target_latency_cycles_count := target_latency_cycles_count + 1;

					next_state := incrementing_target_latency_cycles_count;
	
				elsif	frame = '0' 

					and AD = '0'

					and trdy_value = '0'

				then	target_latency_cycles_count := 0;

					assert false 

					report "target_latency_cycles_counter_fsm: waiting_transaction_end" 
	
					severity note;

					next_state := waiting_transaction_end;

				end if;	

			when waiting_transaction_end =>

				if	frame = '0' 

					and AD = '0'

				then	next_state := waiting_transaction_end;

				elsif	frame = '1' 

					and AD = '1'

				then	next_state := idle;

				end if;


		end case;	

		state := next_state;

	end process target_latency_cycles_counter_fsm;




	acquisition_latency_cycles_counter_out_driver: process 

	begin

		wait until pciclk'event and pciclk = '0'; 

		target_latency_cycles_counter_out <= target_latency_cycles_count;

	end process acquisition_latency_cycles_counter_out_driver;


--	output_signals_driver: process 

--	begin

--		wait until pciclk'event and pciclk = '1'; 

--		trdy <= trdy_value;

--	end process output_signals_driver;


end V1;

