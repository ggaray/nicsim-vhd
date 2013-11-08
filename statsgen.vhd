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

entity statsgen is

	port (

		pciclk						: in	bit;

		ethclk						: in	bit;

		pktreceived					: in	bit;

		pktsize						: in	integer;	--in bytes

		transfer_start_req				: in	bit;

		transfer_end					: in	bit;

		buffer_fill_level_in_bytes			: in	integer;

		buffer_fill_level_in_data_units			: in	integer;

		max_buffer_fill_level				: in	integer;	

		dropped_packets_count				: in	integer;

		nic_proc_latency_cycles_counter_out		: in	integer;	

		acq_latency_cycles_counter_out			: in	integer;		 

	  	arb_latency_cycles_counter_out			: in	integer;

		target_latency_cycles_counter_out		: in	integer;	

		burst_cycles_counter_out			: in	integer;

		dma_cycles_counter_out				: in	integer;

		clock_counter_out				: out	integer

	);

end statsgen;



architecture V1 of statsgen is



	---------------       Bus width configuration   	---------------

	--constant		 bus_width_in_bits 					: integer 	:= 32; 		-- PCI 33/32

	constant 		bus_width_in_bits 					: integer 	:= 64; 		-- PCI 66/64, PCI-X 133/64

	constant 		bus_width_in_bytes 					: integer 	:= bus_width_in_bits/8; 

	-- ***To be removed

	--constant 		bus_width_in_bytes 	: integer 		:= 4; 	-- PCI bus

	--constant 		bus_width_in_bytes 	: integer 		:= 8; 	-- PCI-X bus

	--constant 		preamble		: integer		:= 7;

	--constant		sof			: integer		:= 1;



	---------------       Buffer configuration   	---------------

	--constant buffer_size : integer := 10000;	-- Number of memory locations




	---------------        Descriptor size configuration 	---------------

	constant 		descriptor_size_in_bytes 				: integer 	:= 16;  -- Descriptor size in bytes

	constant 		descriptor_size_in_data_blocks 				: integer 	:= descriptor_size_in_bytes/bus_width_in_bytes;  

	-- ******To be removed

	--constant 		descriptor_size_in_data_blocks 				: integer 	:= 2;  -- Descriptor size in data blocks (PCI-X bus)

	--constant 		descriptor_size_in_data_blocks 				: integer	:= 4;  -- Descriptor size in data blocks (PCI bus)




	---------------        Size of the Ethernet frame fields	---------------

	constant 		preamble_in_bytes					: integer	:= 7;

	constant		sof_in_bytes						: integer	:= 1;

	constant		destination_address_in_bytes				: integer	:= 6;

	constant		source_address_in_bytes					: integer	:= 6;

	constant		length_in_bytes						: integer	:= 2;

	constant		checksum_in_bytes					: integer	:= 4;




	-- Variables needed for printing out simulation statistics

	shared	variable 	nic_processing_latency_cycles_count 			: natural 	:= 0;  	

	shared	variable 	nic_overhead_cycles_count 				: natural 	:= 0;	

	shared	variable 	arbitration_latency_cycles_count			: natural	:= 0;

	shared	variable 	acquisition_latency_cycles_count			: natural	:= 0;	

	shared	variable 	target_latency_cycles_count				: natural	:= 0;

	shared	variable 	max_nic_latency_cycles_count				: natural	:= 0;

	shared	variable 	max_arbitration_latency_cycles_count			: natural	:= 0;

	shared	variable 	max_acquisition_latency_cycles_count			: natural	:= 0;	

	shared	variable 	max_target_latency_cycles_count				: natural	:= 0;

	shared	variable 	transmission_cycles_count 				: natural	:= 0;

	shared	variable 	number_of_packet_being_transferred			: natural	:= 0;		

	shared	variable 	number_of_last_transferred_packet 			: natural	:= 0;

	shared	variable 	nic_latency_cycles_count_per_packet			: natural	:= 0;

	shared	variable 	max_nic_latency_cycles_count_per_packet			: natural	:= 0;

	shared	variable 	arbitration_latency_cycles_count_per_packet		: natural	:= 0;

	shared	variable 	max_arbitration_latency_cycles_count_per_packet		: natural	:= 0;

	shared	variable 	acquisition_latency_cycles_count_per_packet		: natural	:= 0;

	shared	variable 	max_acquisition_latency_cycles_count_per_packet		: natural	:= 0;

	shared	variable 	target_latency_cycles_count_per_packet			: natural	:= 0;

	shared	variable 	max_target_latency_cycles_count_per_packet		: natural	:= 0;

	shared	variable	processing_cycle_of_the_last_processed_packet_by_nic	: natural 	:= 0;

	shared	variable	processing_cycle_of_the_last_processed_packet_by_arb	: natural 	:= 0;

	shared	variable	processing_cycle_of_the_last_processed_packet_by_acq	: natural 	:= 0;

	shared	variable	processing_cycle_of_the_last_processed_packet_by_memsub	: natural 	:= 0;

	shared	variable	received_packets_counter				: natural 	:= 0;

	shared	variable	transferred_packets_count				: natural 	:= 0;

	shared	variable	clock_counter_value					: integer 	:= 1;

	shared	variable	data_units_received_count				: integer 	:= 0;

	--shared	variable	descriptor_size					: integer 	:= 0;

	shared	variable	data_units_received_rate				: real		:= 0.0;

	shared	variable	nic_rate						: real;

	shared	variable	arbctrl_rate						: real;

	shared	variable	acqctrl_rate						: real;

	shared	variable	memsub_rate						: real;

	shared	variable	clock_counter_for_computing_data_units_received_rate	: natural	:= 0;

	shared	variable	data_unit_size						: integer	:= 0;

	shared	variable	buff_fill_level						: integer	:= 0;	

	shared	variable	max_buff_fill_level					: integer	:= 0;	

	shared	variable	max_received_data_unit_size_in_bytes			: integer	:= 0;	

	shared	variable	size_of_received_data_unit_in_bytes			: integer	:= 0;	



	-- Output values

	signal			sig_clock_counter_value				 	: integer 	:= 1;



begin

	clock_counter_out <= sig_clock_counter_value;

	statsgen_fsm : process 

		type statsgen_state is (idle, 

					incrementing_nic_latency_cycles, 

					incrementing_nic_overhead_cycles,

					incrementing_arbitration_latency_cycles_for_payload_transfer,

					incrementing_acquisition_latency_cycles_for_payload_transfer,

					incrementing_target_latency_cycles_for_payload_transfer,

					incrementing_transmission_cycles_for_payload_transfer, 

					incrementing_arbitration_latency_cycles_for_descriptor_transfer,

					incrementing_acquisition_latency_cycles_for_descriptor_transfer, 

					incrementing_target_latency_cycles_for_descriptor_transfer,

					incrementing_transmission_cycles_for_descriptor_transfer,

					incrementing_arbitration_latency_cycles_for_aborted_payload_transfer,

					incrementing_acquisition_latency_cycles_for_aborted_payload_transfer,

					incrementing_target_latency_cycles_for_aborted_payload_transfer,

					incrementing_transmission_cycles_for_resuming_aborted_payload_transfer, 

					incrementing_arbitration_latency_cycles_for_aborted_descriptor_transfer,

					incrementing_acquisition_latency_cycles_for_aborted_descriptor_transfer,

					incrementing_target_latency_cycles_for_aborted_descriptor_transfer,

					incrementing_transmission_cycles_for_resuming_aborted_descriptor_transfer);

		variable 	state	 		: statsgen_state 	:= idle;   --Initial state

		variable 	next_state 		: statsgen_state 	:= idle;

		-- return_to_this_state is a temporal variable is used within the state incrementing_nic_latency_cycles 

		-- in order to return to the current state of the call

		variable 	return_to_this_state 	: statsgen_state;	

	begin

		wait until pciclk'event and pciclk = '1';

		case state is



			when	idle =>

				if	buffer_fill_level_in_bytes = 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0

				then	next_state := idle;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0

				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 

													processing_cycle_of_the_last_processed_packet_by_nic;

					return_to_this_state :=  incrementing_nic_latency_cycles;

					assert false 

					report "statsgen_fsm: incrementing_nic_overhead_cycles" 
	
					severity note;

					next_state := incrementing_nic_overhead_cycles;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out > 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0

				then	nic_processing_latency_cycles_count := nic_processing_latency_cycles_count + 1;	

					nic_latency_cycles_count_per_packet := 

						(nic_overhead_cycles_count + nic_processing_latency_cycles_count) 

												- processing_cycle_of_the_last_processed_packet_by_nic;

					assert false 

					report "statsgen_fsm: incrementing_nic_latency_cycles" 
	
					severity note;

					next_state := incrementing_nic_latency_cycles;

				end if;



			when	incrementing_nic_latency_cycles =>

				if	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out > 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0  

					and	dma_cycles_counter_out = 0

				then	nic_processing_latency_cycles_count := nic_processing_latency_cycles_count + 1;

					nic_latency_cycles_count_per_packet := 

						(nic_overhead_cycles_count + nic_processing_latency_cycles_count) 

												- processing_cycle_of_the_last_processed_packet_by_nic;

					next_state := incrementing_nic_latency_cycles;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0

				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 
					
													processing_cycle_of_the_last_processed_packet_by_nic;

					return_to_this_state :=  incrementing_arbitration_latency_cycles_for_payload_transfer;

					assert false 

					report "statsgen_fsm: incrementing_nic_overhead_cycles" 
	
					severity note;

					next_state := incrementing_nic_overhead_cycles;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out > 0 

					and	acq_latency_cycles_counter_out = 0

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0

				then	arbitration_latency_cycles_count := arbitration_latency_cycles_count + 1;	

					arbitration_latency_cycles_count_per_packet := 

								arbitration_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_arb;

					assert false 

					report "statsgen_fsm: incrementing_arbitration_latency_cycles_for_payload_transfer" 
	
					severity note;

					next_state := incrementing_arbitration_latency_cycles_for_payload_transfer;

				end if;

