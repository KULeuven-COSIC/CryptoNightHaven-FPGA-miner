`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/23/2020 02:01:24 PM
// Design Name: 
// Module Name: Keccak_hash_datapath
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


module Keccak_hash_datapath 
  #(parameter L = 160, 
    parameter d = 128,
    parameter b = 400,
    parameter r = 128
    )(
    input i_clk,
    input i_rst,
    input wire i_f_start,
    input wire i_enable_so,
    input wire i_enable_P,
    input wire i_enable_f_in,
    input wire i_rotate_P,
    input wire[L-1:0] i_v_data, // input data
    output wire o_f_done,
    output wire[d-1:0] o_v_data,   // output date
    output wire[b-1:0] o_v_state,
    output wire[1:0] o_v_absorb_runs
    );
    
    localparam c = b-r; // capacity
    localparam n = (L + r-1)/r; // number of times r fits in L + padding
    localparam m = (d+r-1)/r; // amount of times r fits in d (rounded up)
    
    reg [n*r-L-1:0] padding = 2**(n*r-L-1) + 1; // 100...0...001
    wire [1:0] absorb_runs;
    assign o_v_absorb_runs = absorb_runs;
    // Keccak inputs
    wire f_done;
    assign o_f_done = f_done;
    wire[b-1:0] f_out;
    wire[b-1:0] f_in;
    wire[b-1:0] shuffled_f_in;
    wire[b-1:0] shuffled_f_out;
    // capacity bits (all 0)
    reg[c-1:0] cap_bits = 0;
    
    // Again as in the KeccakF400 and KeccakP(*)400 permutations the bit order
    // specified in the test files is bits[7:0] bits[15:8]...
    // the same shuffling around is happening here but because the input and output
    // have different length two loops are needed
    wire[L-1:0] sorted_input;
    wire[d-1:0] sorted_output;
    
    genvar k, l;
    generate
    for (k = 0; k < L/8; k=k+1) begin :rearrangebits
        assign sorted_input[(k+1)*8-1:k*8] = i_v_data[L-1-(k*8):L-8-(k*8)];
        end
    endgenerate
    generate
    for (l = 0; l < d/8; l = l+1) begin :rearrangeoutputbits
    assign o_v_data[(l+1)*8-1:l*8] = sorted_output[d-1-(l*8):d-8-(l*8)];
        end    
    endgenerate
    //assign sorted_input = i_v_data;
    //assign sorted_output = o_v_data;
    
    
    wire[b-1:0] S; // State
    assign o_v_state = S;
    wire[n*r-1:0] P; // Padded input
    
    // always @(S)
    //     $display("S: %h", S);
    // always @(P)
    //     $display("P: %h", P);
    // always @(f_in)
    //     $display("f_in: %h", f_in);
        
    Keccak_p1600 func(i_clk, i_rst, i_f_start, shuffled_f_in, 5'd24, shuffled_f_out, f_done);
    shuffle_Keccak shuffle_in(.i_v_data(f_in), .o_v_data(shuffled_f_in));
    shuffle_Keccak shuffle_out(.i_v_data(shuffled_f_out), .o_v_data(f_out));
    Flex_register #(.SIZE(b)) State(i_clk, i_rst, f_out, f_done, S);
    Flex_register #(.SIZE(n*r)) Padded_input(i_clk, i_rst, i_rotate_P ? {P[(n-1)*r-1:0], P[n*r-1:(n-1)*r]} : {padding, sorted_input} ,i_enable_P, P);
    Flex_register #(.SIZE(b)) fin(i_clk, i_rst, S ^ {cap_bits, P[r-1:0]}, i_enable_f_in, f_in);
    Flex_register #(.SIZE(d)) sorted_out(i_clk, i_rst, S[r-1:0], i_enable_so, sorted_output);
    Flex_register #(.SIZE(2)) absorb_runs_reg(i_clk, i_rst, absorb_runs + 2'b01, i_enable_f_in, absorb_runs);
    
endmodule
