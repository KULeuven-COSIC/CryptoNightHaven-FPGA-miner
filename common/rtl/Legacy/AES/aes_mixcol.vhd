library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.aes_pkg.all;

entity aes_mixcol is
	port(
		i_clk    : in  std_logic;
		i_data_a : in  byte;
		i_data_b : in  byte;
		i_data_c : in  byte;
		i_data_d : in  byte;
		o_data_a : out byte
	);
end entity aes_mixcol;

architecture rtl of aes_mixcol is

	signal ax1, ax2      : byte;
	signal bx1, bx2, bx3 : byte;
	signal cx1           : byte;
	signal dx1           : byte;

begin

	-- implements first row

	ax1 <= i_data_a;
	ax2 <= times2(i_data_a);

	bx1 <= i_data_b;
	bx2 <= times2(i_data_b);
	bx3 <= times2(i_data_b) xor i_data_b;

	cx1 <= i_data_c;
	dx1 <= i_data_d;

	o_data_a <= ax2 xor bx3 xor cx1 xor dx1; --when rising_edge(i_clk);

end architecture rtl;