-- **************** INICIO de incrementing_nic_overhead_cycles



			when	incrementing_nic_overhead_cycles =>

				if	buffer_fill_level_in_bytes = 0 

					and	transfer_end = '0'   --We need to wait the falling edge of transfer_end

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0

				then	assert false 

					report "statsgen_fsm: idle" 
	
					severity note;

					next_state := idle;

				elsif	buffer_fill_level_in_bytes = 0 

					and	transfer_end = '1'  --We need to wait the falling edge of transfer_end

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0

				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 

													processing_cycle_of_the_last_processed_packet_by_nic;
					next_state := incrementing_nic_overhead_cycles;

				elsif	buffer_fill_level_in_bytes = 0 

					and	transfer_end = '0'

				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 

													processing_cycle_of_the_last_processed_packet_by_nic;

					next_state := incrementing_nic_overhead_cycles;

				elsif	buffer_fill_level_in_bytes = 0 

					and	transfer_end = '1'

				then	assert false 

					report "statsgen_fsm: idle" 
	
					severity note;

					next_state := idle;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					--and	burst_cycles_counter_out = 0  

					and	dma_cycles_counter_out = 0

				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 

													processing_cycle_of_the_last_processed_packet_by_nic;

					next_state := incrementing_nic_overhead_cycles;


				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out > 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					--and	burst_cycles_counter_out = 0  

					and	dma_cycles_counter_out = 0

					and	return_to_this_state = incrementing_nic_latency_cycles

				then	nic_processing_latency_cycles_count := nic_processing_latency_cycles_count + 1;

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 
				
													processing_cycle_of_the_last_processed_packet_by_nic;

					assert false 

					report "statsgen_fsm: incrementing_nic_latency_cycles" 
	
					severity note;

					next_state := incrementing_nic_latency_cycles;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out > 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					--and	burst_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0




					and	return_to_this_state = incrementing_arbitration_latency_cycles_for_payload_transfer

				then	arbitration_latency_cycles_count := arbitration_latency_cycles_count + 1;

					arbitration_latency_cycles_count_per_packet := 

								arbitration_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_arb;

					assert false 

					report "statsgen_fsm: incrementing_arbitration_latency_cycles_for_payload_transfer" 
	
					severity note;

					next_state := incrementing_arbitration_latency_cycles_for_payload_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out > 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					--and	burst_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0

					and	return_to_this_state = incrementing_arbitration_latency_cycles_for_descriptor_transfer

				then	arbitration_latency_cycles_count := arbitration_latency_cycles_count + 1;

					arbitration_latency_cycles_count_per_packet := 

								arbitration_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_arb;

					assert false 

					report "statsgen_fsm: incrementing_arbitration_latency_cycles_for_descriptor_transfer" 
	
					severity note;

					next_state := incrementing_arbitration_latency_cycles_for_descriptor_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0 

					and	arb_latency_cycles_counter_out = 0 

					and	acq_latency_cycles_counter_out > 0 

					and	target_latency_cycles_counter_out = 0

					--and	burst_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0

					and	return_to_this_state = incrementing_acquisition_latency_cycles_for_payload_transfer

				then	acquisition_latency_cycles_count := acquisition_latency_cycles_count + 1;

					acquisition_latency_cycles_count_per_packet := 

								acquisition_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_acq;

					assert false 

					report "statsgen_fsm: incrementing_acquisition_latency_cycles_for_payload_transfer" 
	
					severity note;

					next_state := incrementing_acquisition_latency_cycles_for_payload_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0 

					and	arb_latency_cycles_counter_out = 0 

					and	acq_latency_cycles_counter_out > 0 

					and	target_latency_cycles_counter_out = 0

					--and	burst_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0

					and	return_to_this_state = incrementing_acquisition_latency_cycles_for_descriptor_transfer

				then	acquisition_latency_cycles_count := acquisition_latency_cycles_count + 1;

					acquisition_latency_cycles_count_per_packet := 

								acquisition_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_acq;

					assert false 

					report "statsgen_fsm: incrementing_acquisition_latency_cycles_for_descriptor_transfer" 
	
					severity note;

					next_state := incrementing_acquisition_latency_cycles_for_descriptor_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0 

					and	arb_latency_cycles_counter_out = 0 

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out > 0

					--and	burst_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0

					and	return_to_this_state = incrementing_target_latency_cycles_for_payload_transfer

				then	target_latency_cycles_count := target_latency_cycles_count + 1;

					target_latency_cycles_count_per_packet := 

								target_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_memsub;

					assert false 

					report "statsgen_fsm: incrementing_target_latency_cycles_for_payload_transfer" 
	
					severity note;

					next_state := incrementing_target_latency_cycles_for_payload_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0 

					and	arb_latency_cycles_counter_out = 0 

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out > 0

					--and	burst_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0

					and	return_to_this_state = incrementing_target_latency_cycles_for_descriptor_transfer

				then	target_latency_cycles_count := target_latency_cycles_count + 1;

					target_latency_cycles_count_per_packet := 

								target_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_memsub;

					assert false 

					report "statsgen_fsm: incrementing_target_latency_cycles_for_descriptor_transfer" 
	
					severity note;

					next_state := incrementing_target_latency_cycles_for_descriptor_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0 

					and	arb_latency_cycles_counter_out = 0 

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	dma_cycles_counter_out > 0

					and	burst_cycles_counter_out > 0

					and	return_to_this_state = incrementing_transmission_cycles_for_payload_transfer

				then	transmission_cycles_count := transmission_cycles_count + 1;

					assert false 

					report "statsgen_fsm: incrementing_transmission_cycles_for_payload_transfer" 
	
					severity note;

					next_state := incrementing_transmission_cycles_for_payload_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0 

					and	arb_latency_cycles_counter_out = 0 

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	dma_cycles_counter_out > 0

					and	burst_cycles_counter_out > 0

					and	return_to_this_state = incrementing_transmission_cycles_for_descriptor_transfer

				then	transmission_cycles_count := transmission_cycles_count + 1;

					assert false 

					report "statsgen_fsm: incrementing_transmission_cycles_for_descriptor_transfer" 
	
					severity note;

					next_state := incrementing_transmission_cycles_for_descriptor_transfer;

--				elsif	buffer_fill_level_in_bytes > 0 

--					and	nic_proc_latency_cycles_counter_out = 0

--					and	arb_latency_cycles_counter_out = 0

--					and	acq_latency_cycles_counter_out = 0 

--					and	target_latency_cycles_counter_out > 0

--					and	burst_cycles_counter_out = 0

--					and	dma_cycles_counter_out = 0

--					and	return_to_this_state = incrementing_target_latency_cycles_for_payload_transfer

--				then	target_latency_cycles_count := target_latency_cycles_count + 1;

--					target_latency_cycles_count_per_packet := 

--								target_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_memsub;

--					assert false 

--					report "statsgen_fsm: incrementing_target_latency_cycles_for_payload_transfer" 
	
--					severity note;

