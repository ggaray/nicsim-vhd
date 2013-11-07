--    <one line to give the program's name and a brief idea of what it does.>
--    Copyright (C) 2013 Godofredo R. Garay <godofredo_garay ("at") gmail.com>

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

use ieee.numeric_std.all;

use ieee.math_real.all;

use ieee.std_logic_1164.all;



entity nicctrl is

	port (

		transfer_start_req				: in		bit;

		transfer_end					: out		bit		:= '0';

		req						: out		bit		:= '1';

		gnt						: in		bit;

		frame						: inout		std_logic	:= 'Z';

		irdy						: out		bit		:= '1';

		trdy						: in		bit;

		AD						: out		bit		:= '0';

		payload_size_in_data_blocks			: in		integer;

		payload_transfer_req				: out		bit		:= '1';

		descriptor_transfer_req				: out		bit		:= '1';

		payload_transfer_end				: in		bit;

		descriptor_transfer_end				: in		bit;		

		payload_transfer_aborted			: in		bit;

		resume_aborted_payload_transfer			: out		bit		:= '1';

		descriptor_transfer_aborted			: in		bit;

		resume_aborted_descriptor_transfer		: out		bit		:= '1';

		acq_latency_cycles_counter_out			: out		integer		:= 0;

		nic_proc_latency_cycles_counter_out		: out		integer		:= 0;

		nicclk						: in 		bit;

		pciclk						: in 		bit

	);

end nicctrl;



architecture V1 of nicctrl is



	---------------       NIC processing latency configuration   	---------------

	constant 	packet_identification_latency 		: time 		:= 4.72631578947368 us;
	
	constant 	crc_computation_latency 		: time 		:= 0 us;

	--constant 	packet_identification_latency 		: time 		:= 0.3 us;
	
	--constant 	crc_computation_latency 		: time 		:= 0.2 us;


	-- Baseline for NIC latency used in all the experiment (burst size = 256 bytes, jumbo pkts, 10-GigE, NIC latency = 5 us )

	--constant 	protocol_offload_latency 		: time 		:= 0 us;  



	--------------------------------------------------------------------------------------
	-- Extra overhead for Jumbo packets, 10 Gigabit Ethernet, PCI-X 133/64 bus
	--------------------------------------------------------------------------------------

	--constant 	protocol_offload_latency 		: time 		:= 2.199248123 us; -- Extra overhead for burst size = 512 bytes, jumbo pkts

	--constant 	protocol_offload_latency 		: time 		:= 3.310150379 us;  -- Extra overhead for burst size = 1024 bytes, jumbo pkts

	--constant 	protocol_offload_latency 		: time 		:= 3.800751884 us;  -- Extra overhead for burst size = 2048 bytes, jumbo pkts

	--constant 	protocol_offload_latency 		: time 		:= 4.043233087 us;  -- Extra overhead for burst size = 4096 bytes, jumbo pkts
	--------------------------------------------------------------------------------------



	--------------------------------------------------------------------------------------
	-- Extra overhead for max Ethernet packet size, PCI-X 133/64 bus, Gigabit Ethernet 
	--------------------------------------------------------------------------------------

	--constant 	protocol_offload_latency 		: time 		:= 3.696992484 us;  -- Extra overhead for burst size = 256 bytes, max size pkts

	--constant 	protocol_offload_latency 		: time 		:= 4.136842109 us;  -- Extra overhead for burst size = 512 bytes, max size pkts
	--------------------------------------------------------------------------------------



	--------------------------------------------------------------------------------------
	-- Extra overhead for max Ethernet packet size, PCI-X 133/64 bus, 10 Gigabit Ethernet
	--------------------------------------------------------------------------------------

	--constant 	protocol_offload_latency 		: time 		:= 3.619924815 us;  -- Extra overhead for burst size = 256 bytes, max size pkts

	--constant 	protocol_offload_latency 		: time 		:= 4.010902259 us;  -- Extra overhead for burst size = 512 bytes, max size pkts

	--constant 	protocol_offload_latency 		: time 		:= 4.131203011 us;  -- Extra overhead for burst size = 1024 bytes, max size pkts

	--constant 	protocol_offload_latency 		: time 		:= 4.260902259 us;  -- Extra overhead for burst size = 4096 bytes, max size pkts
	--------------------------------------------------------------------------------------



	--------------------------------------------------------------------------------------
	-- Extra overhead for min Ethernet packet size, PCI-X 133/64 bus, burst size = 256 bytes
	--------------------------------------------------------------------------------------

	--constant 	protocol_offload_latency 		: time 		:= 4.046992485 us;  	-- Extra overhead for Ethernet, min size pkts

	--constant 	protocol_offload_latency 		: time 		:= 4.289473688 us;  	-- Extra overhead for Fast Ethernet, min size pkts

	--constant 	protocol_offload_latency 		: time 		:= 4.161654139 us;  	-- Extra overhead for Gigabit Ethernet, min size pkts

	--constant 	protocol_offload_latency 		: time 		:= 3.48120301 us;  	-- Extra overhead for 10 Gigabit Ethernet, min size pkts
	--------------------------------------------------------------------------------------



	--------------------------------------------------------------------------------------
	-- Extra overhead for min Ethernet packet size, line speed = 100 Mbps, PCI-X 133/64 bus, burst size = 256 bytes 
	--------------------------------------------------------------------------------------

	--constant 	protocol_offload_latency 		: time 		:= 19.105263177 us;  	-- Extra overhead for NIC latency = 20 us

	--constant 	protocol_offload_latency 		: time 		:= 14.016917292 us;  	-- Extra overhead for NIC latency = 15 us

	--constant 	protocol_offload_latency 		: time 		:= 9.992481218 us;  	-- Extra overhead for NIC latency = 10 us

	--constant 	protocol_offload_latency 		: time 		:= 4.289473688 us;  	-- Extra overhead for NIC latency = 5.2 us

	constant 	protocol_offload_latency 		: time 		:= 0 us;  		-- Extra overhead for NIC latency = 0.9 us
	--------------------------------------------------------------------------------------



	--------------------------------------------------------------------------------------
	-- Extra overhead for min Ethernet packet size, line speed = 100 Mbps, NIC latency = 5.2 us, burst size = 256 bytes 
	--------------------------------------------------------------------------------------

	--constant 	protocol_offload_latency 		: time 		:=  us;  		-- Extra overhead for NIC latency = 20 us

	--constant 	protocol_offload_latency 		: time 		:=  us;  		-- Extra overhead for NIC latency = 15 us

	--constant 	protocol_offload_latency 		: time 		:=  3.805303096 us;  	-- Extra overhead for PCI 66/64

	--constant 	protocol_offload_latency 		: time 		:= 2.98787881 us;  	-- Extra overhead for PCI 33/32
	--------------------------------------------------------------------------------------





	-- ***To be removed

	--constant	min_acquisition_latency 		: positive 	:= 1;

	--constant 	max_acquisition_latency 		: positive 	:= 80;


	--constant 	min_acquisition_latency 		: positive 	:= 1;

	--constant 	max_acquisition_latency 		: positive 	:= 80;



	---------------       Random number generator configuration   	---------------

	-- ***To be removed

	--Run 1

	--constant 	seed1_value  	: positive	:= 34;

	--constant 	seed2_value  	: positive	:= 45;

	--Run 2

	--constant 	seed1_value  	: positive	:= 329;

	--constant 	seed2_value  	: positive	:= 6;

	--Run 3

	--constant 	seed1_value 	: positive	:= 105;

	--constant 	seed2_value  	: positive	:= 134;

	--Run 4

	--constant 	seed1_value  	: positive	:= 4;

	--constant 	seed2_value  	: positive	:= 3;

	--Run 5

	--constant 	seed1_value  	: positive	:= 8;

	--constant 	seed2_value  	: positive	:= 4;


