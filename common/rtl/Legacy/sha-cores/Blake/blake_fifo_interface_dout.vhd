-- ==============================================================
-- RTL generated by Vivado(TM) HLS - High-Level Synthesis from C, C++ and SystemC
-- Version: 2014.1
-- Copyright (C) 2014 Xilinx Inc. All rights reserved.
-- 
-- ===========================================================

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity blake_fifo_interface_dout is
port (
    ap_clk : IN STD_LOGIC;
    ap_rst : IN STD_LOGIC;
    hash_dout : IN STD_LOGIC_VECTOR (255 downto 0);
    hash_empty_n : IN STD_LOGIC;
    hash_read : OUT STD_LOGIC;
    dout_din : OUT STD_LOGIC_VECTOR (63 downto 0);
    dout_full_n : IN STD_LOGIC;
    dout_write : OUT STD_LOGIC );
end;


architecture behav of blake_fifo_interface_dout is 
    attribute CORE_GENERATION_INFO : STRING;
    attribute CORE_GENERATION_INFO of behav : architecture is
    "fifo_interface_dout,hls_ip_2014_1,{HLS_INPUT_TYPE=c,HLS_INPUT_FLOAT=0,HLS_INPUT_FIXED=1,HLS_INPUT_PART=xc7vx485tffg1761-2,HLS_INPUT_CLOCK=40.000000,HLS_INPUT_ARCH=others,HLS_SYN_CLOCK=2.522000,HLS_SYN_LAT=0,HLS_SYN_TPT=none,HLS_SYN_MEM=0,HLS_SYN_DSP=0,HLS_SYN_FF=0,HLS_SYN_LUT=0}";
    constant ap_const_logic_1 : STD_LOGIC := '1';
    constant ap_const_logic_0 : STD_LOGIC := '0';
    constant ap_ST_st1_fsm_0 : STD_LOGIC_VECTOR (0 downto 0) := "0";
    constant ap_const_lv8_6 : STD_LOGIC_VECTOR (7 downto 0) := "00000110";
    constant ap_const_lv32_0 : STD_LOGIC_VECTOR (31 downto 0) := "00000000000000000000000000000000";
    constant ap_const_lv1_0 : STD_LOGIC_VECTOR (0 downto 0) := "0";
    constant ap_const_lv8_4 : STD_LOGIC_VECTOR (7 downto 0) := "00000100";
    constant ap_const_lv8_5 : STD_LOGIC_VECTOR (7 downto 0) := "00000101";
    constant ap_const_lv32_C0 : STD_LOGIC_VECTOR (31 downto 0) := "00000000000000000000000011000000";
    constant ap_const_lv32_FF : STD_LOGIC_VECTOR (31 downto 0) := "00000000000000000000000011111111";
    constant ap_const_lv256_lc_2 : STD_LOGIC_VECTOR (255 downto 0) := "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000";
    constant ap_const_lv32_3 : STD_LOGIC_VECTOR (31 downto 0) := "00000000000000000000000000000011";
    constant ap_const_lv32_1 : STD_LOGIC_VECTOR (31 downto 0) := "00000000000000000000000000000001";

    signal state : STD_LOGIC_VECTOR (7 downto 0) := "00000110";
    signal hash_reg : STD_LOGIC_VECTOR (255 downto 0) := "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    signal count : STD_LOGIC_VECTOR (31 downto 0) := "00000000000000000000000000000000";
    signal ap_CS_fsm : STD_LOGIC_VECTOR (0 downto 0) := "0";
    signal tmp_fu_74_p2 : STD_LOGIC_VECTOR (0 downto 0);
    signal tmp_1_fu_80_p2 : STD_LOGIC_VECTOR (0 downto 0);
    signal tmp_2_fu_90_p2 : STD_LOGIC_VECTOR (0 downto 0);
    signal ap_sig_bdd_42 : BOOLEAN;
    signal tmp_6_fu_123_p2 : STD_LOGIC_VECTOR (0 downto 0);
    signal tmp_3_fu_107_p2 : STD_LOGIC_VECTOR (255 downto 0);
    signal tmp_7_fu_129_p2 : STD_LOGIC_VECTOR (31 downto 0);
    signal ap_NS_fsm : STD_LOGIC_VECTOR (0 downto 0);
    signal ap_sig_bdd_46 : BOOLEAN;
    signal ap_sig_bdd_109 : BOOLEAN;
    signal ap_sig_bdd_95 : BOOLEAN;