--					next_state := incrementing_target_latency_cycles_for_payload_transfer;

				------------------------------------------------	
				-- Aborted payload transfer scenario 
				------------------------------------------------

				-- Case 1: Transitions from NIC overhead state to the arbitration, acquisition and target latencies ()

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0  

					and	dma_cycles_counter_out > 0	

				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 

													processing_cycle_of_the_last_processed_packet_by_nic;

					next_state := incrementing_nic_overhead_cycles;

				elsif	buffer_fill_level_in_bytes > 0 


					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out > 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0  

					and	dma_cycles_counter_out > 0	

					and	return_to_this_state = incrementing_arbitration_latency_cycles_for_aborted_payload_transfer

				then	arbitration_latency_cycles_count := arbitration_latency_cycles_count + 1;	

					arbitration_latency_cycles_count_per_packet := 

								arbitration_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_arb;
					assert false 

					report "statsgen_fsm: incrementing_arbitration_latency_cycles_for_aborted_payload_transfer" 
	
					severity note;

					next_state := incrementing_arbitration_latency_cycles_for_aborted_payload_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out > 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0  

					and	dma_cycles_counter_out > 0

					and	return_to_this_state = incrementing_acquisition_latency_cycles_for_aborted_payload_transfer

				then	acquisition_latency_cycles_count := acquisition_latency_cycles_count + 1;

					acquisition_latency_cycles_count_per_packet := 

								acquisition_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_acq;

					assert false 

					report "statsgen_fsm: incrementing_acquisition_latency_cycles_for_aborted_payload_transfer" 
	
					severity note;

					next_state := incrementing_acquisition_latency_cycles_for_aborted_payload_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out > 0

					and	burst_cycles_counter_out = 0  

					and	dma_cycles_counter_out > 0

					and	return_to_this_state = incrementing_target_latency_cycles_for_aborted_payload_transfer

				then	target_latency_cycles_count := target_latency_cycles_count + 1;

					target_latency_cycles_count_per_packet := 

								target_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_memsub;

					assert false 

					report "statsgen_fsm: incrementing_target_latency_cycles_for_aborted_payload_transfer" 
	
					severity note;

					next_state := incrementing_target_latency_cycles_for_aborted_payload_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out > 0  

					and	dma_cycles_counter_out > 0

					--and	resume_aborted_payload_transfer = '0' 

					and	return_to_this_state = incrementing_transmission_cycles_for_resuming_aborted_payload_transfer

				then	transmission_cycles_count := transmission_cycles_count + 1;

					assert false 

					report "statsgen_fsm: incrementing_transmission_cycles_for_resuming_aborted_payload_transfer" 
	
					severity note;

					next_state := incrementing_transmission_cycles_for_resuming_aborted_payload_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0  

					and	dma_cycles_counter_out > 0

					and	return_to_this_state = incrementing_arbitration_latency_cycles_for_aborted_descriptor_transfer

				then	arbitration_latency_cycles_count := arbitration_latency_cycles_count + 1;

					arbitration_latency_cycles_count_per_packet := 

								arbitration_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_arb;

					assert false 

					report "statsgen_fsm: incrementing_arbitration_latency_cycles_for_aborted_descriptor_transfer" 
	
					severity note;

					next_state := incrementing_arbitration_latency_cycles_for_aborted_descriptor_transfer;

				elsif	buffer_fill_level_in_bytes > 0

					and	nic_proc_latency_cycles_counter_out = 0 

					and	arb_latency_cycles_counter_out = 0 

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0  

					and	dma_cycles_counter_out > 0

					and	return_to_this_state = incrementing_acquisition_latency_cycles_for_aborted_descriptor_transfer

				then	acquisition_latency_cycles_count := acquisition_latency_cycles_count + 1;

					acquisition_latency_cycles_count_per_packet := 

								acquisition_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_acq;

					assert false 

					report "statsgen_fsm: incrementing_acquisition_latency_cycles_for_aborted_descriptor_transfer" 
	
					severity note;

					next_state := incrementing_acquisition_latency_cycles_for_aborted_descriptor_transfer;

				elsif	buffer_fill_level_in_bytes > 0

					and	nic_proc_latency_cycles_counter_out = 0 

					and	arb_latency_cycles_counter_out = 0 

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0  

					and	dma_cycles_counter_out > 0

					and	return_to_this_state = incrementing_target_latency_cycles_for_aborted_descriptor_transfer

				then	target_latency_cycles_count := target_latency_cycles_count + 1;

					target_latency_cycles_count_per_packet := 

								target_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_memsub;

					assert false 

					report "statsgen_fsm: incrementing_target_latency_cycles_for_aborted_descriptor_transfer" 
	
					severity note;

					next_state := incrementing_target_latency_cycles_for_aborted_descriptor_transfer;

				elsif	buffer_fill_level_in_bytes > 0   

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0  

					and	dma_cycles_counter_out > 0

					--and	resume_aborted_descriptor_transfer = '0' 

					and	return_to_this_state = incrementing_transmission_cycles_for_resuming_aborted_descriptor_transfer

				then	transmission_cycles_count := transmission_cycles_count + 1;

					assert false 

					report "statsgen_fsm: incrementing_transmission_cycles_for_resuming_aborted_descriptor_transfer" 
	
					severity note;

					next_state := incrementing_transmission_cycles_for_resuming_aborted_descriptor_transfer;

				------------------------------------------------	
				-- Aborted descriptor transfer scenario 
				------------------------------------------------

				end if;