-- ****** In the future, constant pcilck_period should be removed a function based on the pciclk signal should be implemented

	--constant	pciclk_period 	: time 		:= 0.03030303 us; 		-- PCI 33 

	--constant	pciclk_period 	: time 		:= 0.015151515 us; 		-- PCI 66

	constant	pciclk_period 	: time 		:= 0.007518797 us; 		-- PCI-X 133 

	--constant	pciclk_period 	: time 		:= 0.003759398 us; 		-- PCI-X 266 

	--constant	pciclk_period 	: time 		:= 0.001876173 us; 		-- PCI-X 533



	--constant tpd : time := 1 ns;  ****** To be removed



	---------------       Variables Declarations   	---------------

	shared	variable 	random_cycles_count 				: integer 	:= 0;

	shared variable		acq_latency_cycles_count 			: integer	:= 0;

	shared variable 	nic_processing_latency_cycles_count 		: integer	:= 0;

	-- A variable is declared for each output signal. 	

	shared	variable 	transfer_end_value 				: bit		:= '0' ;  

	shared	variable 	req_value 					: bit		:= '1';  

	shared	variable 	irdy_value 					: bit 		:= '1';  

	signal			AD_value	 				: bit 		:= '1';  

	--shared	variable AD_value 					: bit := '1';  

	--shared	variable frame_value 					: bit := '1';  

	shared	variable 	payload_transfer_req_value 			: bit 		:= '1';  

	shared	variable 	descriptor_transfer_req_value 			: bit 		:= '1';  

	shared	variable 	resume_aborted_payload_transfer_value 		: bit 		:= '1';

	shared	variable 	resume_aborted_descriptor_transfer_value 	: bit 		:= '1';

	-- Variables needed for printing out simulation statistics

	shared	variable 	total_transmission_cycles_count 		: natural 	:= 0;

	shared	variable 	total_acquisition_cycles_count 			: natural 	:= 0;

	shared	variable 	transmission_cycles_count 			: natural 	:= 0;

	shared	variable 	non_transmission_cycles_count 			: natural 	:= 0;

	shared	variable 	max_non_transmission_period 			: natural 	:= 0;

	-- These signals are used to handle frame bidirectional port

	signal			dir 						: std_logic 	:= '0'; 	-- '0' reading, '1' driving

	signal			frame_value 					: std_logic 	:= 'Z';

	-- FSM initial state: idle

	type nicctrl_state is  (idle, 

				processing_packet, 

				waiting_arbitration_latency_for_payload_transfer, 

				waiting_acquisition_latency_for_payload_transfer,

				waiting_initial_target_latency_for_payload_transfer, 

				transferring_payload, 

				waiting_arbitration_latency_for_descriptor_transfer, 

				waiting_acquisition_latency_for_descriptor_transfer, 

				waiting_initial_target_latency_for_descriptor_transfer, 

				transferring_descriptor, 

				waiting_arbitration_latency_for_resuming_payload_transfer,

				waiting_acquisition_latency_for_resuming_payload_transfer, 

				waiting_initial_target_latency_for_resuming_payload_transfer, 

				resuming_aborted_payload_transfer, 

				waiting_arbitration_latency_for_resuming_descriptor_transfer,

				waiting_acquisition_latency_for_resuming_descriptor_transfer, 

				waiting_initial_target_latency_for_resuming_descriptor_transfer, 

				resuming_aborted_descriptor_transfer, 

				ending_transaction); 


	shared variable 	state 		: nicctrl_state 	:= idle; 

	shared variable	 	next_state 	: nicctrl_state 	:= idle; 



	---------------       Auxiliary Functions   	---------------

	function compute_crc_latency (eth_frame_size : in integer) return time is

		variable result : time := crc_computation_latency; -- In this version, it is a fixed value. 
								   -- In future version, it should be replace for a formula.
								   --So crc latency should be computed as a function of eth_frame_size

	begin

		return result;

	end function compute_crc_latency;


	function compute_offload_latency (eth_frame_size : in integer) return time is

		variable result : time := protocol_offload_latency; -- In this version, it is a fixed value
								   -- In future version, it should be replace for a formula.
								   --So offload latency should be computed as a function of eth_frame_size

	begin

		return result;

	end function compute_offload_latency;


	function acquisition_latency return time is

		variable result : time;

	begin

		result := pciclk_period * 2;

		return result;

	end function acquisition_latency;



	---------------       Architecture Begin   	---------------
  

