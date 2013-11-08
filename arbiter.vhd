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

--use ieee.numeric_std.all; -- for TO_UNSIGNED

use ieee.std_logic_1164.all;

entity arbiter is

	port (

		req					: in	bit;

	  	gnt					: out	bit		:= '1';

--	  	bus_transfer_cycles_counter_out		: out	integer := 0;	

	  	arb_latency_cycles_counter_out		: out	integer		:= 0;	

	  	pciclk					: in	bit

	);

end arbiter;

-- Architecture begin

architecture V1 of arbiter is


	---------------       Random number generator configuration   	---------------

	constant 	arbiter_seed1_value  		: positive		:= 14;

	constant 	arbiter_seed2_value  		: positive		:= 49;


	---------------       Bus arbitration latency configuration   	---------------

	constant	min_arbitration_latency		: positive		:= 1;

	constant	max_arbitration_latency		: positive		:= 100;




	---------------        Burst size configuration 	--------------- 

	constant 	dma_burst_size_in_cycles 	: integer 		:= 32;		-- DMA busrt size = 256 bytes (PCI-X bus)

	--constant 	dma_burst_size_in_cycles 	: integer 		:= 64;		-- DMA busrt size = 512 bytes (PCI-X bus)

	--constant	dma_burst_size_in_cycles 	: integer		:= 128;		-- DMA busrt size = 1024 bytes (PCI-X bus)

	--constant 	dma_burst_size_in_cycles 	: integer 		:= 256;		-- DMA busrt size = 2048 bytes (PCI-X bus)

	--constant 	dma_burst_size_in_cycles 	: integer 		:= 512;		-- DMA busrt size = 4096 bytes (PCI-X bus)



-- ****** In the future, constant pcilck_period should be removed a function based on the pciclk signal should be implemented

	--constant	pciclk_period 		: time 			:= 0.03030303 us; 	-- PCI 33

	--constant 	pciclk_period 		: time 			:= 0.015151515 us; 	-- PCI-X 66

	constant 	pciclk_period 		: time 			:= 0.007518797 us; 	-- PCI-X 133 

        --constant 	pciclk_period 		: time 			:= 0.003759398 us;  	-- PCI-X 266 

	--constant 	pciclk_period 		: time			:= 0.001876173 us; 	-- PCI-X 533



	---------------       Variables Declarations   	---------------

	shared	variable random_cycles_count : integer := 0;

	shared 	variable bus_transfer_cycles_counter : integer := dma_burst_size_in_cycles;

	shared 	variable total_latency_cycles : integer := 0;

	shared 	variable total_bus_transfer_cycles : integer := 0;

	shared variable latency_cycles_count : integer := 0;

	shared 	variable gnt_value : bit := '1';

	shared 	variable max_arbitration_latency_in_cycles : integer;

	-- Variables needed for arbiter FSM

	type pci_bus_state is (idle, waiting_arbitration_latency, bus_granted);

	shared variable state : pci_bus_state := idle;

	shared variable next_state : pci_bus_state := idle;

	-- Variables needed for printing out simulation statistics

	shared	variable transmission_cycles_count : natural := 0;

	shared	variable non_transmission_cycles_count : natural := 0;



-- Architecture Begin

begin


	-- Arbiter FSM

	pci_arbiter_fsm: process 

	begin

		wait until pciclk'event and pciclk = '1';

		case state is

			when idle =>

				gnt_value := '1';

				bus_transfer_cycles_counter := 0;

				latency_cycles_count := 0;

				if	req = '1' 

				then	gnt_value := '1';

					next_state := idle;

				elsif	req = '0' 

				then	--latency_cycles_count := generate_random_latency_in_cycles;

					latency_cycles_count := random_cycles_count;

					total_latency_cycles := total_latency_cycles + latency_cycles_count;

					bus_transfer_cycles_counter := dma_burst_size_in_cycles;

					--total_bus_transfer_cycles = total_bus_transfer_cycles + bus_transfer_cycles_counter;

					assert false 

					report "pci_arbiter_fsm: waiting_arbitration_latency" 
	
					severity note;

					next_state := waiting_arbitration_latency;

				end if;

			when waiting_arbitration_latency =>

				if	req = '1'

				then	next_state := idle;

				elsif 	req = '0' 

					and latency_cycles_count = 0 

				then 	gnt_value := '0';

					assert false 

					report "pci_arbiter_fsm: bus_granted" 
	
					severity note;

					next_state := bus_granted;

				elsif	req = '0' 

					and latency_cycles_count > 0 	

				then	latency_cycles_count := latency_cycles_count - 1;

					next_state := waiting_arbitration_latency;

				end if;		

			when bus_granted =>

				if	req = '0' 

					and gnt_value = '1'

					and bus_transfer_cycles_counter > 0

					and gnt_value = '0'

				then	assert false 

					report "pci_arbiter_fsm: bus_granted" 
	
					severity note;

					next_state := bus_granted;			

				elsif	req = '0' 

					and gnt_value = '1'

					and bus_transfer_cycles_counter = 0

				then	next_state := idle;

				elsif	(req = '0' 

					and bus_transfer_cycles_counter = 0)

					or req = '1'

				then	next_state := idle;

				end if;		

		end case;	

		state := next_state;

	end process pci_arbiter_fsm;

	-- FSM of Latecy Cycles Generator 

	random_number_generator_fsm: process 

		type generator_state is (idle, generating_random_number, waiting);

		variable state : generator_state := idle;

		variable next_state : generator_state := idle;

		variable random_number : integer := 1;

		variable seed1 : positive := arbiter_seed1_value;

		variable seed2 : positive := arbiter_seed2_value;

		variable rand: real;

		file random_arbitration_cycles_file : text open write_mode is "random_arbitration_cycles.out";

		variable output_line : line;

	begin

		case state is

			when idle =>

				wait until req'event and req = '0';

				assert false 

				report "generating random arbitration latency" 
	
				severity note;

				next_state := generating_random_number;

			when generating_random_number =>

				uniform(seed1, seed2, rand);

				-- Since rand values are in the interval 0..1, the values are multiplicated by 1000 and rounded. 

				-- This way, an integer random value in the interval 1..1000 is obtained

				random_number := integer(round(rand*1000.0));

				--random_number := integer(round(rand * max_arbitration_latency));

				if	random_number >= min_arbitration_latency

					and random_number <= max_arbitration_latency

				then	random_cycles_count := random_number;

					write(output_line, random_cycles_count);

					writeline(random_arbitration_cycles_file, output_line);

					next_state := waiting;

				else	next_state := generating_random_number;

				end if;


			when waiting =>

				wait until req'event and req = '0';

				next_state := generating_random_number;

		end case;	

		state := next_state;

	end process random_number_generator_fsm;


	arb_cycles_counter_out_driver: process 

	begin

		wait until pciclk'event and pciclk = '0'; 

--		bus_transfer_cycles_counter_out <= bus_transfer_cycles_counter;

		arb_latency_cycles_counter_out <= latency_cycles_count;

	end process arb_cycles_counter_out_driver;

	
	output_signals_driver: process 

	begin

		wait until pciclk'event and pciclk = '1'; 

		gnt <= gnt_value;

	end process output_signals_driver;



end V1;
