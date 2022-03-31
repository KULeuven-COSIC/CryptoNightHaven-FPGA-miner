library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.aes_pkg.all;

entity aes_sbox_table1 is
	port(
		i_data : in  std_logic_vector(5 downto 0);
		o_data : out byte
	);
end entity aes_sbox_table1;

architecture rtl of aes_sbox_table1 is
begin

	P_DATA : process(i_data) is
		variable data : byte;
	begin
		data := "00" & i_data;
		case data is
			when x"00"  => o_data <= x"09";
			when x"01"  => o_data <= x"83";
			when x"02"  => o_data <= x"2c";
			when x"03"  => o_data <= x"1a";
			when x"04"  => o_data <= x"1b";
			when x"05"  => o_data <= x"6e";
			when x"06"  => o_data <= x"5a";
			when x"07"  => o_data <= x"a0";
			when x"08"  => o_data <= x"52";
			when x"09"  => o_data <= x"3b";
			when x"0a"  => o_data <= x"d6";
			when x"0b"  => o_data <= x"b3";
			when x"0c"  => o_data <= x"29";
			when x"0d"  => o_data <= x"e3";
			when x"0e"  => o_data <= x"2f";
			when x"0f"  => o_data <= x"84";
			when x"10"  => o_data <= x"53";
			when x"11"  => o_data <= x"d1";
			when x"12"  => o_data <= x"00";
			when x"13"  => o_data <= x"ed";
			when x"14"  => o_data <= x"20";
			when x"15"  => o_data <= x"fc";
			when x"16"  => o_data <= x"b1";
			when x"17"  => o_data <= x"5b";
			when x"18"  => o_data <= x"6a";
			when x"19"  => o_data <= x"cb";
			when x"1a"  => o_data <= x"be";
			when x"1b"  => o_data <= x"39";
			when x"1c"  => o_data <= x"4a";
			when x"1d"  => o_data <= x"4c";
			when x"1e"  => o_data <= x"58";
			when x"1f"  => o_data <= x"cf";
			when x"20"  => o_data <= x"d0";
			when x"21"  => o_data <= x"ef";
			when x"22"  => o_data <= x"aa";
			when x"23"  => o_data <= x"fb";
			when x"24"  => o_data <= x"43";
			when x"25"  => o_data <= x"4d";
			when x"26"  => o_data <= x"33";
			when x"27"  => o_data <= x"85";
			when x"28"  => o_data <= x"45";
			when x"29"  => o_data <= x"f9";
			when x"2a"  => o_data <= x"02";
			when x"2b"  => o_data <= x"7f";
			when x"2c"  => o_data <= x"50";
			when x"2d"  => o_data <= x"3c";
			when x"2e"  => o_data <= x"9f";
			when x"2f"  => o_data <= x"a8";
			when x"30"  => o_data <= x"51";
			when x"31"  => o_data <= x"a3";
			when x"32"  => o_data <= x"40";
			when x"33"  => o_data <= x"8f";
			when x"34"  => o_data <= x"92";
			when x"35"  => o_data <= x"9d";
			when x"36"  => o_data <= x"38";
			when x"37"  => o_data <= x"f5";
			when x"38"  => o_data <= x"bc";
			when x"39"  => o_data <= x"b6";
			when x"3a"  => o_data <= x"da";
			when x"3b"  => o_data <= x"21";
			when x"3c"  => o_data <= x"10";
			when x"3d"  => o_data <= x"ff";
			when x"3e"  => o_data <= x"f3";
			when x"3f"  => o_data <= x"d2";
			when others => o_data <= (others => '0');
		end case;
	end process P_DATA;

end architecture rtl;
