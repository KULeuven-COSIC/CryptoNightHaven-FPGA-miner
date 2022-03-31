library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.aes_pkg.all;

entity aes_sbox_table0 is
	port(
		i_data : in  std_logic_vector(5 downto 0);
		o_data : out byte
	);
end entity aes_sbox_table0;

architecture rtl of aes_sbox_table0 is
begin

	P_DATA : process(i_data) is
		variable data : byte;
	begin
		data := "00" & i_data;
		case data is
			when x"00"  => o_data <= x"63";
			when x"01"  => o_data <= x"7c";
			when x"02"  => o_data <= x"77";
			when x"03"  => o_data <= x"7b";
			when x"04"  => o_data <= x"f2";
			when x"05"  => o_data <= x"6b";
			when x"06"  => o_data <= x"6f";
			when x"07"  => o_data <= x"c5";
			when x"08"  => o_data <= x"30";
			when x"09"  => o_data <= x"01";
			when x"0a"  => o_data <= x"67";
			when x"0b"  => o_data <= x"2b";
			when x"0c"  => o_data <= x"fe";
			when x"0d"  => o_data <= x"d7";
			when x"0e"  => o_data <= x"ab";
			when x"0f"  => o_data <= x"76";
			when x"10"  => o_data <= x"ca";
			when x"11"  => o_data <= x"82";
			when x"12"  => o_data <= x"c9";
			when x"13"  => o_data <= x"7d";
			when x"14"  => o_data <= x"fa";
			when x"15"  => o_data <= x"59";
			when x"16"  => o_data <= x"47";
			when x"17"  => o_data <= x"f0";
			when x"18"  => o_data <= x"ad";
			when x"19"  => o_data <= x"d4";
			when x"1a"  => o_data <= x"a2";
			when x"1b"  => o_data <= x"af";
			when x"1c"  => o_data <= x"9c";
			when x"1d"  => o_data <= x"a4";
			when x"1e"  => o_data <= x"72";
			when x"1f"  => o_data <= x"c0";
			when x"20"  => o_data <= x"b7";
			when x"21"  => o_data <= x"fd";
			when x"22"  => o_data <= x"93";
			when x"23"  => o_data <= x"26";
			when x"24"  => o_data <= x"36";
			when x"25"  => o_data <= x"3f";
			when x"26"  => o_data <= x"f7";
			when x"27"  => o_data <= x"cc";
			when x"28"  => o_data <= x"34";
			when x"29"  => o_data <= x"a5";
			when x"2a"  => o_data <= x"e5";
			when x"2b"  => o_data <= x"f1";
			when x"2c"  => o_data <= x"71";
			when x"2d"  => o_data <= x"d8";
			when x"2e"  => o_data <= x"31";
			when x"2f"  => o_data <= x"15";
			when x"30"  => o_data <= x"04";
			when x"31"  => o_data <= x"c7";
			when x"32"  => o_data <= x"23";
			when x"33"  => o_data <= x"c3";
			when x"34"  => o_data <= x"18";
			when x"35"  => o_data <= x"96";
			when x"36"  => o_data <= x"05";
			when x"37"  => o_data <= x"9a";
			when x"38"  => o_data <= x"07";
			when x"39"  => o_data <= x"12";
			when x"3a"  => o_data <= x"80";
			when x"3b"  => o_data <= x"e2";
			when x"3c"  => o_data <= x"eb";
			when x"3d"  => o_data <= x"27";
			when x"3e"  => o_data <= x"b2";
			when x"3f"  => o_data <= x"75";
			when others => o_data <= (others => '0');
		end case;
	end process P_DATA;

end architecture rtl;
