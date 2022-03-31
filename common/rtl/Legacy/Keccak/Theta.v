`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: EAGLE6
// Engineer: Lucas Bex
// 
// Create Date: 02/11/2020 02:11:42 PM
// Design Name: 
// Module Name: Theta
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Theta step of the Keccak -f400 permutation
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

module Theta(input wire [0:1599] i_v_string, output wire [0:1599] o_v_string);

    wire[319:0] C;
    wire[319:0] D;
    // C[x,z] = C[x + 5*z]
    

    genvar x, z, y;
    generate
        for (x = 0; x < 5; x = x + 1)
            begin :xloop
            for (z = 0; z < 64; z = z + 1)
                begin :zloop
				// Due to reversal of the bit order some deviations from SHA3doc may be found
                assign C[x+5*z] = i_v_string[64*(5*0+x)+z] ^ i_v_string[64*(5*1+x)+z] ^ i_v_string[64*(5*2+x)+z] ^ i_v_string[64*(5*3+x)+z] ^ i_v_string[64*(5*4+x)+z];
                assign D[x+5*z] = C[((x-1)%5+5)%5 + 5*z] ^ C[(x+1)%5 + 5*((z+1)%64)];
                for (y = 0; y < 5; y = y + 1)
                    begin :yloop
                        assign o_v_string[64*(5*y+x)+z] = i_v_string[64*(5*y+x)+z] ^ D[x + 5 * z];
                    end
                end
            end
    endgenerate
    
endmodule