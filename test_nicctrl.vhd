--    <one line to give the program's name and a brief idea of what it does.>
--    Copyright (C) 2013 Godofredo R. Garay <godofredo_garay ("at") yahoo.com>

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


library ieee;

use ieee.std_logic_1164.all;



entity test_nicctrl is


end;

architecture BENCH of test_nicctrl is


component clkgen is

	port (

		pciclk						: out	bit;

		nicclk						: out	bit;

		ethclk						: out	bit

	);

end component;


component traffgen is

	port (

		pktarrival					: out	bit;

		pktsize						: out	integer;

		ethclk						: in	bit
	);

end component;


component buffmngr is

	port (

		pktarrival					: in	bit;

		pktsize						: in	integer;

		transfer_start_req				: out	bit;

		transfer_end					: in	bit;
	
		ethclk						: in	bit;

		pciclk						: in	bit;

		pktreceived					: out	bit;

		payload_size_in_data_blocks			: out	integer;

		buffer_fill_level_in_bytes			: out	integer;	

		buffer_fill_level_in_data_units			: out	integer;	

		max_buffer_fill_level				: out	integer;	

		dropped_packets_count				: out	integer;

		buffer_size_in_data_units			: out	integer

	);

end component;


component nicctrl is

	port (

		transfer_start_req				: in		bit;

		transfer_end					: out		bit;

		req						: out		bit;

		gnt						: in		bit;

		frame						: inout		std_logic;

		irdy						: out		bit;

		trdy						: in		bit;

		AD						: out		bit;

		payload_size_in_data_blocks			: in		integer;

		payload_transfer_req				: out		bit;

		descriptor_transfer_req				: out		bit;

		payload_transfer_end				: in		bit;

		descriptor_transfer_end				: in		bit;		

		payload_transfer_aborted			: in		bit;

		resume_aborted_payload_transfer			: out		bit;

		descriptor_transfer_aborted			: in		bit;

		resume_aborted_descriptor_transfer		: out		bit;

		acq_latency_cycles_counter_out			: out		integer;

		nic_proc_latency_cycles_counter_out		: out		integer;

		nicclk						: in 		bit;

		pciclk						: in 		bit
	);

end component;


component dmactrl is

	port (

		payload_transfer_req				: in	bit;

		descriptor_transfer_req				: in	bit;

		payload_transfer_end				: out	bit;

		descriptor_transfer_end				: out	bit;

		payload_transfer_aborted			: out	bit;

		descriptor_transfer_aborted			: out	bit;

		resume_aborted_payload_transfer			: in	bit;

		resume_aborted_descriptor_transfer		: in	bit;

		irdy						: in	bit;

		trdy						: in	bit;

		gnt						: in	bit;

		payload_size_in_data_blocks			: in	integer;

		dma_cycles_counter_out				: out	integer;

	  	burst_cycles_counter_out			: out	integer;	

		pciclk						: in 	bit

	);

end component;


component arbiter is

	port (

		req						: in	bit;

	  	gnt						: out	bit;

--	  	burst_cycles_counter_out			: out	integer;	

	  	arb_latency_cycles_counter_out			: out	integer;	

	  	pciclk						: in	bit

	);

end component;


component memsub is

	port (

		irdy						: in		bit;

		trdy						: out		bit;

		frame						: inout		std_logic;

		AD						: in		bit;

		target_latency_cycles_counter_out		: out		integer;	-- Always is 1 cycle

		pciclk						: in 		bit
	);

end component;


component othermaster is	

	port (

		frame		: inout		std_logic;

		pciclk		: in 		bit

	);

end component;