-- ************** FIN de incrementing_nic_overhead_cycles 



			when	incrementing_arbitration_latency_cycles_for_payload_transfer =>

				if	buffer_fill_level_in_bytes > 0 

					and 	nic_proc_latency_cycles_counter_out = 0

					and 	arb_latency_cycles_counter_out > 0

					and  	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0

				then	arbitration_latency_cycles_count := arbitration_latency_cycles_count + 1;

					arbitration_latency_cycles_count_per_packet := 

								arbitration_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_arb;

					next_state := incrementing_arbitration_latency_cycles_for_payload_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0



				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 

													processing_cycle_of_the_last_processed_packet_by_nic;

					return_to_this_state := incrementing_acquisition_latency_cycles_for_payload_transfer;

					assert false 

					report "statsgen_fsm: incrementing_nic_overhead_cycles" 
	
					severity note;

					next_state := incrementing_nic_overhead_cycles;

				elsif	buffer_fill_level_in_bytes > 0 

					and 	nic_proc_latency_cycles_counter_out = 0 

					and 	arb_latency_cycles_counter_out = 0 

					and  	acq_latency_cycles_counter_out > 0 

					and	target_latency_cycles_counter_out = 0

					and  	dma_cycles_counter_out = 0

				then	acquisition_latency_cycles_count := acquisition_latency_cycles_count + 1;

					acquisition_latency_cycles_count_per_packet := 

								acquisition_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_acq;

					assert false 

					report "statsgen_fsm: incrementing_acquisition_latency_cycles_for_payload_transfer" 
	
					severity note;

					next_state := incrementing_acquisition_latency_cycles_for_payload_transfer;

				end if;



			when	incrementing_acquisition_latency_cycles_for_payload_transfer =>

				if	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0 

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out > 0 

					and	target_latency_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0

				then	acquisition_latency_cycles_count := acquisition_latency_cycles_count + 1;

					acquisition_latency_cycles_count_per_packet := 

								acquisition_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_acq;

					next_state := incrementing_acquisition_latency_cycles_for_payload_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0

				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 

													processing_cycle_of_the_last_processed_packet_by_nic;

					return_to_this_state := incrementing_target_latency_cycles_for_payload_transfer;

					assert false 

					report "statsgen_fsm: incrementing_nic_overhead_cycles" 
	
					severity note;

					next_state := incrementing_nic_overhead_cycles;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and 	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out > 0

					and  	dma_cycles_counter_out = 0

				then	target_latency_cycles_count := target_latency_cycles_count + 1;

					target_latency_cycles_count_per_packet := 

								target_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_memsub;

					assert false 

					report "statsgen_fsm: incrementing_target_latency_cycles_for_payload_transfer" 
	
					severity note;

					next_state := incrementing_target_latency_cycles_for_payload_transfer;

				end if;



			when	incrementing_target_latency_cycles_for_payload_transfer =>

				if	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0 

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out > 0

					and	dma_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0

				then	target_latency_cycles_count := target_latency_cycles_count + 1;

					target_latency_cycles_count_per_packet := 

								target_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_memsub;

					next_state := incrementing_target_latency_cycles_for_payload_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0

				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;	

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 

													processing_cycle_of_the_last_processed_packet_by_nic;

					return_to_this_state := incrementing_transmission_cycles_for_payload_transfer;

					assert false 

					report "statsgen_fsm: incrementing_nic_overhead_cycles"
	
					severity note;

					next_state := incrementing_nic_overhead_cycles;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and 	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and  	dma_cycles_counter_out > 0

					--and	payload_transfer_req = '0' 

				then	transmission_cycles_count := transmission_cycles_count + 1;

					assert false 

					report "statsgen_fsm: incrementing_transmission_cycles_for_payload_transfer" 
	
					severity note;

					next_state := incrementing_transmission_cycles_for_payload_transfer;

				end if;



			when	incrementing_transmission_cycles_for_payload_transfer =>

				if	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out > 0 -- we keep incrementing transmission cycles count until burst counter reach zero

					and	dma_cycles_counter_out > 0 

					--and	payload_transfer_req = '0' -- better, payload_transfer_aborted?

					--and 	payload_transfer_aborted = '0'

				then	transmission_cycles_count := transmission_cycles_count + 1;

					next_state := incrementing_transmission_cycles_for_payload_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out > 0 -- In this case, no overhead happen after completing successfully dma transfer

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					--and	burst_cycles_counter_out > 0	

					and	dma_cycles_counter_out = 0	-- Transfer is not aborted

					--and	payload_transfer_req = '0'   -- better, payload_transfer_aborted?

					--and 	payload_transfer_aborted = '0'	-- Transfer is not aborted

				then	arbitration_latency_cycles_count := arbitration_latency_cycles_count + 1;

					arbitration_latency_cycles_count_per_packet := 

								arbitration_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_arb;

					assert false 

					report "statsgen_fsm: incrementing_arbitration_latency_cycles_for_descriptor_transfer" 
	
					severity note;

					next_state := incrementing_arbitration_latency_cycles_for_descriptor_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					--and	burst_cycles_counter_out > 0	

					and	dma_cycles_counter_out = 0	-- Transfer is not aborted

					--and	payload_transfer_aborted = '0'	-- Transfer is not aborted

				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;	

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 

													processing_cycle_of_the_last_processed_packet_by_nic;

					return_to_this_state := incrementing_arbitration_latency_cycles_for_descriptor_transfer;

					assert false 

					report "statsgen_fsm: incrementing_nic_overhead_cycles" 
	
					severity note;

					next_state := incrementing_nic_overhead_cycles;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0	-- End of DMA transfer cycles

					and	dma_cycles_counter_out > 0	-- Transfer is aborted, dma counter is not equals to 0

					--and	payload_transfer_aborted = '1'	-- Transfer is aborted, dma counter is not equals to 0

				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;	

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 

													processing_cycle_of_the_last_processed_packet_by_nic;

					return_to_this_state := incrementing_arbitration_latency_cycles_for_aborted_payload_transfer;

					assert false 

					report "statsgen_fsm: incrementing_nic_overhead_cycle" 
	
					severity note;

					next_state := incrementing_nic_overhead_cycles;

				end if;



			when	incrementing_arbitration_latency_cycles_for_descriptor_transfer =>

				if	buffer_fill_level_in_bytes > 0 

					and 	nic_proc_latency_cycles_counter_out = 0

					and 	arb_latency_cycles_counter_out > 0

					and  	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0

				then	arbitration_latency_cycles_count := arbitration_latency_cycles_count + 1;

					arbitration_latency_cycles_count_per_packet := 

								arbitration_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_arb;

					next_state := incrementing_arbitration_latency_cycles_for_descriptor_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0

				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;	

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 

													processing_cycle_of_the_last_processed_packet_by_nic;

					return_to_this_state := incrementing_acquisition_latency_cycles_for_descriptor_transfer;

					assert false 

					report "statsgen_fsm: incrementing_nic_overhead_cycles" 
	
					severity note;

					next_state := incrementing_nic_overhead_cycles;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out > 0 

					and	target_latency_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0

				then	acquisition_latency_cycles_count := acquisition_latency_cycles_count + 1;	

					acquisition_latency_cycles_count_per_packet := 

								acquisition_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_acq;

					assert false 

					report "statsgen_fsm: incrementing_acquisition_latency_cycles_for_descriptor_transfer" 
	
					severity note;

					next_state := incrementing_acquisition_latency_cycles_for_descriptor_transfer;

				end if;



			when	incrementing_acquisition_latency_cycles_for_descriptor_transfer =>

				if	buffer_fill_level_in_bytes > 0 

					and 	nic_proc_latency_cycles_counter_out = 0

					and 	arb_latency_cycles_counter_out = 0

					and  	acq_latency_cycles_counter_out > 0 

					and	target_latency_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0

				then	acquisition_latency_cycles_count := acquisition_latency_cycles_count + 1;

					acquisition_latency_cycles_count_per_packet := 

								acquisition_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_acq;

					next_state := incrementing_acquisition_latency_cycles_for_descriptor_transfer;


				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0

				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;	

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 

													processing_cycle_of_the_last_processed_packet_by_nic;

					return_to_this_state := incrementing_target_latency_cycles_for_descriptor_transfer;

					assert false 

					report "statsgen_fsm: incrementing_nic_overhead_cycles" 
	
					severity note;

					next_state := incrementing_nic_overhead_cycles;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out > 0

					and	dma_cycles_counter_out = 0

				then	target_latency_cycles_count := target_latency_cycles_count + 1;	

					target_latency_cycles_count_per_packet := 

								target_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_memsub;

					assert false 

					report "statsgen_fsm: incrementing_target_latency_cycles_for_descriptor_transfer" 
	
					severity note;

					next_state := incrementing_target_latency_cycles_for_descriptor_transfer;

				end if;



			when	incrementing_target_latency_cycles_for_descriptor_transfer =>

				if	buffer_fill_level_in_bytes > 0 

					and 	nic_proc_latency_cycles_counter_out = 0

					and 	arb_latency_cycles_counter_out = 0

					and  	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out > 0

					and	dma_cycles_counter_out = 0

				then	target_latency_cycles_count := target_latency_cycles_count + 1;

					target_latency_cycles_count_per_packet := 

								target_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_memsub;

					next_state := incrementing_target_latency_cycles_for_descriptor_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0

				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;	

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 

													processing_cycle_of_the_last_processed_packet_by_nic;

					return_to_this_state := incrementing_transmission_cycles_for_descriptor_transfer;

					assert false 

					report "statsgen_fsm: incrementing_nic_overhead_cycles" 
	
					severity note;

					next_state := incrementing_nic_overhead_cycles;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	dma_cycles_counter_out > 0

					--and	descriptor_transfer_req = '0'

				then	transmission_cycles_count := transmission_cycles_count + 1;	

					assert false 

					report "statsgen_fsm: incrementing_transmission_cycles_for_descriptor_transfer" 
	
					severity note;

					next_state := incrementing_transmission_cycles_for_descriptor_transfer;

				end if;



			when	incrementing_transmission_cycles_for_descriptor_transfer =>

				if	buffer_fill_level_in_bytes > 0 

					and 	nic_proc_latency_cycles_counter_out = 0

					and 	arb_latency_cycles_counter_out = 0

					and  	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	dma_cycles_counter_out > 0

					--and	descriptor_transfer_req = '0'

					--and	descriptor_transfer_aborted = '0' 

				then	transmission_cycles_count := transmission_cycles_count + 1;

					next_state := incrementing_transmission_cycles_for_descriptor_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					--and	burst_cycles_counter_out = 0	-- End of DMA transfer cycles 

					and	dma_cycles_counter_out = 0	-- Transfer is not aborted 

					--and	descriptor_transfer_aborted = '0'  -- Not aborted

				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;	

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 

													processing_cycle_of_the_last_processed_packet_by_nic;

					return_to_this_state := incrementing_nic_latency_cycles;

					assert false 

					report "statsgen_fsm: incrementing_nic_overhead_cycles" 
	
					severity note;

					next_state := incrementing_nic_overhead_cycles;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0	-- End of DMA transfer cycles

					and	dma_cycles_counter_out > 0	-- Transfer aborted !

					--and	descriptor_transfer_aborted = '0'  -- Not aborted

				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;	

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 

													processing_cycle_of_the_last_processed_packet_by_nic;

					return_to_this_state := incrementing_arbitration_latency_cycles_for_descriptor_transfer;

					assert false 

					report "statsgen_fsm: incrementing_nic_overhead_cycles" 
	
					severity note;

					next_state := incrementing_nic_overhead_cycles;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out > 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0	-- End of DMA transfer cycles

					and	dma_cycles_counter_out > 0	-- Transfer aborted !

					--and	descriptor_transfer_aborted = '0'  -- Not aborted

				then	assert false 

					report "statsgen_fsm: incrementing_nic_overhead_cycles" 
	
					severity note;

					next_state := incrementing_nic_latency_cycles;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out > 0	-- Go directly to nic processing, no overhead cycles happen

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0  

				then	assert false 

					report "statsgen_fsm: incrementing_nic_latency_cycles" 
	
					severity note;

					next_state := incrementing_nic_latency_cycles;

				elsif	buffer_fill_level_in_bytes = 0   -- Buffer empty !!

					and	nic_proc_latency_cycles_counter_out = 0 

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					--and	burst_cycles_counter_out = 0	-- End of DMA transfer cycles 

					and	dma_cycles_counter_out = 0	-- Transfer is not aborted

					--and	descriptor_transfer_aborted = '0'  -- Not aborted

				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;	

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 

													processing_cycle_of_the_last_processed_packet_by_nic;

					return_to_this_state := idle;

					assert false 

					report "statsgen_fsm: idle" 
	
					severity note;

					next_state := idle;

				elsif	buffer_fill_level_in_bytes = 0   -- Buffer empty !!

					and	nic_proc_latency_cycles_counter_out > 0  -- Go directly to nic processing, no overhead cycles happen

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					--and	burst_cycles_counter_out = 0	-- End of DMA transfer cycles 

					and	dma_cycles_counter_out = 0	-- Transfer is not aborted

					--and	descriptor_transfer_aborted = '0'  -- Not aborted

				then	assert false 

					report "statsgen_fsm: idle" 
	
					severity note;

					next_state := incrementing_nic_latency_cycles;

				end if;



			when	incrementing_arbitration_latency_cycles_for_aborted_payload_transfer =>

				---------------------------------
				-- Go to overhead state
				---------------------------------

				if	buffer_fill_level_in_bytes > 0 

					and 	nic_proc_latency_cycles_counter_out = 0

					and 	arb_latency_cycles_counter_out > 0

					and  	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0

					and	dma_cycles_counter_out > 0	-- Because of it is an aborted transfer, dma cycles counter is greater than 0

				then	arbitration_latency_cycles_count := arbitration_latency_cycles_count + 1;

					arbitration_latency_cycles_count_per_packet := 

								arbitration_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_arb;

					next_state := incrementing_arbitration_latency_cycles_for_aborted_payload_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0

					and	dma_cycles_counter_out > 0	-- Because of it is an aborted transfer, dma cycles counter is greater than 0

				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;	

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 

													processing_cycle_of_the_last_processed_packet_by_nic;

					return_to_this_state := incrementing_acquisition_latency_cycles_for_aborted_payload_transfer;

					assert false 

					report "statsgen_fsm: incrementing_nic_overhead_cycles" 
	
					severity note;

					next_state := incrementing_nic_overhead_cycles;

				---------------------------------------------------
				-- Go to directly to the next state, no overhead
				---------------------------------------------------

				elsif	buffer_fill_level_in_bytes > 0 

					and 	nic_proc_latency_cycles_counter_out = 0 

					and 	arb_latency_cycles_counter_out = 0 

					and  	acq_latency_cycles_counter_out > 0 --Go directly to incrementing acquisition latency cycles, no overhead happen

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0

					and	dma_cycles_counter_out > 0	-- Because of it is an aborted transfer, dma cycles counter is greater than 0

				then	acquisition_latency_cycles_count := acquisition_latency_cycles_count + 1;

					acquisition_latency_cycles_count_per_packet := 

								acquisition_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_acq;

					assert false 

					report "statsgen_fsm: incrementing_acquisition_latency_cycles_for_aborted_payload_transfer" 
	
					severity note;

					next_state := incrementing_acquisition_latency_cycles_for_aborted_payload_transfer;

				end if;



			when	incrementing_acquisition_latency_cycles_for_aborted_payload_transfer =>

				---------------------------------
				-- Go to overhead state
				---------------------------------

				if	buffer_fill_level_in_bytes > 0 

					and 	nic_proc_latency_cycles_counter_out = 0

					and 	arb_latency_cycles_counter_out = 0

					and  	acq_latency_cycles_counter_out > 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0

					and	dma_cycles_counter_out > 0	-- Because of it is an aborted transfer, dma cycles counter is greater than 0

				then	acquisition_latency_cycles_count := acquisition_latency_cycles_count + 1;

					acquisition_latency_cycles_count_per_packet := 

								acquisition_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_acq;

					next_state := incrementing_acquisition_latency_cycles_for_aborted_payload_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0

					and	dma_cycles_counter_out > 0	-- Because of it is an aborted transfer, dma cycles counter is greater than 0

				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;	

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 

													processing_cycle_of_the_last_processed_packet_by_nic;

					return_to_this_state := incrementing_target_latency_cycles_for_aborted_payload_transfer;

					assert false 

					report "statsgen_fsm: incrementing_nic_overhead_cycles" 
	
					severity note;

					next_state := incrementing_nic_overhead_cycles;

				---------------------------------
				-- Go to directly to the next state, no overhead
				---------------------------------

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out > 0 --Go directly to incrementing target latency cycles, no overhead happen

					and	burst_cycles_counter_out = 0

					and	dma_cycles_counter_out > 0	-- Because of it is an aborted transfer, dma cycles counter is greater than 0

				then	target_latency_cycles_count := target_latency_cycles_count + 1;	

					target_latency_cycles_count_per_packet := 

								target_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_memsub;

					assert false 

					report "statsgen_fsm: incrementing_target_latency_cycles_for_aborted_payload_transfer" 
	
					severity note;

					next_state := incrementing_target_latency_cycles_for_aborted_payload_transfer;

				end if;



			when	incrementing_target_latency_cycles_for_aborted_payload_transfer =>

				if	buffer_fill_level_in_bytes > 0 

					and 	nic_proc_latency_cycles_counter_out = 0

					and 	arb_latency_cycles_counter_out = 0

					and  	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out > 0

					and	burst_cycles_counter_out = 0

					and	dma_cycles_counter_out > 0	-- Because of it is an aborted transfer, dma cycles counter is greater than 0

				then	target_latency_cycles_count := target_latency_cycles_count + 1;

					target_latency_cycles_count_per_packet := 

								target_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_memsub;

					next_state := incrementing_target_latency_cycles_for_aborted_payload_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0

					and	dma_cycles_counter_out > 0	-- Because of it is an aborted transfer, dma cycles counter is greater than 0

				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 

													processing_cycle_of_the_last_processed_packet_by_nic;

					return_to_this_state := incrementing_transmission_cycles_for_resuming_aborted_payload_transfer;

					assert false 

					report "statsgen_fsm: incrementing_nic_overhead_cycles" 
	
					severity note;

					next_state := incrementing_nic_overhead_cycles;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out > 0  -- Go directly to incrementing transmission cycles, no overhead happen

					and	dma_cycles_counter_out > 0	-- Because of it is an aborted transfer, dma cycles counter is greater than 0

					--and	resume_aborted_payload_transfer = '0'

				then	transmission_cycles_count := transmission_cycles_count + 1;	

					assert false 

					report "statsgen_fsm: incrementing_transmission_cycles_for_resuming_aborted_payload_transfer" 
	
					severity note;

					next_state := incrementing_transmission_cycles_for_resuming_aborted_payload_transfer;

				end if;



			when	incrementing_transmission_cycles_for_resuming_aborted_payload_transfer => 

				if	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out > 0

					and	dma_cycles_counter_out > 0	-- Because of it is an aborted transfer, dma cycles counter is greater than 0

				then	transmission_cycles_count := transmission_cycles_count + 1;

					next_state := incrementing_transmission_cycles_for_resuming_aborted_payload_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0

					and	dma_cycles_counter_out > 0	-- Again, payload fragmentation

				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;	

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 

													processing_cycle_of_the_last_processed_packet_by_nic;

					return_to_this_state := incrementing_arbitration_latency_cycles_for_aborted_payload_transfer;

					assert false 

					report "statsgen_fsm: incrementing_nic_overhead_cycles" 
	
					severity note;

					next_state := incrementing_nic_overhead_cycles;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					--and	burst_cycles_counter_out = 0

					and	dma_cycles_counter_out = 0	-- Aborted transfer completed

				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;	

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 

													processing_cycle_of_the_last_processed_packet_by_nic;

					return_to_this_state := incrementing_arbitration_latency_cycles_for_descriptor_transfer;

					assert false 

					report "statsgen_fsm: incrementing_nic_overhead_cycles" 
	
					severity note;

					next_state := incrementing_nic_overhead_cycles;