begin




    -- the current state (ap_CS_fsm) of the state machine. --
    ap_CS_fsm_assign_proc : process(ap_clk)
    begin
        if (ap_clk'event and ap_clk =  '1') then
            if (ap_rst = '1') then
                ap_CS_fsm <= ap_ST_st1_fsm_0;
            else
                ap_CS_fsm <= ap_NS_fsm;
            end if;
        end if;
    end process;


    -- count assign process. --
    count_assign_proc : process (ap_clk)
    begin
        if (ap_clk'event and ap_clk = '1') then
            if (ap_sig_bdd_46) then
                if (not((ap_const_lv1_0 = tmp_6_fu_123_p2))) then 
                    count <= ap_const_lv32_0;
                elsif ((ap_const_lv1_0 = tmp_6_fu_123_p2)) then 
                    count <= tmp_7_fu_129_p2;
                end if;
            end if; 
        end if;
    end process;

    -- hash_reg assign process. --
    hash_reg_assign_proc : process (ap_clk)
    begin
        if (ap_clk'event and ap_clk = '1') then
            if (ap_sig_bdd_95) then
                if (not((ap_const_lv1_0 = tmp_1_fu_80_p2))) then 
                    hash_reg <= hash_dout;
                elsif (ap_sig_bdd_109) then 
                    hash_reg <= tmp_3_fu_107_p2;
                end if;
            end if; 
        end if;
    end process;

    -- state assign process. --
    state_assign_proc : process (ap_clk)
    begin
        if (ap_clk'event and ap_clk = '1') then
            if (((ap_ST_st1_fsm_0 = ap_CS_fsm) and (tmp_fu_74_p2 = ap_const_lv1_0) and not((ap_const_lv1_0 = tmp_1_fu_80_p2)) and not(ap_sig_bdd_42))) then 
                state(0) <= '1';
                state(1) <= '0';
            elsif ((((ap_ST_st1_fsm_0 = ap_CS_fsm) and (tmp_fu_74_p2 = ap_const_lv1_0) and (ap_const_lv1_0 = tmp_1_fu_80_p2) and not((ap_const_lv1_0 = tmp_2_fu_90_p2)) and not(ap_sig_bdd_42) and not((ap_const_lv1_0 = tmp_6_fu_123_p2))) or ((ap_ST_st1_fsm_0 = ap_CS_fsm) and not(ap_sig_bdd_42) and not((tmp_fu_74_p2 = ap_const_lv1_0))))) then 
                state(0) <= '0';
                state(1) <= '0';
            end if; 
        end if;
    end process;
    state(7 downto 2) <= "000001";

    -- the next state (ap_NS_fsm) of the state machine. --
    ap_NS_fsm_assign_proc : process (ap_CS_fsm , ap_sig_bdd_42)
    begin
        case ap_CS_fsm is
            when ap_ST_st1_fsm_0 => 
                ap_NS_fsm <= ap_ST_st1_fsm_0;
            when others =>  
                ap_NS_fsm <= "X";
        end case;
    end process;

    -- ap_sig_bdd_109 assign process. --
    ap_sig_bdd_109_assign_proc : process(tmp_1_fu_80_p2, tmp_2_fu_90_p2)
    begin
                ap_sig_bdd_109 <= ((ap_const_lv1_0 = tmp_1_fu_80_p2) and not((ap_const_lv1_0 = tmp_2_fu_90_p2)));
    end process;


    -- ap_sig_bdd_42 assign process. --
    ap_sig_bdd_42_assign_proc : process(hash_empty_n, dout_full_n, tmp_fu_74_p2, tmp_1_fu_80_p2, tmp_2_fu_90_p2)
    begin
                ap_sig_bdd_42 <= (((dout_full_n = ap_const_logic_0) and (tmp_fu_74_p2 = ap_const_lv1_0) and (ap_const_lv1_0 = tmp_1_fu_80_p2) and not((ap_const_lv1_0 = tmp_2_fu_90_p2))) or ((tmp_fu_74_p2 = ap_const_lv1_0) and (hash_empty_n = ap_const_logic_0) and not((ap_const_lv1_0 = tmp_1_fu_80_p2))));
    end process;


    -- ap_sig_bdd_46 assign process. --
    ap_sig_bdd_46_assign_proc : process(ap_CS_fsm, tmp_fu_74_p2, tmp_1_fu_80_p2, tmp_2_fu_90_p2, ap_sig_bdd_42)
    begin
                ap_sig_bdd_46 <= ((ap_ST_st1_fsm_0 = ap_CS_fsm) and (tmp_fu_74_p2 = ap_const_lv1_0) and (ap_const_lv1_0 = tmp_1_fu_80_p2) and not((ap_const_lv1_0 = tmp_2_fu_90_p2)) and not(ap_sig_bdd_42));
    end process;


    -- ap_sig_bdd_95 assign process. --
    ap_sig_bdd_95_assign_proc : process(ap_CS_fsm, tmp_fu_74_p2, ap_sig_bdd_42)
    begin
                ap_sig_bdd_95 <= ((ap_ST_st1_fsm_0 = ap_CS_fsm) and (tmp_fu_74_p2 = ap_const_lv1_0) and not(ap_sig_bdd_42));
    end process;

    dout_din <= hash_reg(255 downto 192);

    -- dout_write assign process. --
    dout_write_assign_proc : process(ap_CS_fsm, tmp_fu_74_p2, tmp_1_fu_80_p2, tmp_2_fu_90_p2, ap_sig_bdd_42)
    begin
        if (((ap_ST_st1_fsm_0 = ap_CS_fsm) and (tmp_fu_74_p2 = ap_const_lv1_0) and (ap_const_lv1_0 = tmp_1_fu_80_p2) and not((ap_const_lv1_0 = tmp_2_fu_90_p2)) and not(ap_sig_bdd_42))) then 
            dout_write <= ap_const_logic_1;
        else 
            dout_write <= ap_const_logic_0;
        end if; 
    end process;


    -- hash_read assign process. --
    hash_read_assign_proc : process(ap_CS_fsm, tmp_fu_74_p2, tmp_1_fu_80_p2, ap_sig_bdd_42)
    begin
        if (((ap_ST_st1_fsm_0 = ap_CS_fsm) and (tmp_fu_74_p2 = ap_const_lv1_0) and not((ap_const_lv1_0 = tmp_1_fu_80_p2)) and not(ap_sig_bdd_42))) then 
            hash_read <= ap_const_logic_1;
        else 
            hash_read <= ap_const_logic_0;
        end if; 
    end process;

    tmp_1_fu_80_p2 <= "1" when (state = ap_const_lv8_4) else "0";
    tmp_2_fu_90_p2 <= "1" when (state = ap_const_lv8_5) else "0";
    tmp_3_fu_107_p2 <= std_logic_vector(shift_left(unsigned(hash_reg),to_integer(unsigned('0' & ap_const_lv256_lc_2(31-1 downto 0)))));
    tmp_6_fu_123_p2 <= "1" when (count = ap_const_lv32_3) else "0";
    tmp_7_fu_129_p2 <= std_logic_vector(unsigned(count) + unsigned(ap_const_lv32_1));
    tmp_fu_74_p2 <= "1" when (state = ap_const_lv8_6) else "0";
end behav;
