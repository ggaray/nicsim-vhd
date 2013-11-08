--    NICSim-vhd: A VHDL-based modelling and simulation of NIC's buffers
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

entity traffgen is  

	port (

		pktarrival				: out	bit		:= '0';

		pktsize					: out	integer		:= 0;  -- in bytes

		ethclk					: in	bit

	);

end traffgen;

architecture beh of traffgen is



	---------------       Input Workload Parameters   	---------------

	--constant 		packet_size_in_bytes 		: integer 	:= 72;		-- Minimum (Ethernet)

	constant 		packet_size_in_bytes 		: integer 	:= 1526;	-- Maximum (Ethernet)

	--constant 		packet_size_in_bytes 		: integer	:= 9026;	-- Jumbo Frames

	constant 		ifg 				: integer 	:= 96; 		-- Inter Frame Gap in bit times

	---------------       Variables Declarations   	---------------

	-- Buffer Memory

	constant eth_trace_size : integer 	:= 5;

	type pktsize_array is 

	  	array (integer range 1 to eth_trace_size) of integer; 

	shared variable pktsize_trace : pktsize_array;

	type inter_pkt_gap_array is 

	  	array (integer range 1 to eth_trace_size) of time; 

	shared variable inter_pkt_gap_trace : inter_pkt_gap_array;


begin  

	traffgen_fsm: process 

		type traffgen_state is (initiating_pktarrival_pulse_generation, 

					ending_pktarrival_pulse_generation, 

					waiting_packet_time, 

					waiting_ifg);

		variable state : traffgen_state := initiating_pktarrival_pulse_generation;  

		variable next_state : traffgen_state := initiating_pktarrival_pulse_generation;

		variable bit_time_counter : integer := packet_size_in_bytes * 8;

	begin

		wait until ethclk'event and ethclk = '1';

		case state is

			when	initiating_pktarrival_pulse_generation =>

				pktarrival <= '1';

				pktsize <= packet_size_in_bytes;

				--bit_time_counter := packet_size_in_bytes * 8;

				bit_time_counter := bit_time_counter - 1;

				next_state := ending_pktarrival_pulse_generation;

			when	ending_pktarrival_pulse_generation =>

				pktarrival <= '0';

				bit_time_counter := bit_time_counter - 1;

				next_state := waiting_packet_time;

			when	waiting_packet_time =>

				if	bit_time_counter = 0

				then	bit_time_counter := ifg;	

					bit_time_counter := bit_time_counter - 1;

				next_state := waiting_ifg;

				else	bit_time_counter := bit_time_counter - 1;

					next_state := waiting_packet_time;

				end if;

			when	waiting_ifg =>

				if	bit_time_counter = 0

				then	bit_time_counter := packet_size_in_bytes * 8;

					pktarrival <= '1';

					bit_time_counter := bit_time_counter - 1;

				next_state := ending_pktarrival_pulse_generation;

				else	bit_time_counter := bit_time_counter - 1;

					next_state := waiting_ifg;

				end if;

		end case; 

		state := next_state;

	end process traffgen_fsm;


end architecture beh; 