begin

	frame <= frame_value when (dir = '1') else 'Z';

	AD <= AD_value;

	nicctrl_fsm: process 

		variable my_line : line;

	begin

		--wait until pciclk'event and pciclk = '1';

		wait until nicclk'event and nicclk = '1';

		case state is

			when 	idle =>

				transfer_end_value 				:= '0';

				req_value 					:= '1';

				irdy_value 					:= '1';

				--dir 						<= '0';

				--frame_value 					:= '1';

				payload_transfer_req_value 			:= '1';

				descriptor_transfer_req_value 			:= '1';	

				resume_aborted_payload_transfer_value 		:= '1';

				resume_aborted_descriptor_transfer_value 	:= '1';

				--wait for pciclk_period * 2;

--				wait until (transfer_start_req'event 

--						and transfer_start_req = '0');
				
				--wait until transfer_start_req = '0';

				if	transfer_start_req = '1'

					and payload_transfer_end = '0' 

					and payload_transfer_aborted = '0' 

					and descriptor_transfer_end = '0' 

					and descriptor_transfer_aborted = '0'

				then	next_state := idle;
			
				elsif	transfer_start_req = '0' 

					and payload_transfer_end = '0' 

					and descriptor_transfer_end = '0' 

					and payload_transfer_aborted = '0' 

					and descriptor_transfer_aborted = '0' 

				then	assert false 

					report "nicctrl_fsm: processing_packet" 
	
					severity note;

					next_state := processing_packet;

				elsif	transfer_start_req = '0' 

					and gnt = '1'

					and payload_transfer_end = '1'

					and descriptor_transfer_end = '0' 

					and payload_transfer_aborted = '0' 

					and descriptor_transfer_aborted = '0'

				then	assert false 

					report "nicctrl_fsm: waiting_arbitration_latency_for_descriptor_transfer" 
	
					severity note;

					next_state := waiting_arbitration_latency_for_descriptor_transfer;

				elsif	transfer_start_req = '0' 

					and gnt = '1'  

					and payload_transfer_aborted = '1' 

					and payload_transfer_req_value = '1'

					and payload_transfer_end = '0' 

					and descriptor_transfer_end = '0' 

					and descriptor_transfer_aborted = '0' 
		-- Duda aqui 
					then	req_value := '0';

					--resume_aborted_payload_transfer_value := '0'; 

					assert false 

					report "nicctrl_fsm: waiting_arbitration_latency_for_resuming_payload_transfer" 
	
					severity note;

					--next_state := resuming_aborted_payload_transfer;

					next_state := waiting_arbitration_latency_for_resuming_payload_transfer;

				elsif	transfer_start_req = '0' 

					and descriptor_transfer_aborted = '1'

					and payload_transfer_end = '0' 

					and descriptor_transfer_end = '0' 

					and payload_transfer_aborted = '0' 

				then	assert false 

					report "nicctrl_fsm: resuming_aborted_descriptor_transfer" 
	
					severity note;

					next_state := resuming_aborted_descriptor_transfer;

				elsif	descriptor_transfer_end = '1'

					and transfer_start_req = '0' 

				then	assert false 

					report "nicctrl_fsm: ending_transaction" 
	
					severity note;

					next_state := ending_transaction;

				else	assert false 

					report "An illegal state has occurred in nicctrl_fsm:. " 
	
					severity note;

				end if;
		


			when 	processing_packet =>

				if	transfer_start_req = '0'

				then 	--wait for nic_service_time;

					wait for packet_identification_latency;

					wait for compute_crc_latency (payload_size_in_data_blocks);

					wait for compute_offload_latency (payload_size_in_data_blocks);

					-- Once the processing for a single packet is completed, the variable nic_processing_latency_cycles_count is reset. 

					-- This variable will be increased again for the next packet. See process nic_processing_latency_cycles_counter. 

					nic_processing_latency_cycles_count := 0;

					assert false 

					report "nicctrl_fsm: waiting_arbitration_latency_for_payload_transfer" 
	
					severity note;

					next_state := waiting_arbitration_latency_for_payload_transfer;
	
				elsif	transfer_start_req = '1'

				then	next_state := idle;

				end if;
	


			when 	waiting_arbitration_latency_for_payload_transfer =>

				--wait for pciclk_period * 2;

				-- Wait for arbitration latency

				if	transfer_start_req = '1'

				then	next_state := idle;

				-- If gnt = '0' due to a current transaction has not been complete yet, we keep waiting in this state until gnt = '0'

				elsif	gnt = '0'

				then	next_state := waiting_arbitration_latency_for_payload_transfer;

				-- Bus is requested only if gnt = '1'

				elsif	gnt = '1' 

				then 	req_value := '0'; 

					wait until gnt = '0';

					assert false 

					report "nicctrl_fsm: waiting_acquisition_latency_for_payload_transfer" 
	
					severity note;

					next_state := waiting_acquisition_latency_for_payload_transfer;

				end if;



			when 	waiting_acquisition_latency_for_payload_transfer  =>

				--wait for pciclk_period * 2;

				-- If PCI/PCI-X bus is not idle due to the current transaction has not being completed, we keep waiting until the bus is idle 

				if	transfer_start_req = '1'

				then	next_state := idle;

				elsif	frame = '0'

				then	dir <= '0';

					next_state := waiting_acquisition_latency_for_payload_transfer;

				elsif	frame = 'Z'

				then	dir <= '1';

					frame_value <= '0';

					--AD_value := '0';

					AD_value <= '0';

					assert false 

					report "nicctrl_fsm: waiting_initial_target_latency_for_payload_transfer" 
	
					severity note;

					next_state := waiting_initial_target_latency_for_payload_transfer;

				elsif	frame = '1'

				then	dir <= '0';

					wait for pciclk_period;

					dir <= '1';

					frame_value <= '0';

					--AD_value := '0';

					AD_value <= '0';

					assert false 

					report "nicctrl_fsm: waiting_initial_target_latency_for_payload_transfer" 
	
					severity note;

					next_state := waiting_initial_target_latency_for_payload_transfer;

				end if;
				

	
			when 	waiting_initial_target_latency_for_payload_transfer  =>

				if	trdy = '1'

				then	next_state := waiting_initial_target_latency_for_payload_transfer;

				elsif	trdy = '0'

				then	payload_transfer_req_value := '0'; 

					irdy_value := '0';

					assert false 

					report "nicctrl_fsm: transferring_payload" 
	
					severity note;

					next_state := transferring_payload;

				end if;



			when 	transferring_payload =>

				--if	transfer_start_req = '0' 

				--then	payload_transfer_req_value := '0';

				--wait until (payload_transfer_end'event 

					--or payload_transfer_aborted'event);

				if	transfer_start_req = '1'

				then	next_state := idle;

				elsif	gnt = '1' 

					or (gnt = '0' 

					and payload_transfer_end = '1') 

					or (gnt = '0'

					and payload_transfer_aborted = '1')

				then	assert false 

					report "nicctrl_fsm: idle" 
	
					severity note;

--aqui

					--ad_value := '1';

					AD_value <= '1';

					--dir <= '0';

					dir <= '1';

					frame_value <= '1';

					wait for pciclk_period;

					dir <= '0';

					next_state := idle;

				-- In the normal scenario, we keep waiting in this stage until the rising edge of payload_transfer_end

				elsif 	gnt = '0' 

					and payload_transfer_end = '0' 

				then	next_state := transferring_payload;

				end if;



			when 	waiting_arbitration_latency_for_descriptor_transfer =>

				-- This delay is required for syncronization

				--wait for pciclk_period * 2;

				-- Wait for arbitration latency

				if	transfer_start_req = '1'

				then	assert false 

					report "nicctrl_fsm: idle" 
	
					severity note;

					next_state := idle;

				-- If gnt = '0' due to a current transaction not complete yet, we keep waiting in this state until gnt = '0'

				elsif	gnt = '0'

				then	next_state := waiting_arbitration_latency_for_descriptor_transfer;

				-- Bus is requested only if gnt = '1'

				elsif	gnt = '1' 

				then 	req_value := '0'; 

					wait until gnt = '0';

					assert false 

					report "nicctrl_fsm: waiting_acquisition_latency_for_descriptor_transfer" 
	
					severity note;

					next_state := waiting_acquisition_latency_for_descriptor_transfer;

				end if;



			when 	waiting_acquisition_latency_for_descriptor_transfer =>

				--if	transfer_start_req = '1'

				--then	next_state := idle;

				--elsif	frame = '0'

				--then	dir <= '0';

				--	next_state := waiting_acquisition_latency_for_descriptor_transfer;

				--elsif	frame = '1'

				--then	dir <= '1';

				--	frame_value <= '0';

				--	assert false 

				--	report "nicctrl_fsm: waiting_initial_target_latency_for_descriptor_transfer" 
	
				--	severity note;

				--	next_state := waiting_initial_target_latency_for_descriptor_transfer;

				--end if;				


				-- If PCI/PCI-X bus is not idle due to the current transaction has not being completed, we keep waiting until the bus is idle 

				if	transfer_start_req = '1'

				then	assert false 

					report "nicctrl_fsm: waiting_acquisition_latency_for_descriptor_transfer" 
	
					severity note;

					next_state := idle;

				elsif	frame = '0'

				then	dir <= '0';

					next_state := waiting_acquisition_latency_for_descriptor_transfer;

				elsif	frame = 'Z'

				then	dir <= '1';

					frame_value <= '0';

					--AD_value := '0';

					AD_value <= '0';

					assert false 

					report "nicctrl_fsm: waiting_initial_target_latency_for_descriptor_transfer" 
	
					severity note;

					next_state := waiting_initial_target_latency_for_descriptor_transfer;

				elsif	frame = '1'

				then	dir <= '0';

					wait for pciclk_period;

					dir <= '1';

					frame_value <= '0';

					--AD_value := '0';

					AD_value <= '0';

					assert false 

					report "nicctrl_fsm: waiting_initial_target_latency_for_descriptor_transfer" 
	
					severity note;

					next_state := waiting_initial_target_latency_for_descriptor_transfer;

				end if;



			when 	waiting_initial_target_latency_for_descriptor_transfer =>

				if	transfer_start_req = '1'

				then	assert false 

					report "nicctrl_fsm: transferring_descriptor" 
	
					severity note;

					next_state := idle;

				-- We keep waiting in this state until trdy is asserted.

				elsif	trdy = '1'

				then	next_state := waiting_initial_target_latency_for_descriptor_transfer;

				-- Here trdy is asserted.

				elsif	trdy = '0'

				then	descriptor_transfer_req_value := '0'; 

					irdy_value := '0';

					assert false 

					report "nicctrl_fsm: transferring_descriptor" 
	
					severity note;

					next_state := transferring_descriptor;

				end if;



			when 	transferring_descriptor =>

				-- If signal transfer_end is received we leave this stage.

				if	transfer_start_req = '1'

				then	next_state := idle;

				-- If grant is de-asserted or descriptor transfer is aborted or descriptor transfer end we leave this stage.

				elsif	 gnt = '1'

					or (gnt = '0' 

					and descriptor_transfer_end = '1')

					or (gnt = '0'

					and descriptor_transfer_aborted = '1') 

					then 	
--aqui

					--ad_value := '1';

					AD_value <= '1';

					--dir <= '0';

					dir <= '1';

					frame_value <= '1';

					wait for pciclk_period;

					dir <= '0';

					assert false 

					report "nicctrl_fsm: idle" 
	
					severity note;

					next_state := idle;

				-- Keep waiting in this stage until the rising edge of descriptor_transfer_end

				elsif 	gnt = '0' 

					and descriptor_transfer_end = '0' 

				then 	next_state := transferring_descriptor; 

				end if;



			when 	waiting_arbitration_latency_for_resuming_payload_transfer =>

				--wait for pciclk_period * 2;

				-- Wait for arbitration latency

				if	transfer_start_req = '1'

				then	assert false 

					report "nicctrl_fsm: idle" 
	
					severity note;

					next_state := idle;

				-- If gnt = '0' due to a current transaction not complete yet, we keep waiting in this state until gnt = '0'

				elsif	gnt = '0'

				then	next_state := waiting_arbitration_latency_for_resuming_payload_transfer;

				-- Bus is requested only if gnt = '1'

				elsif	gnt = '1' 

				then 	req_value := '0'; 

					wait until gnt = '0';

					assert false 

					report "nicctrl_fsm: waiting_acquisition_latency_for_resuming_payload_transfer" 
	
					severity note;

					next_state := waiting_acquisition_latency_for_resuming_payload_transfer;

				end if;



			when	waiting_acquisition_latency_for_resuming_payload_transfer =>

				--if	transfer_start_req = '1'

				--then	next_state := idle;

				--elsif	frame = '0'

				--then	dir <= '0';

				--	next_state := waiting_acquisition_latency_for_resuming_payload_transfer;

				--elsif	frame = '1'

				--then	dir <= '1';

				--	frame_value <= '0';

				--	assert false 

				--	report "nicctrl_fsm: waiting_initial_target_latency_for_resuming_payload_transfer" 
	
				--	severity note;

				--	next_state := waiting_initial_target_latency_for_resuming_payload_transfer;

				--end if;		


				-- If PCI/PCI-X bus is not idle due to the current transaction has not being completed, we keep waiting until the bus is idle 

				if	transfer_start_req = '1'

				then	assert false 

					report "nicctrl_fsm: idle" 
	
					severity note;

					next_state := idle;

				elsif	frame = '0'   -- Bus is busy

				then	dir <= '0';

					next_state := waiting_acquisition_latency_for_resuming_payload_transfer;

				elsif	frame = 'Z'

				then	dir <= '1';

					frame_value <= '0';

					--AD_value := '0';

					AD_value <= '0';

					assert false 

					report "nicctrl_fsm: waiting_initial_target_latency_for_resuming_payload_transfer" 
	
					severity note;

					next_state := waiting_initial_target_latency_for_resuming_payload_transfer;

				elsif	frame = '1'

				then	dir <= '0';

					wait for pciclk_period;

					dir <= '1';

					frame_value <= '0';

					--AD_value := '0';

					AD_value <= '0';

					assert false 

					report "nicctrl_fsm: waiting_initial_target_latency_for_resuming_payload_transfer" 
	
					severity note;

					next_state := waiting_initial_target_latency_for_resuming_payload_transfer;

				end if;



			when	waiting_initial_target_latency_for_resuming_payload_transfer => 

				if	trdy = '1'

				then	next_state := waiting_initial_target_latency_for_resuming_payload_transfer;

				elsif	trdy = '0'

				then	--payload_transfer_req_value := '0'; 

					-- Here, resume_aborted_payload_transfer is asserted

					irdy_value := '0';

					resume_aborted_payload_transfer_value := '0'; 

					assert false 

					report "nicctrl_fsm: resuming_aborted_payload_transfer" 
	
					severity note;

					next_state := resuming_aborted_payload_transfer;

				end if;



			when 	resuming_aborted_payload_transfer =>

				if	transfer_start_req = '1'

				then	next_state := idle;

				elsif	gnt = '1' 

					or (gnt = '0' 

					and payload_transfer_end = '1') 

					or (gnt = '0'

					and payload_transfer_aborted = '1')
	-- *** Duda aqui ***
				then	AD_value <= '1';   

					--dir <= '0';

					dir <= '1';

					frame_value <= '1';

					wait for pciclk_period;

					dir <= '0';

					assert false 

					report "nicctrl_fsm: idle" 
	
					severity note;

					next_state := idle;

				-- Keep waiting in this stage until the rising edge of payload_transfer_end

				elsif 	gnt = '0' 

					and payload_transfer_end = '0' 

				then 	next_state := resuming_aborted_payload_transfer;

				end if;



			when 	waiting_arbitration_latency_for_resuming_descriptor_transfer =>

				if	transfer_start_req = '1'

				then	next_state := idle;

				elsif	transfer_start_req = '1'

				then	next_state := idle;

				-- Keep waiting if conditions are not ok

				elsif	gnt = '0' 

					--and irdy_value = '1'

					--and payload_transfer_end = '0'

					--and descriptor_transfer_end = '0'

					--and descriptor_transfer_aborted = '1')

				then	next_state := waiting_arbitration_latency_for_resuming_descriptor_transfer;

				-- req is asserted if conditions are ok

				elsif	gnt = '1' 

					--and irdy_value = '1'

					--and payload_transfer_end = '0'

					--and descriptor_transfer_end = '0'

					--and descriptor_transfer_aborted = '1'

				then 	req_value := '0'; 

					wait until gnt = '0';

					-- Wait for acquisition latency

					wait for acquisition_latency;

					-- NIC is ready for data-phase transfers

					--irdy_value := '0';

					--next_state := resuming_aborted_descriptor_transfer;

					next_state := waiting_acquisition_latency_for_resuming_descriptor_transfer;

				end if;



			when	waiting_acquisition_latency_for_resuming_descriptor_transfer =>

				--if	transfer_start_req = '1'

				--then	next_state := idle;

				--elsif	frame = '0'

				--then	dir <= '0';

				--	next_state := waiting_acquisition_latency_for_resuming_descriptor_transfer;

				--elsif	frame = '1'

				--then	dir <= '1';

				--	frame_value <= '0';

				--	assert false 

				--	report "nicctrl_fsm: waiting_initial_target_latency_for_resuming_descriptor_transfer" 
	
				--	severity note;

				--	next_state := waiting_initial_target_latency_for_resuming_descriptor_transfer;

				--end if;	


				if	transfer_start_req = '1'

				then	next_state := idle;

				elsif	frame = '0'

				then	dir <= '0';

					next_state := waiting_acquisition_latency_for_resuming_descriptor_transfer;

				elsif	frame = 'Z'

				then	dir <= '1';

					frame_value <= '0';

					--AD_value := '0';

					AD_value <= '0';

					assert false 

					report "nicctrl_fsm: waiting_initial_target_latency_for_resuming_descriptor_transfer" 
	
					severity note;

					next_state := waiting_initial_target_latency_for_resuming_descriptor_transfer;

				elsif	frame = '1'

				then	dir <= '0';

					wait for pciclk_period;

					dir <= '1';

					frame_value <= '0';

					--AD_value := '0';

					AD_value <= '0';

					assert false 

					report "nicctrl_fsm: waiting_initial_target_latency_for_resuming_descriptor_transfer" 
	
					severity note;

					next_state := waiting_initial_target_latency_for_resuming_descriptor_transfer;

				end if;



			when	waiting_initial_target_latency_for_resuming_descriptor_transfer =>

				if	trdy = '1'

				then	next_state := waiting_initial_target_latency_for_resuming_descriptor_transfer;

				elsif	trdy = '0'

				then	resume_aborted_descriptor_transfer_value := '0'; 

					irdy_value := '0';

					-- Signal resume_aborted_payload_transfer_value is asserted

					resume_aborted_descriptor_transfer_value := '0'; 

					assert false 

					report "nicctrl_fsm: resuming_aborted_descriptor_transfer" 
	
					severity note;

					next_state := resuming_aborted_descriptor_transfer;

				end if;



			when 	resuming_aborted_descriptor_transfer =>

				--resume_aborted_descriptor_transfer_value := '0';

				if	transfer_start_req = '1'

				then	next_state := idle;

				elsif	gnt = '1' 

					or (gnt = '0' 

					and descriptor_transfer_end = '1') 

					or (gnt = '0'

					and descriptor_transfer_aborted = '1')

				then	

