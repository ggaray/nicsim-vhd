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

--use ieee.std_logic_1164.all;

use ieee.numeric_std.all;

use ieee.math_real.all;




entity buffmngr is

	port (

		pktarrival				: in	bit;		-- The rising edge indicates that the first bit of the packet arrives at the NIC

		pktsize					: in	integer;	-- in bytes

		transfer_start_req			: out	bit 		:= '1';

		transfer_end				: in	bit;

		ethclk					: in	bit;

		pciclk					: in	bit;

		pktreceived				: out	bit 		:= '0'; -- The rising edge indicates that all the bits have been received

		payload_size_in_data_blocks		: out	integer  	:= 0;

		buffer_fill_level_in_bytes		: out	integer		:= 0;	

		buffer_fill_level_in_data_units		: out	integer		:= 0;	

		max_buffer_fill_level			: out	integer		:= 0;	

		dropped_packets_count			: out	integer		:= 0;

		buffer_size_in_data_units		: out	integer		:= 10

	);

end buffmngr;




architecture V1 of buffmngr is



	---------------       Buffer configuration   	---------------

	constant buffer_size : integer := 10000;	-- Number of memory locations



	---------------       Bus width configuration   	---------------

	--constant bus_width_in_bits 			: integer 		:= 32; 				-- PCI 33/32

	constant bus_width_in_bits 			: integer 		:= 64; 				-- PCI 66/64, PCI-X 133/64

	constant bus_width_in_bytes 			: integer 		:= bus_width_in_bits/8; 	-- PCI bus

	-- ***To be removed

	--constant bus_width_in_bytes 			: integer 		:= 4; 				-- PCI bus

	--constant bus_width_in_bytes 			: integer 		:= 8; 				-- PCI-X bus



	---------------        Descriptor size configuration 	---------------

	constant descriptor_size_in_bytes : integer := 16;  -- Descriptor size in bytes



-- ****** In the future, constant pcilck_period should be removed a function based on the pciclk signal should be implemented

	--constant pciclk_period : time := 0.03030303 us; -- PCI 33 

	--constant pciclk_period : time := 0.015151515 us; -- PCI 66

	constant pciclk_period : time := 0.007518797 us; -- PCI-X 133 

	--constant pciclk_period : time := 0.003759398 us;  -- PCI-X 266 

	--constant pciclk_period : time := 0.001876173 us; -- PCI-X 533




-- ******* to be removed, this constant is not used

	--constant descriptor_size_in_dwords : integer := 4;  

	--constant descriptor_size_in_dwords : integer := 2;  -- Descriptor size in data blocks (PCI-X bus)


-- ******* to be removed, constant packet_identification_latency is not used

	--constant packet_identification_latency : time := 2 us;

	---------------        Size of the Ethernet frame fields	---------------

	constant 		preamble_in_bytes					: integer	:= 7;

	constant		sof_in_bytes						: integer	:= 1;

	constant		destination_address_in_bytes				: integer	:= 6;

	constant		source_address_in_bytes					: integer	:= 6;

	constant		length_in_bytes						: integer	:= 2;

	constant		checksum_in_bytes					: integer	:= 4;

	--constant header_fields_length_in_octets 		: integer := 22;	-- In octets

	--constant trailer_fields_length_in_octets 		: integer := 4;		-- In octets

	-- Data structure used for data FIFO (implemented as a circular buffer)

	type memory_array is 

	  	array (integer range 1 to buffer_size) of real; 

	shared variable 	nic_buffer_memory : memory_array;

	-- FIFO pointers for implementing buffer ring

	-- buff_in_ptr: pointer to the memory location for storing the next 
	-- 		received packet  

	shared	variable	 buff_in_ptr 						: integer 	:= 1;	

	-- buff_out_ptr: Pointer to the memory location of the next packet 
	--		 to transfer from the NIC to the system memory

	shared	variable 	buff_out_ptr 						: integer 	:= 0;	

	signal			pktreceived_value 					: bit 		:= '0';

	-- Variables used for statistics and debugging 

	shared variable 	buff_fill_level 					: integer 	:= 0;		-- in bytes

	shared variable 	occupancy						: integer 	:= 0;  		-- in memory locations

	shared variable 	max_buff_fill_level 					: integer 	:= 0;	-- in bytes

	shared variable 	total_received_packets 					: integer 	:= 0;

	shared variable 	total_dropped_packets 					: integer 	:= 0;

	shared variable 	input_packet_size 					: integer 	:= 0;

	-- Auxiliary procedure inc is used to increment pointers

	procedure inc (variable ptr : inout integer) is

	begin

		if	ptr = buffer_size

		then	ptr := 1;

		else	ptr := ptr + 1;

		end if;

	end procedure inc;



