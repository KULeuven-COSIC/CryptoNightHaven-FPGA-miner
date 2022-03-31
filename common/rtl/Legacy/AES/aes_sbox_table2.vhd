library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.aes_pkg.all;

entity aes_sbox_table2 is
	port(
		i_data : in  std_logic_vector(5 downto 0);
		o_data : out byte
	);
end entity aes_sbox_table2;

architecture rtl of aes_sbox_table2 is
begin

	P_DATA : process(i_data) is
		variable data : byte;
	begin
		data := "00" & i_data;
		case data is
			when x"00"  => o_data <= x"cd";
			when x"01"  => o_data <= x"0c";
			when x"02"  => o_data <= x"13";
			when x"03"  => o_data <= x"ec";
			when x"04"  => o_data <= x"5f";
			when x"05"  => o_data <= x"97";
			when x"06"  => o_data <= x"44";
			when x"07"  => o_data <= x"17";
			when x"08"  => o_data <= x"c4";
			when x"09"  => o_data <= x"a7";
			when x"0a"  => o_data <= x"7e";
			when x"0b"  => o_data <= x"3d";
			when x"0c"  => o_data <= x"64";
			when x"0d"  => o_data <= x"5d";
			when x"0e"  => o_data <= x"19";
			when x"0f"  => o_data <= x"73";
			when x"10"  => o_data <= x"60";
			when x"11"  => o_data <= x"81";
			when x"12"  => o_data <= x"4f";
			when x"13"  => o_data <= x"dc";
			when x"14"  => o_data <= x"22";
			when x"15"  => o_data <= x"2a";
			when x"16"  => o_data <= x"90";
			when x"17"  => o_data <= x"88";
			when x"18"  => o_data <= x"46";
			when x"19"  => o_data <= x"ee";
			when x"1a"  => o_data <= x"b8";
			when x"1b"  => o_data <= x"14";
			when x"1c"  => o_data <= x"de";
			when x"1d"  => o_data <= x"5e";
			when x"1e"  => o_data <= x"0b";
			when x"1f"  => o_data <= x"db";
			when x"20"  => o_data <= x"e0";
			when x"21"  => o_data <= x"32";
			when x"22"  => o_data <= x"3a";
			when x"23"  => o_data <= x"0a";
			when x"24"  => o_data <= x"49";
			when x"25"  => o_data <= x"06";
			when x"26"  => o_data <= x"24";
			when x"27"  => o_data <= x"5c";
			when x"28"  => o_data <= x"c2";
			when x"29"  => o_data <= x"d3";
			when x"2a"  => o_data <= x"ac";
			when x"2b"  => o_data <= x"62";
			when x"2c"  => o_data <= x"91";
			when x"2d"  => o_data <= x"95";
			when x"2e"  => o_data <= x"e4";
			when x"2f"  => o_data <= x"79";
			when x"30"  => o_data <= x"e7";
			when x"31"  => o_data <= x"c8";
			when x"32"  => o_data <= x"37";
			when x"33"  => o_data <= x"6d";
			when x"34"  => o_data <= x"8d";
			when x"35"  => o_data <= x"d5";
			when x"36"  => o_data <= x"4e";
			when x"37"  => o_data <= x"a9";
			when x"38"  => o_data <= x"6c";
			when x"39"  => o_data <= x"56";
			when x"3a"  => o_data <= x"f4";
			when x"3b"  => o_data <= x"ea";
			when x"3c"  => o_data <= x"65";
			when x"3d"  => o_data <= x"7a";
			when x"3e"  => o_data <= x"ae";
			when x"3f"  => o_data <= x"08";
			when others => o_data <= (others => '0');
		end case;
	end process P_DATA;

end architecture rtl;
