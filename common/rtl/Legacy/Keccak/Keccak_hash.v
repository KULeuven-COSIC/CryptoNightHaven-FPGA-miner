`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/23/2020 02:01:24 PM
// Design Name: 
// Module Name:
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: This is based on Sep_hash, a module I implemented for the eagle project
//      the input should be provided LSByte to MSByte, but o_v_state is provided MSByte to LSByte
//      o_v_data is the actual output data and is not important in this application.
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Keccak_hash #(parameter L = 160, parameter d = 128, parameter b = 400, parameter r = 128)(
    input i_clk,
    input i_rst,
    input i_start,
    input wire[L-1:0] i_v_data, // input data
    output wire[d-1:0] o_v_data,   // output date
    output wire[b-1:0] o_v_state,
    output o_done
    );
    
    wire f_start, f_done, enable_P, rotate_P, enable_f_in, enable_so, rst_datapath;
    wire [1:0] absorb_runs;
    
    Keccak_hash_controller #(.L(L), .d(d), .b(b), .r(r)) Controller(i_clk, i_rst, i_start, f_done, absorb_runs, f_start, enable_P, enable_f_in, rotate_P, enable_so, rst_datapath, o_done);
    Keccak_hash_datapath #(.L(L), .d(d), .b(b), .r(r)) Datapath(i_clk, i_rst||rst_datapath, f_start, enable_so, enable_P, enable_f_in, rotate_P, i_v_data, f_done, o_v_data, o_v_state, absorb_runs);
    
endmodule