-- Quizas nunca ocurra esta transaccion, ir directo al otro estado sin pasar por ciclos de overhead

--				elsif	buffer_fill_level_in_bytes > 0 

--					and	nic_proc_latency_cycles_counter_out = 0

--					and	arb_latency_cycles_counter_out > 0

--					and	acq_latency_cycles_counter_out = 0 

--					and	target_latency_cycles_counter_out = 0

--					and	burst_cycles_counter_out = 0

--					and	resume_aborted_payload_transfer = '0'

--				then	arbitration_latency_cycles_count := arbitration_latency_cycles_count + 1;

--					arbitration_latency_cycles_count_per_packet := 

--								arbitration_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_arb;

--					assert false 

--					report "statsgen_fsm: incrementing_arbitration_latency_cycles_for_descriptor_transfer" 
	
--					severity note;

--					next_state := incrementing_arbitration_latency_cycles_for_descriptor_transfer;

-- Quizas nunca ocurra esta transaccion, ir directo al otro estado sin pasar por ciclos de overhead

--				elsif	buffer_fill_level_in_bytes > 0 

--					and	nic_proc_latency_cycles_counter_out = 0

--					and	arb_latency_cycles_counter_out > 0

--					and	acq_latency_cycles_counter_out = 0 

--					and	target_latency_cycles_counter_out = 0

--					and	burst_cycles_counter_out = 0

--					and	resume_aborted_payload_transfer = '1'

--				then	arbitration_latency_cycles_count := arbitration_latency_cycles_count + 1;

--					arbitration_latency_cycles_count_per_packet := 

--								arbitration_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_arb;

--					assert false 

--					report "statsgen_fsm: incrementing_arbitration_latency_cycles_for_aborted_payload_transfer" 
	
--					severity note;

