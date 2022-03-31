`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: EAGLE6
// Engineer: Lucas Bex
// 
// Create Date: 02/11/2020 02:25:13 PM
// Design Name: 
// Module Name: Rho
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Rho step of the Keccak -f400 permutation
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
module Rho(input wire[0:1599] i_v_string, output wire[0:1599] o_v_string);
    
    wire [8:0] offsets[0:24];/* = {0, 1, 190, 28, 91, // y = 0
                         36, 300, 6, 55, 276, // y = 1
                         3, 10, 171, 153, 231, // y = 2
                         105, 45, 15, 21, 136, // y = 3
                         210, 66, 253, 120, 78}; */// y = 4
    // index via x + 5*y
    
    assign offsets[0] = 9'd0;
    assign offsets[1] = 9'd1;
    assign offsets[2] = 9'd190;
    assign offsets[3] = 9'd28;
    assign offsets[4] = 9'd91;
    assign offsets[5] = 9'd36;
    assign offsets[6] = 9'd300;
    assign offsets[7] = 9'd6;
    assign offsets[8] = 9'd55;
    assign offsets[9] = 9'd276;
    assign offsets[10] = 9'd3;
    assign offsets[11] = 9'd10;
    assign offsets[12] = 9'd171;
    assign offsets[13] = 9'd153;
    assign offsets[14] = 9'd231;
    assign offsets[15] = 9'd105;
    assign offsets[16] = 9'd45;
    assign offsets[17] = 9'd15;
    assign offsets[18] = 9'd21;
    assign offsets[19] = 9'd136;
    assign offsets[20] = 9'd210;
    assign offsets[21] = 9'd66;
    assign offsets[22] = 9'd253;
    assign offsets[23] = 9'd120;
    assign offsets[24] = 9'd78;
    
    genvar x, y, z;
    generate
    for (x = 0; x < 5; x = x + 1)
                begin :xloop
                for (y = 0; y < 5; y = y + 1)
                    begin :yloop
                    for (z = 0; z < 64; z = z + 1)
                        begin :zloop
                        assign o_v_string[64*(5*y+x)+z] = i_v_string[64*(5*y+x)+(z + offsets[x+5*y])%64];
                        end
                    end
                end
    endgenerate

endmodule