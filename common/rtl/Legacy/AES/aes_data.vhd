library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.aes_pkg.all;

entity aes_data is
	port(
		i_clk       : in  std_logic;
		--i_control   : in  r_control_data;
		i_plain     : in  std_logic_vector(127 downto 0);
		i_key_ram   : in  std_logic_vector(127 downto 0);
		o_cipher    : out std_logic_vector(127 downto 0)
		--o_key_sched : out byte_array(0 to 3)
	);
end entity aes_data;

architecture rtl of aes_data is

	signal input_sel_out  : aes_array;
	signal sbox_out       : aes_array;
	signal shiftrow_out   : aes_array;
	signal mixcol_out     : aes_array;
	signal mixcolskip_out : aes_array;
--    signal improvise      : aes_array;
begin

	----------------------------------------------------------------------------
	-- Input Selection (128 LUT)
	----------------------------------------------------------------------------

--	E_Input_Sel : entity work.aes_input_sel
--		port map(
--			i_clk        => i_clk,
--			i_plain      => i_plain,
--			i_mixcol     => mixcol_out,
--			i_mixcolskip => mixcolskip_out,
--			i_key_ram    => i_key_ram,
--			i_sel        => i_control.data_mux,
--			o_data       => input_sel_out,
--			o_cipher     => o_cipher
--		);

	----------------------------------------------------------------------------
	-- Sbox (512 LUT)
	----------------------------------------------------------------------------
    
	G_Sbox : for i in 0 to 15 generate
		E_Sbox : entity work.aes_sbox
			port map(
				i_clk  => i_clk,
				i_data => i_plain(7+i*8 downto i*8),--improvise(i),--input_sel_out(i),
				o_data => sbox_out(i)
			);
	end generate G_Sbox;

--	o_key_sched(0) <= sbox_out(7);
--	o_key_sched(1) <= sbox_out(11);
--	o_key_sched(2) <= sbox_out(15);
--	o_key_sched(3) <= sbox_out(3);

	----------------------------------------------------------------------------
	-- ShiftRows (0 LUT)
	----------------------------------------------------------------------------

	G_ShiftRows_Row : for i in 0 to 3 generate
		G_ShiftRows_Col : for j in 0 to 3 generate
			shiftrow_out(4 * i + j) <= sbox_out(4 * i + ((i + j) mod 4));
		end generate G_ShiftRows_Col;
	end generate G_ShiftRows_Row;

	----------------------------------------------------------------------------
	-- MixColumns (128 LUT)
	----------------------------------------------------------------------------

	G_MixCol1 : for i in 0 to 3 generate
		G_MixCol2 : for j in 0 to 3 generate
			E_MixCol : entity work.aes_mixcol
				port map(
					i_clk    => i_clk,
					i_data_a => shiftrow_out(i + 4 * j),
					i_data_b => shiftrow_out(i + ((4 + 4 * j) mod 16)),
					i_data_c => shiftrow_out(i + ((8 + 4 * j) mod 16)),
					i_data_d => shiftrow_out(i + ((12 + 4 * j) mod 16)),
					o_data_a => mixcol_out(i + 4 * j)
				);
				o_cipher(7+8*(i+4*j) downto 8*(i+4*j)) <= mixcol_out(i+4*j) xor i_key_ram(7+8*(i+4*j) downto 8*(i+4*j));
		end generate G_MixCol2;
	end generate G_MixCol1;

	mixcolskip_out <= shiftrow_out when rising_edge(i_clk);

end architecture rtl;