--					next_state := incrementing_arbitration_latency_cycles_for_aborted_payload_transfer;

				end if;



			when	incrementing_arbitration_latency_cycles_for_aborted_descriptor_transfer =>

				if	buffer_fill_level_in_bytes > 0 

					and 	nic_proc_latency_cycles_counter_out = 0

					and 	arb_latency_cycles_counter_out > 0

					and  	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out > 0

					--and	resume_aborted_descriptor_transfer = '0'

				then	arbitration_latency_cycles_count := arbitration_latency_cycles_count + 1;

					arbitration_latency_cycles_count_per_packet := 

								arbitration_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_arb;

					next_state := incrementing_arbitration_latency_cycles_for_aborted_descriptor_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out > 0

				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;	

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 

													processing_cycle_of_the_last_processed_packet_by_nic;

					return_to_this_state := incrementing_acquisition_latency_cycles_for_aborted_descriptor_transfer;

					assert false 

					report "statsgen_fsm: incrementing_nic_overhead_cycles" 
	
					severity note;

					next_state := incrementing_nic_overhead_cycles;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out > 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out > 0

				then	acquisition_latency_cycles_count := acquisition_latency_cycles_count + 1;	

					acquisition_latency_cycles_count_per_packet := 

								acquisition_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_acq;

					assert false 

					report "statsgen_fsm: incrementing_acquisition_latency_cycles_for_aborted_descriptor_transfer" 
	
					severity note;

					next_state := incrementing_acquisition_latency_cycles_for_aborted_descriptor_transfer;

				end if;



			when	incrementing_acquisition_latency_cycles_for_aborted_descriptor_transfer =>

				if	buffer_fill_level_in_bytes > 0 

					and 	nic_proc_latency_cycles_counter_out = 0

					and 	arb_latency_cycles_counter_out = 0

					and  	acq_latency_cycles_counter_out > 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out > 0

				then	acquisition_latency_cycles_count := acquisition_latency_cycles_count + 1;

					acquisition_latency_cycles_count_per_packet := 

								acquisition_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_acq;

					assert false 

					report "statsgen_fsm: incrementing_acquisition_latency_cycles_for_aborted_descriptor_transfer" 
	
					severity note;

					next_state := incrementing_acquisition_latency_cycles_for_aborted_descriptor_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out > 0

				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;	

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 

													processing_cycle_of_the_last_processed_packet_by_nic;

					return_to_this_state := incrementing_target_latency_cycles_for_aborted_descriptor_transfer;

					assert false 

					report "statsgen_fsm: incrementing_nic_overhead_cycles" 
	
					severity note;

					next_state := incrementing_nic_overhead_cycles;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out > 0

					and	burst_cycles_counter_out > 0

				then	target_latency_cycles_count := target_latency_cycles_count + 1;	

					target_latency_cycles_count_per_packet := 

								target_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_memsub;

					assert false 

					report "statsgen_fsm: incrementing_target_latency_cycles_for_aborted_descriptor_transfer" 
	
					severity note;

					next_state := incrementing_target_latency_cycles_for_aborted_descriptor_transfer;

				end if;



			when	incrementing_target_latency_cycles_for_aborted_descriptor_transfer =>

				if	buffer_fill_level_in_bytes > 0 

					and 	nic_proc_latency_cycles_counter_out = 0

					and 	arb_latency_cycles_counter_out = 0

					and  	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out > 0

					and	burst_cycles_counter_out > 0

				then	target_latency_cycles_count := target_latency_cycles_count + 1;

					target_latency_cycles_count_per_packet := 

								target_latency_cycles_count - processing_cycle_of_the_last_processed_packet_by_memsub;

					next_state := incrementing_target_latency_cycles_for_aborted_descriptor_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out > 0

				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 

													processing_cycle_of_the_last_processed_packet_by_nic;	

					return_to_this_state := incrementing_transmission_cycles_for_resuming_aborted_descriptor_transfer;

					assert false 

					report "statsgen_fsm: incrementing_nic_overhead_cycles" 
	
					severity note;

					next_state := incrementing_nic_overhead_cycles;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out > 0

					--and	resume_aborted_descriptor_transfer = '0'

				then	transmission_cycles_count := transmission_cycles_count + 1;	


					assert false 

					report "statsgen_fsm: incrementing_transmission_cycles_for_resuming_aborted_descriptor_transfer" 
	
					severity note;

					next_state := incrementing_transmission_cycles_for_resuming_aborted_descriptor_transfer;


				end if;



			when	incrementing_transmission_cycles_for_resuming_aborted_descriptor_transfer =>

				if	buffer_fill_level_in_bytes > 0 

					and 	nic_proc_latency_cycles_counter_out = 0

					and 	arb_latency_cycles_counter_out = 0

					and  	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out > 0

					--and	resume_aborted_descriptor_transfer = '0'

				then	transmission_cycles_count := transmission_cycles_count + 1;

					next_state := incrementing_transmission_cycles_for_resuming_aborted_descriptor_transfer;

				elsif	buffer_fill_level_in_bytes > 0 

					and	nic_proc_latency_cycles_counter_out = 0

					and	arb_latency_cycles_counter_out = 0

					and	acq_latency_cycles_counter_out = 0 

					and	target_latency_cycles_counter_out = 0

					and	burst_cycles_counter_out = 0	-- Aborted descriptor transfer completed

				then	nic_overhead_cycles_count := nic_overhead_cycles_count + 1;	

					nic_latency_cycles_count_per_packet := 

							(nic_overhead_cycles_count + nic_processing_latency_cycles_count) - 

													processing_cycle_of_the_last_processed_packet_by_nic;

					return_to_this_state := incrementing_transmission_cycles_for_resuming_aborted_descriptor_transfer;

					assert false 

					report "statsgen_fsm: incrementing_nic_overhead_cycles" 
	
					severity note;

					next_state := incrementing_nic_overhead_cycles;

				elsif	buffer_fill_level_in_bytes = 0 

				then	next_state := idle;

				end if;

		end case; 

		state := next_state;

	end process statsgen_fsm;





	transaction_in_progress_monitor: process 

		type statsgen_transaction_in_progress_monitor_fsm is (idle,

							transaction_in_progress, 

							ending_transaction);

							--updating_latency_per_packet);

		variable 	state	 			: statsgen_transaction_in_progress_monitor_fsm 	:= idle;   --Initial state

		variable 	next_state 			: statsgen_transaction_in_progress_monitor_fsm 	:= idle;

	begin

		wait until pciclk'event and pciclk = '0';

		case state is



			when	idle =>

				processing_cycle_of_the_last_processed_packet_by_nic := nic_overhead_cycles_count + nic_processing_latency_cycles_count;	

				processing_cycle_of_the_last_processed_packet_by_arb := arbitration_latency_cycles_count;

				processing_cycle_of_the_last_processed_packet_by_acq := acquisition_latency_cycles_count;

				processing_cycle_of_the_last_processed_packet_by_memsub := target_latency_cycles_count;

				arbitration_latency_cycles_count_per_packet := 0;

				acquisition_latency_cycles_count_per_packet := 0;

				target_latency_cycles_count_per_packet := 0;

				if	transfer_start_req = '1' 

					and 	transfer_end = '0'

				then	next_state := idle;

				elsif	transfer_start_req = '0'	--Start of transaction

					and 	transfer_end = '0'

				then	assert false 

					report "statsgen_transaction_in_progress_monitor_fsm: transaction_in_progress" 
	
					severity note;

					next_state := transaction_in_progress;

				end if;



			when	transaction_in_progress =>

				if	transfer_start_req = '0'	--Transaction in progress

					and 	transfer_end = '0'

				then	next_state := transaction_in_progress;

				elsif	transfer_end = '1'	--Transaction termination start

				then	transferred_packets_count := transferred_packets_count + 1;

					assert false 

					report "statsgen_transaction_in_progress_monitor_fsm: ending_transaction" 
	
					severity note;

					next_state := ending_transaction;

				end if;



			when	ending_transaction =>

				if	transfer_end = '1'	--Transaction termination in progress

				then	next_state := ending_transaction;

				elsif	transfer_end = '0'	--End of transaction (transaction termination process completed)

				then	assert false 

					report "statsgen_transaction_in_progress_monitor_fsm: updating_latency_per_packet" 
	
					severity note;

					next_state := idle;

				end if;



--			when	updating_latency_per_packet =>

--				processing_cycle_of_the_last_processed_packet_by_nic := nic_overhead_cycles_count + nic_processing_latency_cycles_count;	

--				assert false 

--				report "statsgen_transaction_in_progress_monitor_fsm: idle" 
	
--				severity note;

--				next_state := idle;

		end case; 

		state := next_state;

	end process transaction_in_progress_monitor;




	maximum_latency_monitor: process 

	begin

		wait until pciclk'event and pciclk = '0';

		if	nic_latency_cycles_count_per_packet > max_nic_latency_cycles_count_per_packet

		then	max_nic_latency_cycles_count_per_packet := nic_latency_cycles_count_per_packet;

		end if;

		if	arbitration_latency_cycles_count_per_packet > max_arbitration_latency_cycles_count_per_packet

		then	max_arbitration_latency_cycles_count_per_packet := arbitration_latency_cycles_count_per_packet;

		end if;

		if	acquisition_latency_cycles_count_per_packet > max_acquisition_latency_cycles_count_per_packet

		then	max_acquisition_latency_cycles_count_per_packet := acquisition_latency_cycles_count_per_packet;

		end if;

		if	target_latency_cycles_count_per_packet > max_target_latency_cycles_count_per_packet

		then	max_target_latency_cycles_count_per_packet := target_latency_cycles_count_per_packet;

		end if;


	end process maximum_latency_monitor;





	max_buffer_fill_level_monitor: process 

	begin

		wait until ethclk'event and ethclk = '1';

		if	buff_fill_level > max_buff_fill_level 

		then	max_buff_fill_level := buff_fill_level;

		end if;

	end process max_buffer_fill_level_monitor;





	max_data_unit_size_monitor: process 

		type max_data_unit_size_monitor_fsm is (idle,

							comparing);

		variable 	state	 			: max_data_unit_size_monitor_fsm 	:= idle;   --Initial state

		variable 	next_state 			: max_data_unit_size_monitor_fsm 	:= idle;

	begin

		wait until ethclk'event and ethclk = '1';

		case state is



		when	idle =>

			if	pktreceived = '0'

			then	next_state := idle;

			elsif	pktreceived = '1'

			then	size_of_received_data_unit_in_bytes := pktsize - (preamble_in_bytes + sof_in_bytes) + descriptor_size_in_bytes;

				next_state := comparing;

			end if;



		when	comparing =>

			if	size_of_received_data_unit_in_bytes > max_received_data_unit_size_in_bytes 
	
			then	max_received_data_unit_size_in_bytes := size_of_received_data_unit_in_bytes;

			end if;

			size_of_received_data_unit_in_bytes := 0;

			next_state := idle;

		end case; 

		state := next_state;

	end process max_data_unit_size_monitor;




	inc_clock_counter: process 

	begin

		wait until pciclk'event and pciclk = '1'; 

		clock_counter_value := clock_counter_value + 1;

	end process inc_clock_counter;



	clock_counter_manager: process 

	begin

		wait until pciclk'event and pciclk = '0'; 

		sig_clock_counter_value <= clock_counter_value;

	end process clock_counter_manager;




	input_rate_computation_in_data_units_per_pci_cycles: process 

		type data_units_received_monitor_fsm is (idle,

							fresh_packet_received,

							waiting_packet_received_falling_edge, 

							waiting_for_a_fresh_packet);

		variable 	state	 			: data_units_received_monitor_fsm 	:= idle;   --Initial state

		variable 	next_state 			: data_units_received_monitor_fsm 	:= idle;

	begin

		wait until pciclk'event and pciclk = '1';

		case state is



		when	idle =>

			if	pktreceived = '0'

			then	next_state := idle;

			elsif	pktreceived = '1'

			then	received_packets_counter := received_packets_counter + 1;

				nic_overhead_cycles_count := nic_overhead_cycles_count + 1;

				assert false 

				report "data_units_received_monitor_fsm: fresh_packet_received" 
	
				severity note;

				next_state := fresh_packet_received;

			end if;



		when	fresh_packet_received =>

			--received_packets_counter := received_packets_counter + 1;

			nic_overhead_cycles_count := nic_overhead_cycles_count + 1;


			data_units_received_count := 

			data_units_received_count + integer(ceil(real(pktsize - (preamble_in_bytes + sof_in_bytes))/real(bus_width_in_bytes))) 

															+ descriptor_size_in_data_blocks;

			data_unit_size := integer(ceil(real(pktsize - (preamble_in_bytes + sof_in_bytes))/real(bus_width_in_bytes))) 

															+ descriptor_size_in_data_blocks;

			--descriptor_size := descriptor_size_in_data_blocks;

			clock_counter_for_computing_data_units_received_rate := clock_counter_for_computing_data_units_received_rate + 1;

			data_units_received_rate := 

				real(data_units_received_count)/real(clock_counter_for_computing_data_units_received_rate);

				assert false 

				report "data_units_received_monitor_fsm: waiting_packet_received_falling_edge" 
	
				severity note;

			next_state := waiting_packet_received_falling_edge;



		when	waiting_packet_received_falling_edge =>

			if	pktreceived = '1'

			then	clock_counter_for_computing_data_units_received_rate := clock_counter_for_computing_data_units_received_rate + 1;

				data_units_received_rate := 

						real(data_units_received_count)/real(clock_counter_for_computing_data_units_received_rate);

			nic_overhead_cycles_count := nic_overhead_cycles_count + 1;

				next_state := waiting_packet_received_falling_edge;

			elsif	pktreceived = '0'

			then	clock_counter_for_computing_data_units_received_rate := clock_counter_for_computing_data_units_received_rate + 1;

				data_units_received_rate := 

						real(data_units_received_count)/real(clock_counter_for_computing_data_units_received_rate);

			--nic_overhead_cycles_count := nic_overhead_cycles_count + 1;

				assert false 

				report "data_units_received_monitor_fsm: waiting_for_a_fresh_packet" 
	
				severity note;

				next_state := waiting_for_a_fresh_packet;

			end if;



		when	waiting_for_a_fresh_packet =>

			if	pktreceived = '0'

			then	clock_counter_for_computing_data_units_received_rate := clock_counter_for_computing_data_units_received_rate + 1;

				data_units_received_rate := 

						real(data_units_received_count)/real(clock_counter_for_computing_data_units_received_rate);

				--nic_overhead_cycles_count := nic_overhead_cycles_count + 1;

				next_state := waiting_for_a_fresh_packet;

			elsif	pktreceived = '1'

			then	received_packets_counter := received_packets_counter + 1;

				clock_counter_for_computing_data_units_received_rate := clock_counter_for_computing_data_units_received_rate + 1;

				data_units_received_rate := 

						real(data_units_received_count)/real(clock_counter_for_computing_data_units_received_rate);

				nic_overhead_cycles_count := nic_overhead_cycles_count + 1;

				assert false 

				report "data_units_received_monitor_fsm: fresh_packet_received" 
	
				severity note;

				next_state := fresh_packet_received;


			end if;



		end case; 

		state := next_state;

	end process input_rate_computation_in_data_units_per_pci_cycles;



