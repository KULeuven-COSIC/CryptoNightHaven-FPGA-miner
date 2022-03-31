`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: EAGLE6
// Engineer: Lucas Bex
// 
// Create Date: 02/11/2020 02:37:08 PM
// Design Name: 
// Module Name: Pi
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Pi step of the Keccak -f400 permutation
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

module Pi(input wire[0:1599] i_v_string, output wire[0:1599] o_v_string);
    genvar x, y, z;
        generate
        for (x = 0; x < 5; x = x + 1)
            begin :xloop
            for (y = 0; y < 5; y = y + 1)
                begin :yloop
                for (z = 0; z < 64; z = z + 1)
                    begin :zloop
                    assign o_v_string[64*(5*y+x) + z] = i_v_string[64*(5*x+(x+3*y)%5) + z];
                    end
                end
            end
        endgenerate

endmodule