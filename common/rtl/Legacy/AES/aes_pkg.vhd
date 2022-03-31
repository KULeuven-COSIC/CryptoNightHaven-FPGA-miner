library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package aes_pkg is

	subtype byte is std_logic_vector(7 downto 0);
	type byte_array is array (natural range <>) of byte;

	subtype aes_array is byte_array(0 to 15);
	type aes_key_ram is array (0 to 10) of std_logic_vector(127 downto 0);

	type aes_data_mux is (PLAIN, KEY, MIXCOL, MIXCOLSKIP);
	type aes_fsm is (IDLE, KEY, ENCRYPT, DUMMY);

	type r_control_in is record         -- control input
		load_key   : std_logic;
		load_plain : std_logic;
	end record r_control_in;

	type r_control_key is record        -- control to key schedule
		key_ram_addr  : unsigned(3 downto 0);
		key_ram_wr_en : std_logic;
		key_mux       : std_logic;
		rcon_en       : std_logic;
		rcon_rst      : std_logic;
	end record r_control_key;

	type r_control_data is record       -- control to datapath
		data_mux : aes_data_mux;
	end record r_control_data;

	type r_control_top is record        -- control to top
		done : std_logic;
		rdy  : std_logic;
	end record r_control_top;

	function to_array(a : std_logic_vector) return aes_array;
	function from_array(a : aes_array) return std_logic_vector;
	function xor_array(a : aes_array; b : aes_array) return aes_array;
	function times2(a : byte) return byte;

end package aes_pkg;

package body aes_pkg is

	function to_array(a : std_logic_vector) return aes_array is
		variable result : aes_array;
	begin
		for i in 0 to 3 loop
			for j in 0 to 3 loop
				result(15 - (i + 4 * j)) := a((4 * i + j + 1) * 8 - 1 downto (4 * i + j) * 8);
			end loop;
		end loop;
		return result;
	end function to_array;

	function from_array(a : aes_array) return std_logic_vector is
		variable result : std_logic_vector(127 downto 0);
	begin
		for i in 0 to 3 loop
			for j in 0 to 3 loop
				result((4 * i + j + 1) * 8 - 1 downto (4 * i + j) * 8) := a(15 - (i + 4 * j));
			end loop;
		end loop;
		return result;
	end function from_array;

	function xor_array(a : aes_array; b : aes_array) return aes_array is
		variable result : aes_array;
	begin
		for i in 0 to 15 loop
			result(i) := a(i) xor b(i);
		end loop;
		return result;
	end function xor_array;

	function times2(a : byte) return byte is
	begin
		return (a(6 downto 0) & '0') xor ("000" & a(7) & a(7) & '0' & a(7) & a(7));
	end function times2;

end package body aes_pkg;

