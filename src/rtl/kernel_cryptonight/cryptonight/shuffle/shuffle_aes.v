`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/11/2021 01:57:07 PM
// Design Name: 
// Module Name: shuffle_aes
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Wrapper module for the AES block inside shuffle
// To utilise the software-based implementation byte reversals are
// necessary.
// To utilise the hardware-based version (by Michiel) the columns need to be reorderd.
// This module improves readability of the shuffle code
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module shuffle_aes (
    input clk,
    input[127:0] in,
    input[127:0] key,
    output[127:0] out
);

    wire[127:0] rev_in, revv_in, rev_key, revv_key, rev_out, revv_out;
    rev_col h_rev_in(.in(in), .out(rev_in));
    rev_bytes #(.SIZE(128)) h_revv_in(.in(rev_in), .out(revv_in));
    rev_col h_rev_key(.in(key), .out(rev_key));
    rev_bytes #(.SIZE(128)) h_revv_key(.in(rev_key), .out(revv_key));
    rev_col h_rev_out(.in(rev_out), .out(out));
    rev_bytes #(.SIZE(128)) h_revv_out(.in(revv_out), .out(rev_out));
    aes_data AES(.i_clk(clk), .i_plain(revv_in), .o_cipher(revv_out), .i_key_ram(revv_key));
endmodule
