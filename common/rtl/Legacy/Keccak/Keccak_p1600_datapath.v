`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.08.2020 11:52:14
// Design Name: 
// Module Name: Keccak_p1600_datapath
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Keccak_p1600_datapath(input wire i_clk, input wire i_rst, input wire i_enable, input wire i_sel_input, input wire i_mode,
                                input wire[4:0] i_round_number, input wire[1599:0] i_v_state, output wire[1599:0] o_v_state
    );
    
    wire[0:1599] Theta_to_Rho;
    wire[0:1599] sorted_input;
    wire[0:1599] sorted_output;
    wire[0:1599] Rho_to_Pi;
    wire[0:1599] Pi_to_Chi;
    wire[0:1599] Chi_to_Iota;
    wire[0:1599] intermediate_input;
    wire[0:1599] twisted_in;
    wire[0:1599] twisted_out;
	
	// The round components were implemented to work for the provided
	// test vectors. This means input and output should be organised
	// in the following manner: bits[7:0] || bits[14:8] || .. || bits[399:392]
	// input and output is in the regular bits[399:0] order, thus the bits need
	// to be shuffled around
    genvar i;
    generate
    for (i = 0; i < 100; i=i+1) begin :rearrangebits
        assign sorted_input[16*i:7+16*i] = i_v_state[16*i+15:8+16*i];
        assign sorted_input[8+16*i:15+16*i] = i_v_state[7+16*i:16*i];
        assign o_v_state[7+16*i:16*i] = i_mode ? sorted_output[8+16*i:15+16*i] : twisted_out[8+16*i:15+16*i];
        assign o_v_state[16*i+15:8+16*i] = i_mode ? sorted_output[16*i:7+16*i] : twisted_out[16*i:7+16*i];
        end
    endgenerate
    
    
    
    Flex_register # (.SIZE(1600)) intermediate_result(i_clk, i_rst, i_sel_input ? sorted_output : i_mode ? sorted_input : twisted_in , i_enable, intermediate_input);
    
    Theta th(intermediate_input, Theta_to_Rho);
    Rho rh(Theta_to_Rho, Rho_to_Pi);
    Pi pi(Rho_to_Pi, Pi_to_Chi);
    Chi ch(Pi_to_Chi, Chi_to_Iota);
    Iota io(Chi_to_Iota, i_round_number, sorted_output);
    Inv_Pi in_pi(sorted_input, twisted_in);
    Pi out_pi(sorted_output, twisted_out);
    
endmodule