--aqui

					--ad_value := '1';

					AD_value <= '1';

					--dir <= '0';

					dir <= '1';

					frame_value <= '1';

					wait for pciclk_period;

					dir <= '0';

					next_state := idle;

				-- Keep waiting in this stage until the rising edge of payload_transfer_end

				elsif 	gnt = '0' 

					and descriptor_transfer_end = '0' 

				then 	next_state := resuming_aborted_descriptor_transfer;

				end if;



			when	ending_transaction =>

				-- Signal transfer_end is generated if all conditions are ok

				if	transfer_start_req = '0'

					--transfer_start_req = '1'

					--or (gnt = '1' 

					--and descriptor_transfer_end = '0')

					--and	payload_transfer_end = '0'

					--and	payload_transfer_aborted = '0' 

					--and	descriptor_transfer_aborted = '0'

				then	transfer_end_value := '1';

					--wait for pciclk_period * 8;

					--assert false 
	
					--report "nicctrl_fsm: idle" 
	
					--severity note;

					--next_state := idle;

					next_state := ending_transaction;

				-- Keep waiting in this stage if all condition are not ok

				elsif	gnt = '1' 

				and	descriptor_transfer_end = '1'

				--and 	payload_transfer_end = '0'

				--and	payload_transfer_aborted = '0' 

				--and	descriptor_transfer_aborted = '0')

				then	next_state := ending_transaction;

				elsif	transfer_start_req = '1'

				then	assert false 
	
					report "nicctrl_fsm: idle" 
	
					severity note;

					next_state := idle;

				end if;

		end case; 

		state := next_state;

	end process nicctrl_fsm;


	-- FSM of Latecy Cycles Generator 

