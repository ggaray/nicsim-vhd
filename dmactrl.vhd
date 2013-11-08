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





entity dmactrl is

	port (

		payload_transfer_req			: in	bit;

		descriptor_transfer_req			: in	bit;

		payload_transfer_end			: out	bit		:= '0';

		descriptor_transfer_end			: out	bit		:= '0';

		payload_transfer_aborted		: out	bit		:= '0';

		descriptor_transfer_aborted		: out	bit		:= '0';

		resume_aborted_payload_transfer		: in	bit;

		resume_aborted_descriptor_transfer	: in	bit;

		irdy					: in	bit;

		trdy					: in	bit;

		gnt					: in	bit;

		payload_size_in_data_blocks		: in	integer;

		dma_cycles_counter_out			: out	integer		:= 0;

	  	burst_cycles_counter_out		: out	integer 	:= 0;	

		pciclk					: in 	bit

	);

end dmactrl;




architecture V1 of dmactrl is


	---------------       Bus width configuration   	---------------

	--constant bus_width_in_bits 			: integer 		:= 32; 	-- PCI 33/32

	constant bus_width_in_bits 			: integer 		:= 64; 	-- PCI 66/64, PCI-X 133/64

	constant bus_width_in_bytes 			: integer 		:= bus_width_in_bits/8;

	-- ***To be removed

	--constant 	bus_width_in_bytes 		: integer 	:= 4; 	-- PCI bus

	--constant 	bus_width_in_bytes 		: integer 	:= 8; 	-- PCI-X bus


	---------------        Burst size configuration 	--------------- 

        constant	dma_burst_size_in_bytes		: integer	:= 256;		-- DMA busrt size = 256 bytes

        --constant	dma_burst_size_in_bytes		: integer	:= 512;		-- DMA busrt size = 512 bytes

        --constant	dma_burst_size_in_bytes		: integer	:= 1024;	-- DMA busrt size = 1024 bytes

        --constant	dma_burst_size_in_bytes		: integer	:= 2048;	-- DMA busrt size = 2048 bytes

        --constant	dma_burst_size_in_bytes		: integer	:= 2048;	-- DMA busrt size = 4096 bytes

	constant	dma_burst_size_in_cycles	: integer	:= dma_burst_size_in_bytes/bus_width_in_bytes; 

	--constant	dma_burst_size_in_cycles	: integer	:= 64;		-- DMA busrt size = 512 bytes (PCI-X bus)

	--constant	dma_burst_size_in_cycles	: integer	:= 128;		-- DMA busrt size = 1024 bytes (PCI-X bus)

	--constant	dma_burst_size_in_cycles	: integer	:= 256;		-- DMA busrt size = 2048 bytes (PCI-X bus)

	--constant	dma_burst_size_in_cycles	: integer	:= 512;		-- DMA busrt size = 4096 bytes (PCI-X bus)



	---------------        Descriptor size configuration 	---------------

	--constant	descriptor_size_in_data_blocks	: integer	:= 2;		-- Descriptor size in data blocks (PCI-X bus)

	--constant	descriptor_size_in_data_blocks	: integer	:= 4;		-- Descriptor size in data blocks (PCI bus)

	constant 	descriptor_size_in_bytes 	: integer 	:= 16;  	-- Descriptor size in bytes

	constant 	descriptor_size_in_data_blocks 	: integer 	:= descriptor_size_in_bytes/bus_width_in_bytes;  


	---------------        Injection rate configuration 	---------------

	-- ******* To be used in the future, not implemented yet...

	--constant nic_injection_rate : natural := 1;	-- NIC/PCI bus bandwidth ratio

	constant	nic_injection_rate		: natural	:= 1;		-- NIC/PCI bus bandwidth ratio 



