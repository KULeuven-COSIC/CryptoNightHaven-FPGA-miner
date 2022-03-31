--*************************************************************************
--                                                                        *           
-- The AES Sbox.             										      *
--                                                                        *
-- The tables and MUX primitives force the Sbox into a single slice.      *
--                                                                        *
--*************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

Library UNISIM;
use UNISIM.vcomponents.all;

use work.aes_pkg.all;

entity aes_sbox is
	port(
		i_clk  : in  std_logic;
		i_data : in  byte;
		o_data : out byte
	);
end entity aes_sbox;

architecture rtl of aes_sbox is

	signal table0_out : byte;
	signal table1_out : byte;
	signal table2_out : byte;
	signal table3_out : byte;

	signal muxf7_0_out : byte;
	signal muxf7_1_out : byte;

	signal data : byte;

begin

	E_Sbox_table0 : entity work.aes_sbox_table0
		port map(
			i_data => i_data(5 downto 0),
			o_data => table0_out
		);

	E_Sbox_table1 : entity work.aes_sbox_table1
		port map(
			i_data => i_data(5 downto 0),
			o_data => table1_out
		);

	E_Sbox_table2 : entity work.aes_sbox_table2
		port map(
			i_data => i_data(5 downto 0),
			o_data => table2_out
		);

	E_Sbox_table3 : entity work.aes_sbox_table3
		port map(
			i_data => i_data(5 downto 0),
			o_data => table3_out
		);

	G_MUXF : for i in 0 to 7 generate

		E_MUXF7_0 : MUXF7
			port map(
				O  => muxf7_0_out(i),   -- Output of MUX to general routing
				I0 => table0_out(i),    -- Input (tie to LUT6 O6 pin)
				I1 => table1_out(i),    -- Input (tie to LUT6 O6 pin)
				S  => i_data(6)         -- Input select to MUX
			);

		E_MUXF7_1 : MUXF7
			port map(
				O  => muxf7_1_out(i),   -- Output of MUX to general routing
				I0 => table2_out(i),    -- Input (tie to LUT6 O6 pin)
				I1 => table3_out(i),    -- Input (tie to LUT6 O6 pin)
				S  => i_data(6)         -- Input select to MUX
			);

		E_MUXF8 : MUXF8
			port map(
				O  => data(i),          -- Output of MUX to general routing
				I0 => muxf7_0_out(i),   -- Input (tie to LUT6 O6 pin)
				I1 => muxf7_1_out(i),   -- Input (tie to LUT6 O6 pin)
				S  => i_data(7)         -- Input select to MUX
			);

	end generate G_MUXF;

	o_data <= data; --when rising_edge(i_clk);

end architecture rtl;