--	random_number_generator_fsm: process 

--		type generator_state is (idle, generating_random_number, waiting);

--		variable state : generator_state := idle;

--		variable next_state : generator_state := idle;

--		variable random_number : integer := 1;

--		variable seed1 : positive := seed1_value;

--		variable seed2 : positive := seed2_value;

--		variable rand: real;

--		file random_acquisition_cycles_file : text open write_mode is "random_acquisition_cycles.out";

--		variable output_line : line;

--	begin

--		case state is

--			when	idle =>

--				wait until gnt'event and gnt = '0';

--				assert false 

--				report "generating random acquisition latency" 
	
--				severity note;

--				next_state := generating_random_number;

--			when	generating_random_number =>

				-- Since rand values are in the interval 0..1, the values are multiplicated by 1000 and rounded. 
				-- This way, an integer random value in the interval 1..1000 is obtained

--				uniform(seed1, seed2, rand);

--				random_number := integer(round(rand*1000.0));

				--random_number := 5; 

--				if	random_number >= min_acquisition_latency

--					and random_number <= max_acquisition_latency

--				then	random_cycles_count := random_number;

--					write(output_line, random_cycles_count);

--					writeline(random_acquisition_cycles_file, output_line);

--					next_state := waiting;

--				else	next_state := generating_random_number;