--	input_rate_computation_in_packets_per_second: process 

--		type data_units_received_monitor_fsm is (idle,

--							fresh_packet_received,

--							waiting_packet_received_falling_edge, 

--							waiting_for_a_fresh_packet);

--		variable 	state	 			: data_units_received_monitor_fsm 	:= idle;   --Initial state

--		variable 	next_state 			: data_units_received_monitor_fsm 	:= idle;

--	begin

--		wait until ethclk'event and ethclk = '1';

--		case state is



--		when	idle =>

--			if	pktreceived = '0'

--			then	next_state := idle;

--			elsif	pktreceived = '1'

--			then	next_state := fresh_packet_received;

--			end if;



--		when	fresh_packet_received =>

--			packets_received_counter := packets_received_counter + 1;

--			eth_clock_counter := eth_clock_counter + 1;

--			packets_received_rate := 

--				real(packets_received_counter)/real(clock_counter_for_computing_data_units_received_rate);

--			next_state := waiting_packet_received_falling_edge;



--		when	waiting_packet_received_falling_edge =>

--			if	pktreceived = '1'

--			then	clock_counter_for_computing_data_units_received_rate := clock_counter_for_computing_data_units_received_rate + 1;

--				data_units_received_rate := 

--						real(data_units_received_count)/real(clock_counter_for_computing_data_units_received_rate);

--				next_state := waiting_packet_received_falling_edge;

--			elsif	pktreceived = '0'

--			then	clock_counter_for_computing_data_units_received_rate := clock_counter_for_computing_data_units_received_rate + 1;

--				data_units_received_rate := 

--						real(data_units_received_count)/real(clock_counter_for_computing_data_units_received_rate);

--				next_state := waiting_for_a_fresh_packet;

--			end if;



--		when	waiting_for_a_fresh_packet =>

--			if	pktreceived = '0'

--			then	clock_counter_for_computing_data_units_received_rate := clock_counter_for_computing_data_units_received_rate + 1;

--				data_units_received_rate := 

--						real(data_units_received_count)/real(clock_counter_for_computing_data_units_received_rate);

--				next_state := waiting_for_a_fresh_packet;

--			elsif	pktreceived = '1'

--			then	clock_counter_for_computing_data_units_received_rate := clock_counter_for_computing_data_units_received_rate + 1;

--				data_units_received_rate := 

--						real(data_units_received_count)/real(clock_counter_for_computing_data_units_received_rate);

--				next_state := fresh_packet_received;


--			end if;



--		end case; 

--		state := next_state;

--	end process input_rate_computation_in_packets_per_second;






	current_packet_being_transferred_monitor: process 

		type packet_being_transferred_fsm_state is (waiting_transfer_start, 

							    waiting_packet_reception,

							    transferring, 

							    ending);

		variable 	state 		: packet_being_transferred_fsm_state 	:=	waiting_packet_reception;   --Initial state

		variable 	next_state 	: packet_being_transferred_fsm_state 	:=	waiting_packet_reception;

	begin

		wait until pciclk'event and pciclk = '1'; 

		case state is



			when	waiting_packet_reception =>

				if	pktreceived = '0'

				then	--number_of_packet_being_transferred := 0;

					next_state := waiting_packet_reception;

				elsif	pktreceived = '1'

				then	number_of_packet_being_transferred := number_of_last_transferred_packet;

					number_of_packet_being_transferred := number_of_packet_being_transferred + 1;

					assert false 

					report "current_packet_being_transferred_monitor_fsm: waiting_transfer_start" 
	
					severity note;

					next_state := waiting_transfer_start;

				end if;



			when	waiting_transfer_start =>

				if	transfer_start_req = '1' and transfer_end = '0'

				then	--assert false 

					--report "current_packet_being_transferred_monitor_fsm: waiting_transfer_start" 
	
					--severity note;

					next_state := waiting_transfer_start;

				elsif	transfer_start_req = '0' and transfer_end = '0'

				then	--number_of_packet_being_transferred := number_of_last_transferred_packet;

					--number_of_packet_being_transferred := number_of_packet_being_transferred + 1;	

					assert false 

					report "current_packet_being_transferred_monitor_fsm: transferring" 
	
					severity note;	

					next_state := transferring;

				end if;



			when	transferring =>

				if	transfer_start_req = '0' and transfer_end = '1' 

				then	number_of_last_transferred_packet := number_of_packet_being_transferred;

					number_of_packet_being_transferred := 0;


					assert false 

					report "current_packet_being_transferred_monitor_fsm: ending" 
	
					severity note;

					next_state := ending;

				elsif	transfer_start_req = '0' and transfer_end = '0' 

				then	--assert false 

					--report "current_packet_being_transferred_monitor_fsm: transferring" 
	
					--severity note;

					next_state := transferring;

				end if;



			when	ending =>

				if	transfer_end = '1'

				then	next_state := ending;

				elsif	transfer_end = '0'

				then	--number_of_packet_being_transferred := 0;

					--next_state := waiting_transfer_start;

					assert false 

					report "current_packet_being_transferred_monitor_fsm: waiting_packet_reception" 
	
					severity note;

					next_state := waiting_packet_reception;

				end if;

		end case; 

		state := next_state;

	end process current_packet_being_transferred_monitor;



-------------------------------------------------------------------------------------------------------------

