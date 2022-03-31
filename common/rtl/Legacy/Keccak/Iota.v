`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: EAGLE6
// Engineer: Lucas Bex
// 
// Create Date: 02/11/2020 02:58:00 PM
// Design Name: 
// Module Name: Iota
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Iota step of the Keccak -f400 permutation round
//	instead of a three dimensional array a one dimensional array is used: 
//	A[x, y, z] = S[16*(5*y+x)+z]
//		with 0 <= x < 5; 0 <= y < 5; 0 <= z < 16;
//	implementation based on SHA3doc.pdf in Module_information/CRYPTO
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module Iota(input wire[0:1599] i_v_string, input wire[4:0] i_v_current_round,
    output wire[0:1599] o_v_string);
    
    wire[0:63] RC[0:23];/* = {16'h0001, 16'h8082, 16'h808A, 16'h8000, 16'h808B, 16'h0001,
                                    16'h8081, 16'h8009, 16'h008A, 16'h0088, 16'h8009, 16'h000A,
                                    16'h808B, 16'h008B, 16'h8089, 16'h8003, 16'h8002,
                                    16'h0080, 16'h800A, 16'h000A};    */    
    assign RC[00] = 64'h0000000000000001;
    assign RC[01] = 64'h0000000000008082;
    assign RC[02] = 64'h800000000000808A;
    assign RC[03] = 64'h8000000080008000;
    assign RC[04] = 64'h000000000000808B;
    assign RC[05] = 64'h0000000080000001;
    assign RC[06] = 64'h8000000080008081;
    assign RC[07] = 64'h8000000000008009;
    assign RC[08] = 64'h000000000000008A;
    assign RC[09] = 64'h0000000000000088;
    assign RC[10] = 64'h0000000080008009;
    assign RC[11] = 64'h000000008000000A;
    assign RC[12] = 64'h000000008000808B;
    assign RC[13] = 64'h800000000000008B;
    assign RC[14] = 64'h8000000000008089;
    assign RC[15] = 64'h8000000000008003;
    assign RC[16] = 64'h8000000000008002;
    assign RC[17] = 64'h8000000000000080;
    assign RC[18] = 64'h000000000000800A;
    assign RC[19] = 64'h800000008000000A;
    assign RC[20] = 64'h8000000080008081;
    assign RC[21] = 64'h8000000000008080;
    assign RC[22] = 64'h0000000080000001;
    assign RC[23] = 64'h8000000080008008;
    
    genvar x, y, z;
    generate
            for (x = 0; x < 5; x = x + 1)
                begin :xloop
                for (y = 0; y < 5; y = y + 1)
                    begin :yloop
                    for (z = 0; z < 64; z = z + 1)
                        begin :zloop
                        if (x == 0 && y == 0)
                        assign o_v_string[64*(5*y+x)+z] = i_v_string[64*(5*y+x)+z] ^ RC[i_v_current_round][z];
                        else
                        assign o_v_string[64*(5*y+x)+z] = i_v_string[64*(5*y+x)+z];
                        end
                    end
                end
    endgenerate                      
endmodule