-- Architecture begin

begin

	pktreceived <= pktreceived_value;


	network_to_nic_packet_arrival: process 

		--file buffer_fill_level_output_file : text open write_mode is "pkt_arrival_fsm.out";

		variable 	output_line 						: line;

		variable 	total_bits_received_count 				: integer	:= 0;

		variable 	pktsize_in_bits 					: integer 	:= 0;

		variable 	payload_size_in_octets					 : integer;

		type pkt_arrival_state is (idle, waiting_end_of_packet, updating_buffer);

		variable arrival_state : pkt_arrival_state := idle;  

		variable next_arrival_state : pkt_arrival_state := idle;

	begin

		wait until ethclk'event and ethclk = '1';

		case arrival_state is

			when	idle =>

				total_bits_received_count := 0;

				pktsize_in_bits := 0;

				if 	pktarrival = '0' 

				then	

			        --write(output_line, string'("state = idle, pktarrival = '0' "));

				--writeline(buffer_fill_level_output_file, output_line);

					next_arrival_state := idle;

				elsif	pktarrival = '1'

				then	pktsize_in_bits := pktsize * 8;

					-- Here, packet payload size (in octets) is computed. The actual size of the input packet (pktsize) is measured in octets.

					payload_size_in_octets := pktsize - (preamble_in_bytes + sof_in_bytes + destination_address_in_bytes 

											+ source_address_in_bytes + length_in_bytes + checksum_in_bytes);

					next_arrival_state := waiting_end_of_packet;

			 	--write(output_line, string'("state = idle, pktarrival = '1' "));

				--writeline(buffer_fill_level_output_file, output_line);

				end if;

			when	waiting_end_of_packet =>

			        --write(output_line, string'("waiting_end_of_packet "));

			        --write(output_line, string'(" occupancy =  "));

				--write(output_line, occupancy);

				if	total_bits_received_count = pktsize_in_bits

				then	--write(output_line, string'(" total_bits_received_count = pktsize_in_bits "));

					--write(output_line, string'(" total_bits_received_count =  "));

					--write(output_line, total_bits_received_count);

					--write(output_line, string'(" pktsize_in_bits =  "));

					--write(output_line, pktsize_in_bits);

					--writeline(buffer_fill_level_output_file, output_line);

					pktreceived_value <= '1';

					total_received_packets := total_received_packets + 1; 

					next_arrival_state := updating_buffer;

				else	total_bits_received_count := total_bits_received_count + 1;

					--write(output_line, string'(" total_bits_received_count := total_bits_received_count + 1 "));

					--write(output_line, string'(" total_bits_received_count =  "));

					--write(output_line, total_bits_received_count);

					--write(output_line, string'(" pktsize_in_bits =  "));

					--write(output_line, pktsize_in_bits);

					--writeline(buffer_fill_level_output_file, output_line);

					next_arrival_state := waiting_end_of_packet;

				end if;


			when	updating_buffer =>

			        --write(output_line, string'(" updating_buffer "));

			        --write(output_line, string'(" occupancy =  "));

				--write(output_line, occupancy);

				if	occupancy = 0

				-- Packet payload is stored in the memory location pointed by buff_in_ptr.

				-- Data are stored in data block units. The size of a data block depends on the bus width.

				then	--nic_buffer_memory(buff_in_ptr) := real(payload_size_in_octets)/real(4); 

					nic_buffer_memory(buff_in_ptr) := real(payload_size_in_octets)/real(bus_width_in_bytes);

				        --write(output_line, string'(" nic_buffer_memory(buff_in_ptr) := "));

					--write(output_line, nic_buffer_memory(buff_in_ptr));

					buff_out_ptr := 1; 

					inc(buff_in_ptr);

					occupancy := occupancy + 1;

					wait until pciclk'event and pciclk = '1';

					buff_fill_level := 

						buff_fill_level + (pktsize - (preamble_in_bytes + sof_in_bytes)) + descriptor_size_in_bytes;

					input_packet_size := pktsize;

					wait for pciclk_period;

					input_packet_size := 0;

				       --write(output_line, string'(" buff_in_ptr =  "));

					--write(output_line, buff_in_ptr);

					--writeline(buffer_fill_level_output_file, output_line);

					pktreceived_value <= '0';

					next_arrival_state := idle;

				elsif	occupancy > 0

					and occupancy < buffer_size - 1

				then	--nic_buffer_memory(buff_in_ptr) := payload_size_in_octets/4; 

			 		--write(output_line, string'("if occupancy > 0 and and occupancy < buffer_size - 1"));

				        --write(output_line, string'(" occupancy ="));

					--write(output_line, occupancy);

					--nic_buffer_memory(buff_in_ptr) := real(payload_size_in_octets)/real(4);

					nic_buffer_memory(buff_in_ptr) := real(payload_size_in_octets)/real(bus_width_in_bytes);

			 		--write(output_line, string'(" nic_buffer_memory(buff_in_ptr) := "));

					--write(output_line, nic_buffer_memory(buff_in_ptr));

					inc(buff_in_ptr);

			   		--write(output_line, string'(" buff_in_ptr =  "));

					--write(output_line, buff_in_ptr);
	
					occupancy := occupancy + 1;

					wait until pciclk'event and pciclk = '1';

					buff_fill_level := 

						buff_fill_level + (pktsize - (preamble_in_bytes + sof_in_bytes)) + descriptor_size_in_bytes;

					input_packet_size := pktsize;

					wait for pciclk_period;

					input_packet_size := 0;

					--writeline(buffer_fill_level_output_file, output_line);

					pktreceived_value <= '0';

					next_arrival_state := idle;

				elsif	occupancy = buffer_size - 1

				then	--nic_buffer_memory(buff_in_ptr) := payload_size_in_octets/4; 

					--nic_buffer_memory(buff_in_ptr) := real(payload_size_in_octets)/real(4);

					nic_buffer_memory(buff_in_ptr) := real(payload_size_in_octets)/real(bus_width_in_bytes);

					occupancy := occupancy + 1;

					wait until pciclk'event and pciclk = '1';

					buff_fill_level := 

						buff_fill_level + (pktsize - (preamble_in_bytes + sof_in_bytes)) + descriptor_size_in_bytes;

					input_packet_size := pktsize;

					wait for pciclk_period;

					input_packet_size := 0;

					pktreceived_value <= '0';

					next_arrival_state := idle;	

				elsif	occupancy = buffer_size

				then	total_dropped_packets := total_dropped_packets + 1;

					input_packet_size := pktsize;

					wait for pciclk_period;

					input_packet_size := 0;

					assert false 

					report "total_dropped_packets := total_dropped_packets + 1" 
	
					severity warning;

					pktreceived_value <= '0';

					next_arrival_state := idle;

				end if;

					-- Total packets received is used for statistics

--					total_received_packets := total_received_packets + 1; 

					-- input_packet size is used for statistics

--					input_packet_size := pktsize;

--					wait for pciclk_period;

--					input_packet_size := 0;

--				else	total_dropped_packets := total_dropped_packets + 1; 	

--				input_packet_size := pktsize;

--				wait for pciclk_period;

--				input_packet_size := 0;				

--				end if;

--				arrival_next_state := idle;

		end case; 

		arrival_state := next_arrival_state;

--		wait until pktarrival'event and pktarrival = '1';

		-- Variable packets_received_count is used for obtaining statistics

		--wait until pciclk'event and pciclk = '1';

		--buff_fill_level := buff_fill_level + 1;

--		wait for packet_identification_latency;

		--nic_buffer_memory(buff_in_ptr) := pktsize;

		--buff_fill_level := buff_fill_level + pktsize;

	
	end process network_to_nic_packet_arrival;






	nic_to_memory_packet_transfer: process 

		-- States of Packet Transfer FSM 
		
		type pkt_transfer_state is (idle, 

					    requesting_transfer, 

					    transferring, 

					    updating_buffer);

		variable transfer_state : pkt_transfer_state := idle;  

		variable next_transfer_state : pkt_transfer_state := idle;

		begin

		--wait until pciclk'event and pciclk = '1';

		wait until ethclk'event and ethclk = '1';

		case transfer_state is

			when	idle =>

				transfer_start_req <= '1';

				payload_size_in_data_blocks <= 0;

				buff_out_ptr := 0;

				if 	buff_fill_level = 0 

				then	next_transfer_state := idle;

				elsif 	buff_fill_level > 0 and transfer_end = '0'

				then	assert false 

					report "pkt_transfer_fsm: requesting_transfer" 
	
					severity note;

					next_transfer_state := requesting_transfer;

				end if;

			when	requesting_transfer =>

				--if 	buff_out_ptr = buffer_size	

				--then	buff_out_ptr := 1;

				--else	buff_out_ptr := buff_out_ptr + 1;

				--end if;

				inc(buff_out_ptr);

				payload_size_in_data_blocks <= integer(ceil(nic_buffer_memory(buff_out_ptr)));

				--transfer_start_req <= '1';

				--wait for pciclk_period;

					assert false 

					report "pkt_transfer_fsm: transferring" 
	
					severity note;

				transfer_start_req <= '0';

				next_transfer_state := transferring;

			when	transferring =>

				--wait until transfer_end'event and transfer_end = '1';

				if	transfer_end = '0'

				then	next_transfer_state := transferring;

				elsif	transfer_end = '1'

				then	assert false 

					report "pkt_transfer_fsm: updating_buffer" 
	
					severity note;

					next_transfer_state := updating_buffer;

				end if;

			when	updating_buffer =>

				--wait until transfer_end'event and transfer_end = '1';

				if	occupancy = buffer_size

				then	wait until pciclk'event and pciclk = '0';

					buff_fill_level := buff_fill_level - 

						(integer(nic_buffer_memory(buff_out_ptr)*real(bus_width_in_bytes)) + destination_address_in_bytes 

								+ source_address_in_bytes + length_in_bytes + checksum_in_bytes + descriptor_size_in_bytes);

--						(integer(nic_buffer_memory(buff_out_ptr)*real(bus_width_in_bytes)) + preamble_in_bytes + sof_in_bytes 
															
--																+ descriptor_size_in_bytes);

--						(integer(nic_buffer_memory(buff_out_ptr)*real(4)) + header_fields_length_in_octets + trailer_fields_length_in_octets);

					occupancy := occupancy - 1;

					inc(buff_in_ptr);

					inc(buff_out_ptr);

					next_transfer_state := idle;

				elsif	occupancy = 1

				then	wait until pciclk'event and pciclk = '0';

					buff_fill_level := buff_fill_level - 

						(integer(nic_buffer_memory(buff_out_ptr)*real(bus_width_in_bytes)) + destination_address_in_bytes 

								+ source_address_in_bytes + length_in_bytes + checksum_in_bytes + descriptor_size_in_bytes);

--						(integer(nic_buffer_memory(buff_out_ptr)*real(bus_width_in_bytes)) + preamble_in_bytes + sof_in_bytes 
															
--																+ descriptor_size_in_bytes);


--						(integer(nic_buffer_memory(buff_out_ptr)*real(4)) + header_fields_length_in_octets + trailer_fields_length_in_octets);

					occupancy := occupancy - 1;

					-- Reset pointers to buffer empty state

					buff_out_ptr := 0;

					buff_in_ptr := 1;

					next_transfer_state := idle;

				elsif	occupancy > 1 

					and occupancy < buffer_size

				then	wait until pciclk'event and pciclk = '0';	

					buff_fill_level := buff_fill_level - 

						(integer(nic_buffer_memory(buff_out_ptr)*real(bus_width_in_bytes)) + destination_address_in_bytes 

								+ source_address_in_bytes + length_in_bytes + checksum_in_bytes + descriptor_size_in_bytes);

--						(integer(nic_buffer_memory(buff_out_ptr)*real(bus_width_in_bytes)) + preamble_in_bytes + sof_in_bytes 
															
--																+ descriptor_size_in_bytes);


--						(integer(nic_buffer_memory(buff_out_ptr)*real(4)) + header_fields_length_in_octets + trailer_fields_length_in_octets);

					occupancy := occupancy - 1;

					inc(buff_out_ptr);

					assert false 

					report "pkt_transfer_fsm: idle" 
	
					severity note;

					next_transfer_state := idle;

				end if;

		end case; 

		transfer_state := next_transfer_state;

	end process nic_to_memory_packet_transfer;

--	traffic_monitor_fsm: process 

--		type traffic_monitor_state is (waiting_zero, waiting_one);

--		variable monitor_state : traffic_monitor_state := idle;  

--		variable next_monitor_state : traffic_monitor_state := idle;

--		begin

--		wait until pciclk'event and pciclk = '1';

--		case monitor_state is

--			when	waiting_zero =>

--				if	transfer_start_req_value = '1'

--				then	total_cycles_count := total_cycles_count + 1;

--					next_monitor_state := waiting_zero;

--				elsif	transfer_start_req_value = '0'

--				then	total_cycles_count := total_cycles_count + 1;

--					total_packets_plus_descriptors_size := total_packets_plus_descriptors_size 

--									+ ((pktsize - header_fields) + descriptor_size);

--				end if;

--			when	waiting_one =>

--				if	transfer_start_req_value = '0'

--				then	total_cycles_count := total_cycles_count + 1;

--					next_monitor_state := waiting_one;

--				elsif	transfer_start_req_value = '1'

--					total_cycles_count := total_cycles_count + 1;

--					next_monitor_state := waiting_zero;

--		end case; 

--		transfer_state := next_transfer_state;

--	end process traffic_monitor_fsm;



--	transfer_end_driver: process 

--		-- Auxiliary function for verifying buffer empty condition

--		function buffer_empty (in_ptr : in integer; out_ptr : in integer) 

--								return boolean is

--			variable result : boolean := false;

--		begin

--			if	in_ptr = out_ptr

--			then	result := true;

--			end if;

--			return result;

--		end function buffer_empty;

--	begin

--		wait until transfer_end'event and transfer_end = '1';

--		wait until pciclk'event and pciclk = '0';

--		buff_fill_level := buff_fill_level - nic_buffer_memory(buff_out_ptr);

--		occupancy := occupancy - 1;

--		if	buffer_empty(buff_in_ptr, buff_out_ptr)

--		then	buff_out_ptr := 0;  

--		else	buff_out_ptr := buff_out_ptr + 1;

--		end if;

--	end process transfer_end_driver;





	max_buff_fill_level_monitor: process 

	begin

		wait until pciclk'event and pciclk = '1';

		if	buff_fill_level > max_buff_fill_level 

		then	max_buff_fill_level := buff_fill_level;

		end if;

	end process max_buff_fill_level_monitor;



	output_driver: process 

	begin

		wait until pciclk'event and pciclk = '0'; 

		buffer_fill_level_in_bytes <= buff_fill_level;

		max_buffer_fill_level <= max_buff_fill_level;

		dropped_packets_count <= total_dropped_packets;

		buffer_size_in_data_units <= buffer_size;

	end process output_driver;


--	print_out_statistics: process 

--		file buffer_fill_level_output_file : text open write_mode is "buffer.out";

--		variable output_line : line;

--		variable clock_counter : integer := 1;

--		variable verbosity : integer := 1; **** Output verbosity management has not been implemented yet...
	
--	begin

--		case verbosity is

--			when	0 =>

--				wait for 1 ns;

--			when	1 =>

--				wait for 1 ns;

--			when	2 =>

--				wait for 1 ns;

--		end case; 

		--wait until pciclk'event and pciclk = '1'; 

	--	wait until pciclk'event and pciclk = '0'; 

--	        write(output_line, string'("clock "));

--		write(output_line, clock_counter);

--	        write(output_line, string'(": "));

	--      write(output_line, string'("FIFO size = "));

	--	write(output_line, buffer_size);

	--      write(output_line, string'(": "));

--	        write(output_line, string'("occupancy = "));

--	--	write(output_line, occupancy);

--	        write(output_line, string'("("));

--		write(output_line, real(occupancy)/real(buffer_size));

--	        write(output_line, string'(" %) "));

--	        write(output_line, string'(": "));

--	        write(output_line, string'("fill level = "));

--		write(output_line, buff_fill_level);

--	        write(output_line, string'(": "));

	--      write(output_line, string'("max fill level = "));

	--	write(output_line, max_buff_fill_level);

	--       write(output_line, string'(": "));

--	        write(output_line, string'("input pkt size = "));

--		write(output_line, input_packet_size);

--	        write(output_line, string'(": "));

	--        write(output_line, string'("total packet arrivals = "));

	--	write(output_line, total_received_packets + total_dropped_packets);

	--        write(output_line, string'(": "));

	--        write(output_line, string'("received = "));

	--	write(output_line, total_received_packets);

	--        write(output_line, string'(": "));

	--        write(output_line, string'("dropped = "));

	--	write(output_line, total_dropped_packets);

	--	writeline(buffer_fill_level_output_file, output_line);

	--	clock_counter := clock_counter + 1;

	--end process print_out_statistics;

end V1;
