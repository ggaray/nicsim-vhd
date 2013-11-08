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


entity clkgen is

	port (

		pciclk					: out	bit;

		nicclk					: out	bit;

		ethclk					: out	bit

	);

end clkgen;


architecture V1 of clkgen is



	---------------       Line speed configuration   	---------------

	--constant		ethclk_period		: time		:= 0.1 us; 	--Ethernet

	--constant		ethclk_period		: time		:= 0.01 us; 	-- Fast Ethernet

	constant		ethclk_period		: time		:= 0.001 us;	-- Gigabit Ethernet

	--constant		ethclk_period		: time		:= 0.0001 us;	-- 10 Gigabit Ethernet

	--constant		ethclk_period		: time		:= 0.00001 us; -- 100 Gigabit Ethernet



	---------------       I/O-bus speed configuration   	---------------

	--constant		pciclk_period		: time		:= 0.03030303 us; -- PCI 33  

	--constant		pciclk_period		: time		:= 0.015151515 us; -- PCI-X 66

	constant		pciclk_period		: time		:= 0.007518797 us; -- PCI-X 133 

	--constant		pciclk_period		: time		:= 0.003759398 us;  -- PCI-X 266 

	--constant		pciclk_period		: time		:= 0.001876173 us; -- PCI-X 533



	--constant freq : integer := 33; -- PCI Clock in MHz 

	--constant clk_period : time := 1/freq;  -- Clock Period in microseconds

	--constant eth_freq : time := 10; -- Ethernet Clock in MHz




	constant 		pcitpw 			: time 		:= pciclk_period/2;  --Pulse width (0 and 1) of the PCI Clock

	constant		nicclk_period 		: time 		:= pciclk_period/100; -- NIC Clock Period (this clock 100 times faster than IO-bus clock) 

	constant 		nictpw 			: time 		:= nicclk_period/2;  -- Pulse width (0 and 1) of the Memory Clock

	constant 		ethtpw 			: time 		:= ethclk_period/2;  -- Pulse width (0 and 1) of the Ethernet Clock

begin

	pci_clock_generator: process 

	begin

		pciclk <= '0', '1' after pcitpw;

		wait for pciclk_period;

	end process pci_clock_generator;



	nic_clock_generator: process 

	begin

		nicclk <= '1', '0' after nictpw;

		wait for nicclk_period;

	end process nic_clock_generator;


	eth_clock_generator: process 

	begin

		ethclk <= '1', '0' after ethtpw;

		wait for ethclk_period;

	end process eth_clock_generator;


end V1;