---------- Print out statistics -----------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------



	print_out_input_workload_statistics: process 

		file input_workload_statistics_file : text open write_mode is "input.out";

		variable output_line : line;

		variable clock_counter : natural := 1;

		variable average : real;

	begin

		wait until pciclk'event and pciclk = '0'; 

	        write(output_line, string'("clock "));

		write(output_line, clock_counter);

	        write(output_line, string'(": "));

	        write(output_line, string'("rcvd data units size (in data blocks) = "));

		write(output_line, data_units_received_count);

	        write(output_line, string'(": "));

	        write(output_line, string'("cycles count = "));

		write(output_line, clock_counter_for_computing_data_units_received_rate);

	        write(output_line, string'(": "));

		write(output_line, string'("max. data unit size = "));

		write(output_line, data_unit_size);

	        write(output_line, string'(": "));

		write(output_line, string'("rate = "));

		write(output_line, data_units_received_rate);

		writeline(input_workload_statistics_file, output_line);

		clock_counter := clock_counter + 1;

	end process print_out_input_workload_statistics;



	print_out_buffer_statistics: process 

		file buffer_statistics_output_file : text open write_mode is "buffer.out";

		variable output_line : line;

		variable clock_counter : integer := 1;

--		variable verbosity : integer := 1; **** Output verbosity management has not been implemented yet...
	
	begin

		--wait until pciclk'event and pciclk = '1'; 

		wait until pciclk'event and pciclk = '0'; 

	        write(output_line, string'("clock "));

		write(output_line, clock_counter);

	        write(output_line, string'(": "));

--	        write(output_line, string'("FIFO size = "));

--		write(output_line, buffer_size);

--	        write(output_line, string'(": "));

--	        write(output_line, string'("occupancy = "));

--		write(output_line, occupancy);

--	        write(output_line, string'("("));

--		write(output_line, real(occupancy)/real(buffer_size));

--	        write(output_line, string'(" %) "));

--	        write(output_line, string'(": "));

--	        write(output_line, string'("fill level = "));

--		write(output_line, buff_fill_level);

--	        write(output_line, string'(": "));

--	        write(output_line, string'(": "));

	        write(output_line, string'("fill level (in bytes) = "));

		write(output_line, buffer_fill_level_in_bytes);

	        write(output_line, string'(": "));

	        write(output_line, string'("max fill level = "));

		write(output_line, max_buffer_fill_level);

	        write(output_line, string'(": "));

	        write(output_line, string'("received pkts = "));

		write(output_line, received_packets_counter);

	        write(output_line, string'(": "));

	        write(output_line, string'("transferred = "));

		write(output_line, transferred_packets_count);

	        write(output_line, string'(": "));

	        write(output_line, string'("dropped = "));

		write(output_line, dropped_packets_count);

		writeline(buffer_statistics_output_file, output_line);

		clock_counter := clock_counter + 1;

	end process print_out_buffer_statistics;





	print_out_nic_statistics: process 

		file nic_output_file : text open write_mode is "nic.out";

		variable output_line : line;

		variable clock_counter : natural := 1;

	begin


		wait until pciclk'event and pciclk = '0'; 

	        write(output_line, string'("clock "));

		write(output_line, clock_counter);

	        write(output_line, string'(": "));

	        write(output_line, string'("rcvd packets = "));

		write(output_line, received_packets_counter);

	        write(output_line, string'(": "));

--	        write(output_line, string'("transferring # "));

--		write(output_line, number_of_packet_being_transferred);

--	        write(output_line, string'(": "));

	        --write(output_line, string'("lat. cycles = "));

		--write(output_line, nic_processing_latency_cycles_count);

	        --write(output_line, string'(": "));

		--write(output_line, string'("ovrh. cycles = "));

		--write(output_line, nic_overhead_cycles_count);

--	        write(output_line, string'(": "));

--		write(output_line, string'("lat. per pkt = "));

--		write(output_line, nic_latency_cycles_count_per_packet);

--	        write(output_line, string'(": "));

--		write(output_line, string'("last processed pkt = "));

--		write(output_line, processing_cycle_of_the_last_processed_packet_by_nic);

--	        write(output_line, string'(": "));

		write(output_line, string'("non trans. cycles = "));

		write(output_line, nic_overhead_cycles_count + nic_processing_latency_cycles_count);

	        write(output_line, string'(": "));

		write(output_line, string'("trans. cycles = "));

		write(output_line, transmission_cycles_count);

	        write(output_line, string'(": "));

		write(output_line, string'("latency = "));

		write(output_line, max_nic_latency_cycles_count_per_packet);

	        write(output_line, string'(": "));

		write(output_line, string'("rate = "));

		if	(nic_overhead_cycles_count + nic_processing_latency_cycles_count) > 0

		then	write(output_line, real(transmission_cycles_count)/real(nic_overhead_cycles_count 

											+ nic_processing_latency_cycles_count + transmission_cycles_count));

		else	write(output_line, string'("0.0e0"));

		end if;

		writeline(nic_output_file, output_line);

		clock_counter := clock_counter + 1;

	end process print_out_nic_statistics;




	print_out_bus_arbitration_statistics: process 

		file bus_arb_output_file : text open write_mode is "arb.out";

		variable output_line : line;

		variable clock_counter : natural := 1;

--		variable average : real;

	begin

		wait until pciclk'event and pciclk = '0'; 

	        write(output_line, string'("clock "));

		write(output_line, clock_counter);

	        write(output_line, string'(": "));

--		write(output_line, received_packets_counter);

--	        write(output_line, string'(" received pkts"));

--	        write(output_line, string'(": "));

--	        write(output_line, string'("transferring # "));

--		write(output_line, number_of_packet_being_transferred);

--	        write(output_line, string'(": "));

		write(output_line, string'("non trans. cycles = "));

		write(output_line, arbitration_latency_cycles_count);

	        write(output_line, string'(": "));

		write(output_line, string'("trans. cycles = "));

		write(output_line, transmission_cycles_count);

	        write(output_line, string'(": "));

		--write(output_line, string'("lat. per pkt = "));

		--write(output_line, arbitration_latency_cycles_count_per_packet);

	        --write(output_line, string'(": "));

		--write(output_line, string'("last processed pkt = "));

		--write(output_line, processing_cycle_of_the_last_processed_packet_by_arb);

	        --write(output_line, string'(": "));

		write(output_line, string'("latency = "));

		write(output_line, max_arbitration_latency_cycles_count_per_packet);


	        write(output_line, string'(": "));

		write(output_line, string'("rate = "));

		if	arbitration_latency_cycles_count > 0

		then	write(output_line, real(transmission_cycles_count)/real(arbitration_latency_cycles_count + transmission_cycles_count));

		else	write(output_line, string'("0.0e0"));

		end if;

		writeline(bus_arb_output_file, output_line);

		clock_counter := clock_counter + 1;

	end process print_out_bus_arbitration_statistics;



	print_out_bus_acquisition_statistics: process 

		file bus_acq_output_file : text open write_mode is "acq.out";

		variable output_line : line;

		variable clock_counter : natural := 1;

--		variable average : real;

	begin

		wait until pciclk'event and pciclk = '0'; 

	        write(output_line, string'("clock "));

		write(output_line, clock_counter);

	        write(output_line, string'(": "));

--		write(output_line, received_packets_counter);

--	        write(output_line, string'(" received pkts"));

--	        write(output_line, string'(": "));

--	        write(output_line, string'("transferring # "));

--		write(output_line, number_of_packet_being_transferred);

--	        write(output_line, string'(": "));

		write(output_line, string'("non trans. cycles = "));

		write(output_line, acquisition_latency_cycles_count);

	        write(output_line, string'(": "));

		write(output_line, string'("trans. cycles = "));

		write(output_line, transmission_cycles_count);

--	        write(output_line, string'(": "));

--		write(output_line, string'("lat. per pkt = "));

--		write(output_line, acquisition_latency_cycles_count_per_packet);

--	        write(output_line, string'(": "));

--		write(output_line, string'("last processed pkt = "));

--		write(output_line, processing_cycle_of_the_last_processed_packet_by_acq);

	        write(output_line, string'(": "));

		write(output_line, string'("latency = "));

		write(output_line, max_acquisition_latency_cycles_count_per_packet);

	        write(output_line, string'(": "));

		write(output_line, string'("rate = "));

		if	acquisition_latency_cycles_count > 0

		then	write(output_line, real(transmission_cycles_count)/real(acquisition_latency_cycles_count + transmission_cycles_count));

		else	write(output_line, string'("0.0e0"));

		end if;

		writeline(bus_acq_output_file, output_line);

		clock_counter := clock_counter + 1;

	end process print_out_bus_acquisition_statistics;





	print_out_target_latency_statistics: process 

		file target_latency_output_file : text open write_mode is "memsub.out";

		variable output_line : line;

		variable clock_counter : natural := 1;

--		variable average : real;

	begin

		wait until pciclk'event and pciclk = '0'; 

	        write(output_line, string'("clock "));

		write(output_line, clock_counter);

	        write(output_line, string'(": "));

--		write(output_line, received_packets_counter);

--	        write(output_line, string'(" received pkts"));

--	        write(output_line, string'(": "));

--	        write(output_line, string'("transferring # "));

--		write(output_line, number_of_packet_being_transferred);

--	        write(output_line, string'(": "));

		write(output_line, string'("non trans. cycles = "));

		write(output_line, target_latency_cycles_count);

	        write(output_line, string'(": "));

		write(output_line, string'("trans. cycles = "));

		write(output_line, transmission_cycles_count);

	        write(output_line, string'(": "));

--		write(output_line, string'("lat. per pkt = "));

--		write(output_line, target_latency_cycles_count_per_packet);

--	        write(output_line, string'(": "));

--		write(output_line, string'("last processed pkt = "));

--		write(output_line, processing_cycle_of_the_last_processed_packet_by_memsub);

--	        write(output_line, string'(": "));

		write(output_line, string'("latency = "));

		write(output_line, max_target_latency_cycles_count_per_packet);

	        write(output_line, string'(": "));

		write(output_line, string'("rate = "));

		if	target_latency_cycles_count > 0

		then	write(output_line, real(transmission_cycles_count)/real(target_latency_cycles_count + transmission_cycles_count));

		else	write(output_line, string'("0.0e0"));

		end if;

		writeline(target_latency_output_file, output_line);

		clock_counter := clock_counter + 1;

	end process print_out_target_latency_statistics;


end V1;