-- ****** In the future, constant pcilck_period should be removed a function based on the pciclk signal should be implemented
 
	--constant	pciclk_period			: time		:= 0.03030303 us; 	-- PCI 33

	--constant	pciclk_period			: time		:= 0.015151515 us; 	-- PCI 66

	constant	pciclk_period			: time		:= 0.007518797 us; 	-- PCI-X 133 

	--constant	pciclk_period			: time		:= 0.003759398 us;  	-- PCI-X 266 

	--constant	pciclk_period			: time		:= 0.001876173 us; 	-- PCI-X 533



	---------------       Variables Declarations   	---------------

	shared variable burst_cycles_counter 		: integer;

	-- A variable is declared for each output signal. 	

	shared variable payload_transfer_end_value 	: bit := '0';  

	shared variable descriptor_transfer_end_value 	: bit := '0';

	shared variable payload_transfer_aborted_value 	: bit := '0';

	shared variable descriptor_transfer_aborted_value : bit := '0';

	shared variable dma_cycles_counter 		: integer := 0;  

begin

	dma_controller_fsm: process 

		type controller_state is (idle, 

					  transferring_payload, 

					  transferring_descriptor, 
		
					  transferring_payload_stalled, 

		   			  transferring_descriptor_stalled);

		variable state : controller_state := idle;  

		variable next_state : controller_state := idle;  

	begin

		wait until pciclk'event and pciclk = '1';

		case state is

			when idle =>

				payload_transfer_end_value := '0';  

				descriptor_transfer_end_value := '0';

				payload_transfer_aborted_value := '0';

				descriptor_transfer_aborted_value := '0';

				burst_cycles_counter := 0;

				if 	payload_transfer_req = '1' 

					and descriptor_transfer_req = '1'

					and resume_aborted_payload_transfer = '1'

					and resume_aborted_descriptor_transfer = '1' 
	
				then	next_state := idle;

				elsif 	payload_transfer_req = '0' 

					--and descriptor_transfer_req = '1' 

					and irdy = '0' 

					and trdy = '0' 
			
					--and dma_cycles_counter = 0 

				then	dma_cycles_counter := payload_size_in_data_blocks;

					burst_cycles_counter := dma_burst_size_in_cycles;

					assert false 

					report "dma_controller_fsm: transferring_payload" 
	
					severity note;

					next_state := transferring_payload;

				elsif 	payload_transfer_req = '0' 

					--and dma_cycles_counter > 0

					and (irdy = '1' 

					or trdy = '1')  

				then 	assert false 

					report "dma_controller_fsm: transferring_payload_stalled" 
	
					severity note;

					next_state := transferring_payload_stalled;

				-- Descriptor transfer

				elsif 	descriptor_transfer_req = '0' 

					and payload_transfer_req = '1' 

					and irdy = '0' 

					and trdy = '0' 

					and dma_cycles_counter = 0 

				then	dma_cycles_counter := descriptor_size_in_data_blocks;

					burst_cycles_counter := dma_burst_size_in_cycles;

					assert false 

					report "dma_controller_fsm: transferring_descriptor" 
	
					severity note;

					next_state := transferring_descriptor;

				elsif 	descriptor_transfer_req = '0' 

					and payload_transfer_req = '1' 

					and dma_cycles_counter > 0

					and (irdy = '1' 

					or trdy = '1')  

				then 	assert false 

					report "dma_controller_fsm: transferring_descriptor_stalled" 
	
					severity note;

					next_state := transferring_descriptor_stalled;

				-- Aborted payload transfer

				elsif 	resume_aborted_payload_transfer = '0' 

					and payload_transfer_req = '1'

					and descriptor_transfer_req = '1'

					and resume_aborted_descriptor_transfer = '1'

					and gnt = '0'

					and irdy = '0' 

					and trdy = '0' 

					and dma_cycles_counter > 0
			
				then	assert false 

					report "Aborted payload transfer, resume_aborted_payload_transfer = 0" 
	
					severity note;

					burst_cycles_counter := dma_burst_size_in_cycles;

					next_state := transferring_payload;

				elsif 	resume_aborted_payload_transfer = '0' 

					and payload_transfer_req = '1'

					and descriptor_transfer_req = '1'

					and resume_aborted_descriptor_transfer = '1'

					and irdy = '0'

					and dma_cycles_counter > 0

					and (irdy = '1' 

					or trdy = '1') 
			
				then	assert false 

					report "dma_controller_fsm: transferring_payload_stalled" 
	
					severity note;

					next_state := transferring_payload_stalled;

				elsif 	resume_aborted_payload_transfer = '0' 

					and dma_cycles_counter = 0

				then	assert false 

					report "Illegal resume_aborted_payload_transfer at this moment because dma_cycles_counter = 0. Ignoring signal " 
	
					severity warning;
			
					next_state := idle;

				-- Aborted descriptor transfer

				elsif 	resume_aborted_descriptor_transfer = '0' 

					and dma_cycles_counter > 0

					and irdy = '0' 

					and trdy = '0' 
		
				then	assert false 

					report "dma_controller_fsm: transferring_descriptor" 
	
					severity note;

					next_state := transferring_descriptor;

				elsif 	resume_aborted_payload_transfer = '0' 

					and dma_cycles_counter > 0

					and (irdy = '1' 

					and trdy = '1') 
	
				then	assert false 

					report "dma_controller_fsm: transferring_payload_stalled" 
	
					severity note;

					next_state := transferring_payload_stalled;

				elsif 	resume_aborted_descriptor_transfer = '0' 

					and dma_cycles_counter > 0

					and (irdy = '0' 

					and trdy = '0') 
	
				then	assert false 

					report "dma_controller_fsm: transferring_descriptor_stalled" 
	
					severity note;

					next_state := transferring_descriptor_stalled;

				elsif 	resume_aborted_descriptor_transfer = '0' 

					and dma_cycles_counter = 0

				then	assert false 

					report "Illegal resume_aborted_descriptor_transfer signal at this moment. Ignoring signal" 
	
					severity warning;
			
					next_state := idle;

				end if;

			when transferring_payload =>

				if	burst_cycles_counter = 0

				then	payload_transfer_aborted_value := '1';

					wait for pciclk_period * 8;

					assert false 

					report "dma_controller_fsm: idle" 
	
					severity note;

					next_state := idle;  
									
				elsif 	(payload_transfer_req = '0' 

					or resume_aborted_payload_transfer = '0')

					and gnt = '0' 

					and irdy = '0' 

					and trdy = '0' 

					and dma_cycles_counter > 0 

				then	--assert false 

					--report "decrementing payload cycles counter" 
	
					--severity warning;

					dma_cycles_counter := dma_cycles_counter - 1;

					burst_cycles_counter := burst_cycles_counter - 1;

					assert false 

					report "dma_controller_fsm: decrementing dma_cycles_counter" 
	
					severity note;

					next_state := transferring_payload;  

				elsif 	(payload_transfer_req = '0' 

					or resume_aborted_payload_transfer = '0')

					--and gnt = '0' 

					--and irdy = '0' 

					--and trdy = '0' 

					and dma_cycles_counter = 0 

				then 	payload_transfer_end_value := '1';

					wait for pciclk_period * 8;

					assert false 

					report "dma_controller_fsm: idle" 
	
					severity note;

					next_state := idle;  

				elsif 	payload_transfer_req = '0' 

					and gnt = '0' 

					and dma_cycles_counter > 0 

					and (trdy = '1' 

					or irdy = '1') 

				then 	assert false 

					report "dma_controller_fsm: transferring_payload_stalled" 
	
					severity note;

					next_state := transferring_payload_stalled;  

				elsif 	(payload_transfer_req = '0' 

					or resume_aborted_payload_transfer = '0') 

					and gnt = '1'

					and dma_cycles_counter > 0 

				then  	payload_transfer_aborted_value := '1';

					wait for pciclk_period * 8;

					next_state := idle;  

				end if;

			when transferring_payload_stalled =>

				if	burst_cycles_counter = 0

				then	payload_transfer_aborted_value := '1';

					wait for pciclk_period * 8;

					next_state := idle;  

				elsif 	payload_transfer_req = '0'  	

					and gnt = '0' 

					and dma_cycles_counter > 0 

					and (irdy = '1' 

					or trdy = '1')

				then	burst_cycles_counter := burst_cycles_counter - 1;

					assert false 

					report "dma_controller_fsm: transferring_payload_stalled" 
		
					severity note;

					next_state := transferring_payload_stalled;  

				elsif 	payload_transfer_req = '0'  	

					and gnt = '0' 

					and irdy = '0' 

					and trdy = '0' 

					and dma_cycles_counter > 0 

				then	burst_cycles_counter := burst_cycles_counter - 1;

					assert false 

					report "dma_controller_fsm: decrementing burst_cycles_counter" 
	
					severity note;

					next_state := transferring_payload;  

				elsif 	gnt = '1'

					--and dma_cycles_counter > 0 

				then  	payload_transfer_aborted_value := '1';

					wait for pciclk_period * 8;

					--descriptor_transfer_aborted <= '0';

					next_state := idle;  

				end if;

			when transferring_descriptor =>

				if 	(descriptor_transfer_req = '0' 

					or resume_aborted_descriptor_transfer = '0')

					and gnt = '0' 

					and irdy = '0' 

					and trdy = '0' 

					and dma_cycles_counter > 0 

				then	dma_cycles_counter := dma_cycles_counter - 1;

					burst_cycles_counter := burst_cycles_counter - 1;

					assert false 

					report "dma_controller_fsm: decrementing dma_cycles_counter" 
	
					severity note;

					next_state := transferring_descriptor;  

				elsif 	(descriptor_transfer_req = '0' 

					or resume_aborted_payload_transfer = '0')

					--and gnt = '0' 

					--and irdy = '0' 

					--and trdy = '0' 

					and dma_cycles_counter = 0 

				then 	descriptor_transfer_end_value := '1';

					wait for pciclk_period * 8;

					assert false 

					report "dma_controller_fsm: idle" 
	
					severity note;

					next_state := idle;  

				elsif 	descriptor_transfer_req = '0' 

					and gnt = '0' 

					and dma_cycles_counter > 0 

					and (trdy = '1' 

					or irdy = '1') 

				then 	assert false 

					report "dma_controller_fsm: transferring_descriptor_stalled" 
	
					severity note;

					next_state := transferring_descriptor_stalled;  

				elsif 	(descriptor_transfer_req = '0' 

					or resume_aborted_descriptor_transfer = '0') 

					and gnt = '1'

					and dma_cycles_counter > 0 

				then  	descriptor_transfer_aborted_value := '1';

					wait for pciclk_period * 8;

					next_state := idle;  

				end if;

			when transferring_descriptor_stalled =>

				if 	descriptor_transfer_req = '0'  	

					and gnt = '0' 

					and dma_cycles_counter > 0 

					and (irdy = '1' 

					or trdy = '1')

				then	assert false 

					report "dma_controller_fsm: transferring_descriptor_stalled" 
	
					severity note;

					next_state := transferring_descriptor_stalled;  

				elsif 	descriptor_transfer_req = '0'  	

					and gnt = '0' 

					and irdy = '0' 

					and trdy = '0' 

					and dma_cycles_counter > 0 

				then	next_state := transferring_descriptor;

				elsif 	gnt = '1' 

				--	and dma_cycles_counter > 0 

				then  	descriptor_transfer_aborted_value := '1';

					wait for pciclk_period * 8;

					next_state := idle;  

				end if;

		end case; 

		state := next_state;

	end process dma_controller_fsm;


	output_signals_driver: process 

	begin

		wait until pciclk'event and pciclk = '1'; 

		payload_transfer_end <= payload_transfer_end_value;  

		descriptor_transfer_end <= descriptor_transfer_end_value;

		payload_transfer_aborted <= payload_transfer_aborted_value;

		descriptor_transfer_aborted <= descriptor_transfer_aborted_value;

	end process output_signals_driver;


	dma_cycles_counter_out_driver: process 

	begin

		wait until pciclk'event and pciclk = '0'; 

		dma_cycles_counter_out <= dma_cycles_counter;

		burst_cycles_counter_out <= burst_cycles_counter;

	end process dma_cycles_counter_out_driver;

end V1;