--				end if;

--			when	waiting =>

--				wait until gnt'event and gnt = '0';

--				next_state := generating_random_number;

--		end case;	

--		state := next_state;

--	end process random_number_generator_fsm;


	output_signals_driver: process 

	begin

		--wait until pciclk'event and pciclk = '1'; 

		wait until nicclk'event and nicclk = '1';

		transfer_end <= transfer_end_value;

		req <= req_value;

		irdy <= irdy_value;  

		--AD <= AD_value;

		--frame <= frame_value;  

		payload_transfer_req <= payload_transfer_req_value;

		descriptor_transfer_req <= descriptor_transfer_req_value;

		resume_aborted_payload_transfer <= resume_aborted_payload_transfer_value;

		resume_aborted_descriptor_transfer <= resume_aborted_descriptor_transfer_value;

	end process output_signals_driver;


--	transmission_and_non_transmission_cycles_counter : process 

--	begin

--		wait until pciclk'event and pciclk = '1'; 

--		if	state = processing_packet 

			-- or state = waiting_arbitration_latency_for_payload_transfer

			-- or state = requesting_bus_access_for_descriptor_transfer

--		then	non_transmission_cycles_count := non_transmission_cycles_count + 1;

--		elsif	state = transferring_payload

--			or state = transferring_descriptor

