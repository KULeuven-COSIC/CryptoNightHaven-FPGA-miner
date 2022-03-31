library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.aes_pkg.all;

entity aes_sbox_table3 is
	port(
		i_data : in  std_logic_vector(5 downto 0);
		o_data : out byte
	);
end entity aes_sbox_table3;

architecture rtl of aes_sbox_table3 is
begin

	P_DATA : process(i_data) is
		variable data : byte;
	begin
		data := "00" & i_data;
		case data is
			when x"00"  => o_data <= x"ba";
			when x"01"  => o_data <= x"78";
			when x"02"  => o_data <= x"25";
			when x"03"  => o_data <= x"2e";
			when x"04"  => o_data <= x"1c";
			when x"05"  => o_data <= x"a6";
			when x"06"  => o_data <= x"b4";
			when x"07"  => o_data <= x"c6";
			when x"08"  => o_data <= x"e8";
			when x"09"  => o_data <= x"dd";
			when x"0a"  => o_data <= x"74";
			when x"0b"  => o_data <= x"1f";
			when x"0c"  => o_data <= x"4b";
			when x"0d"  => o_data <= x"bd";
			when x"0e"  => o_data <= x"8b";
			when x"0f"  => o_data <= x"8a";
			when x"10"  => o_data <= x"70";
			when x"11"  => o_data <= x"3e";
			when x"12"  => o_data <= x"b5";
			when x"13"  => o_data <= x"66";
			when x"14"  => o_data <= x"48";
			when x"15"  => o_data <= x"03";
			when x"16"  => o_data <= x"f6";
			when x"17"  => o_data <= x"0e";
			when x"18"  => o_data <= x"61";
			when x"19"  => o_data <= x"35";
			when x"1a"  => o_data <= x"57";
			when x"1b"  => o_data <= x"b9";
			when x"1c"  => o_data <= x"86";
			when x"1d"  => o_data <= x"c1";
			when x"1e"  => o_data <= x"1d";
			when x"1f"  => o_data <= x"9e";
			when x"20"  => o_data <= x"e1";
			when x"21"  => o_data <= x"f8";
			when x"22"  => o_data <= x"98";
			when x"23"  => o_data <= x"11";
			when x"24"  => o_data <= x"69";
			when x"25"  => o_data <= x"d9";
			when x"26"  => o_data <= x"8e";
			when x"27"  => o_data <= x"94";
			when x"28"  => o_data <= x"9b";
			when x"29"  => o_data <= x"1e";
			when x"2a"  => o_data <= x"87";
			when x"2b"  => o_data <= x"e9";
			when x"2c"  => o_data <= x"ce";
			when x"2d"  => o_data <= x"55";
			when x"2e"  => o_data <= x"28";
			when x"2f"  => o_data <= x"df";
			when x"30"  => o_data <= x"8c";
			when x"31"  => o_data <= x"a1";
			when x"32"  => o_data <= x"89";
			when x"33"  => o_data <= x"0d";
			when x"34"  => o_data <= x"bf";
			when x"35"  => o_data <= x"e6";
			when x"36"  => o_data <= x"42";
			when x"37"  => o_data <= x"68";
			when x"38"  => o_data <= x"41";
			when x"39"  => o_data <= x"99";
			when x"3a"  => o_data <= x"2d";
			when x"3b"  => o_data <= x"0f";
			when x"3c"  => o_data <= x"b0";
			when x"3d"  => o_data <= x"54";
			when x"3e"  => o_data <= x"bb";
			when x"3f"  => o_data <= x"16";
			when others => o_data <= (others => '0');
		end case;
	end process P_DATA;

end architecture rtl;