component statsgen is

	port (

		pciclk						: in	bit;

		ethclk						: in	bit;

		pktreceived					: in	bit;

		pktsize						: in	integer;

		transfer_start_req				: in	bit;

		--payload_transfer_req				: in	bit;

		--payload_transfer_aborted			: in	bit;

		--resume_aborted_payload_transfer		: in	bit;

		--descriptor_transfer_req			: in	bit;

		--descriptor_transfer_aborted			: in	bit;

		--resume_aborted_descriptor_transfer		: in	bit;

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

end component;

signal sig_pciclk, sig_nicclk, sig_ethclk : bit;

signal sig_frame : std_logic;

signal sig_pktarrival, sig_transfer_start_req, sig_transfer_end, sig_req, sig_gnt, sig_irdy, sig_payload_transfer_req, sig_descriptor_transfer_req, sig_payload_transfer_end, sig_descriptor_transfer_end, sig_payload_transfer_aborted, sig_descriptor_transfer_aborted, sig_resume_aborted_payload_transfer, sig_resume_aborted_descriptor_transfer, sig_trdy, sig_AD, sig_pktreceived : bit;

signal sig_payload_size_in_data_blocks, sig_dma_cycles_counter_out, sig_buffer_fill_level_in_bytes, sig_buffer_fill_level_in_data_units, sig_burst_cycles_counter_out, sig_arb_latency_cycles_counter_out, sig_pktsize, sig_acq_latency_cycles_counter_out, sig_nic_proc_latency_cycles_counter_out, sig_target_latency_cycles_counter_out, sig_clock_counter_out, sig_max_buffer_fill_level, sig_dropped_packets_count, sig_buffer_size_in_data_units : integer;



begin


-- Components Port Map

clkgen_comp: clkgen port map (pciclk => sig_pciclk, nicclk => sig_nicclk, ethclk => sig_ethclk);



traffgen_comp : traffgen port map (pktarrival => sig_pktarrival, pktsize => sig_pktsize, ethclk => sig_ethclk);



buffmngr_comp: buffmngr port map (pktarrival => sig_pktarrival, pktsize => sig_pktsize, transfer_start_req => sig_transfer_start_req, transfer_end => sig_transfer_end, ethclk => sig_ethclk, pciclk => sig_pciclk, pktreceived => sig_pktreceived, payload_size_in_data_blocks => sig_payload_size_in_data_blocks, buffer_fill_level_in_bytes => sig_buffer_fill_level_in_bytes, buffer_fill_level_in_data_units => sig_buffer_fill_level_in_data_units, max_buffer_fill_level => sig_max_buffer_fill_level, dropped_packets_count => sig_dropped_packets_count, buffer_size_in_data_units => sig_buffer_size_in_data_units);

		

nicctrl_comp: nicctrl port map (transfer_start_req => sig_transfer_start_req, transfer_end => sig_transfer_end, req => sig_req, gnt => sig_gnt, frame => sig_frame, irdy => sig_irdy, trdy => sig_trdy, AD => sig_AD, payload_size_in_data_blocks => sig_payload_size_in_data_blocks, payload_transfer_req => sig_payload_transfer_req, descriptor_transfer_req => sig_descriptor_transfer_req, payload_transfer_end => sig_payload_transfer_end, descriptor_transfer_end => sig_descriptor_transfer_end, payload_transfer_aborted => sig_payload_transfer_aborted, resume_aborted_payload_transfer => sig_resume_aborted_payload_transfer, descriptor_transfer_aborted => sig_descriptor_transfer_aborted, resume_aborted_descriptor_transfer => sig_resume_aborted_descriptor_transfer, acq_latency_cycles_counter_out => sig_acq_latency_cycles_counter_out, nic_proc_latency_cycles_counter_out => sig_nic_proc_latency_cycles_counter_out, nicclk => sig_nicclk, pciclk => sig_pciclk);



dmactrl_comp: dmactrl port map (payload_transfer_req => sig_payload_transfer_req, descriptor_transfer_req => sig_descriptor_transfer_req, payload_transfer_end => sig_payload_transfer_end, descriptor_transfer_end => sig_descriptor_transfer_end, payload_transfer_aborted => sig_payload_transfer_aborted, descriptor_transfer_aborted => sig_descriptor_transfer_aborted, resume_aborted_payload_transfer => sig_resume_aborted_payload_transfer, resume_aborted_descriptor_transfer => sig_resume_aborted_descriptor_transfer, irdy => sig_irdy, trdy => sig_trdy, gnt => sig_gnt, payload_size_in_data_blocks => sig_payload_size_in_data_blocks, dma_cycles_counter_out => sig_dma_cycles_counter_out, burst_cycles_counter_out => sig_burst_cycles_counter_out, pciclk => sig_pciclk);



arbiter_comp: arbiter port map (req => sig_req, gnt => sig_gnt, arb_latency_cycles_counter_out => sig_arb_latency_cycles_counter_out, pciclk => sig_pciclk);



memsub_comp: memsub port map (irdy => sig_irdy, trdy => sig_trdy, frame => sig_frame, AD => sig_AD, target_latency_cycles_counter_out => sig_target_latency_cycles_counter_out, pciclk => sig_pciclk);



statsgen_comp: statsgen port map (pciclk => sig_pciclk, ethclk => sig_ethclk, pktreceived => sig_pktreceived, pktsize => sig_pktsize,transfer_start_req => sig_transfer_start_req, transfer_end => sig_transfer_end, buffer_fill_level_in_bytes => sig_buffer_fill_level_in_bytes, buffer_fill_level_in_data_units => sig_buffer_fill_level_in_data_units, max_buffer_fill_level => sig_max_buffer_fill_level, dropped_packets_count => sig_dropped_packets_count, nic_proc_latency_cycles_counter_out => sig_nic_proc_latency_cycles_counter_out, acq_latency_cycles_counter_out => sig_acq_latency_cycles_counter_out, arb_latency_cycles_counter_out => sig_arb_latency_cycles_counter_out, target_latency_cycles_counter_out => sig_target_latency_cycles_counter_out, burst_cycles_counter_out => sig_burst_cycles_counter_out, dma_cycles_counter_out => sig_dma_cycles_counter_out, clock_counter_out => sig_clock_counter_out);



othermaster_comp: othermaster port map (frame => sig_frame, pciclk => sig_pciclk);


end BENCH;