--		then	transmission_cycles_count := transmission_cycles_count + 1;

--			if	non_transmission_cycles_count > max_non_transmission_period

--			then	max_non_transmission_period := non_transmission_cycles_count;

--			end if;

--		end if;
		
--	end process transmission_and_non_transmission_cycles_counter;


	total_transmission_cycles_counter : process 

	begin

		wait until pciclk'event and pciclk = '1' and transfer_start_req = '0'; 

		total_transmission_cycles_count := total_transmission_cycles_count + 1;

	end process total_transmission_cycles_counter;


--	total_acquisition_cycles_counter : process 

--	begin

--		wait until pciclk'event and pciclk = '1' and acq_latency_cycles_count > 0; 

--		total_acquisition_cycles_count := total_acquisition_cycles_count + 1;

--	end process total_acquisition_cycles_counter;


--	print_out_nicctrl_statistics: process 

--		file nicctrl_output_file : text open write_mode is "nicctrl.out";

--		variable output_line : line;

--		variable clock_counter : natural := 1;

--	begin

--		wait until pciclk'event and pciclk = '0'; 

--	        write(output_line, string'("clock "));

--		write(output_line, clock_counter);

--	        write(output_line, string'(": "));

--	        write(output_line, string'("total transmission cycles count = "));

--		write(output_line, total_transmission_cycles_count);

--	        write(output_line, string'(": "));

--		write(output_line, string'("total acquisition cycles count = "));

--		write(output_line, total_acquisition_cycles_count);

--		writeline(nicctrl_output_file, output_line);

--		clock_counter := clock_counter + 1;

--	end process print_out_nicctrl_statistics;


	acquisition_latency_cycles_counter_out_driver: process 

	begin

		wait until pciclk'event and pciclk = '0'; 

		acq_latency_cycles_counter_out <= acq_latency_cycles_count;

	end process acquisition_latency_cycles_counter_out_driver;


	nic_processing_latency_cycles_counter : process 

	begin

		wait until pciclk'event and pciclk = '1' and  state = processing_packet; --transfer_start_req = '0' and req_value = '1'; 

		nic_processing_latency_cycles_count := nic_processing_latency_cycles_count + 1;

	end process nic_processing_latency_cycles_counter;


	nic_processing_latency_cycles_counter_out_driver: process 

	begin

		wait until pciclk'event and pciclk = '0'; 

		nic_proc_latency_cycles_counter_out <= nic_processing_latency_cycles_count;

	end process nic_processing_latency_cycles_counter_out_driver;




	acq_latency_cycles_counter_fsm: process 

	-- Variables needed for acq_latency_cycles_counter_fsm

	type acq_latency_cycles_counter_fsm_state is (idle, 

						      incrementing_acq_latency_cycles_count, 

						      waiting_transaction_end);

	variable state : acq_latency_cycles_counter_fsm_state := idle;

	variable next_state : acq_latency_cycles_counter_fsm_state := idle;

	begin

		wait until pciclk'event and pciclk = '1';

		case state is



			when idle =>

				acq_latency_cycles_count := 0;

				if	gnt = '1' 

				then	next_state := idle;

				elsif	gnt = '0' 

				then	acq_latency_cycles_count := acq_latency_cycles_count + 1;

					assert false 

					report "acq_latency_cycles_counter_fsm: incrementing_acq_latency_cycles_count" 
	
					severity note;

					next_state := incrementing_acq_latency_cycles_count;

				end if;



			when incrementing_acq_latency_cycles_count =>

				if	gnt = '0' 

					and not (frame = '0'

					and AD_value = '0')  

				then	acq_latency_cycles_count := acq_latency_cycles_count + 1;

					next_state := incrementing_acq_latency_cycles_count;
	
				elsif	gnt = '0'

					and frame = '0'

					and AD_value = '0'

				then	acq_latency_cycles_count := 0;

					assert false 

					report "acq_latency_cycles_counter_fsm: waiting_transaction_end" 
	
					severity note;

					next_state := waiting_transaction_end;

				end if;	



			when waiting_transaction_end =>

				if	gnt = '0' 

				then	next_state := waiting_transaction_end;

				elsif	gnt = '1' 

				then	assert false 

					report "acq_latency_cycles_counter_fsm: idle" 
	
					severity note;

					next_state := idle;

				end if;



		end case;	

		state := next_state;

	end process acq_latency_cycles_counter_fsm;





--	print_out_nicctrl_statistics: process 

--		file nicctrl_output_file : text open write_mode is "nicctrl.out";

--		variable output_line : line;

--		variable clock_counter : natural := 1;

--		variable average : real;

--	begin

--		wait until pciclk'event and pciclk = '0'; 

--	        write(output_line, string'("clock "));

--		write(output_line, clock_counter);

--	        write(output_line, string'(": "));

--	        write(output_line, string'("non trans. cycles count = "));

--		write(output_line, non_transmission_cycles_count);

--	        write(output_line, string'(": "));

--		write(output_line, string'("trans. cycles count = "));

--		write(output_line, transmission_cycles_count);

--	        write(output_line, string'(": "));

--	        write(output_line, string'("max. non trans. period = "));

--		write(output_line, max_non_transmission_period);

--	        write(output_line, string'(": "));

--	        write(output_line, string'("total cycles count = "));

--		write(output_line, transmission_cycles_count + non_transmission_cycles_count);

--	        write(output_line, string'(": "));

--	        write(output_line, string'("average rate = "));

		--write(output_line, real(transmission_cycles_count)/real(transmission_cycles_count + non_transmission_cycles_count));

--		writeline(nicctrl_output_file, output_line);

--		clock_counter := clock_counter + 1;

--	end process print_out_nicctrl_statistics;


end V1;
