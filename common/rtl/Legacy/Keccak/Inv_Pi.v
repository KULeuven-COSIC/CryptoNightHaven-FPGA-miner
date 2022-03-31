`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/24/2020 05:57:55 PM
// Design Name: 
// Module Name: Inv_Pi
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


module Inv_Pi(input wire[0:1599] i_v_string, output wire[0:1599] o_v_string);

    genvar x, y, z;
    generate
    for (x = 0; x < 5; x = x + 1)
        begin :xloop
        for (y = 0; y < 5; y = y + 1)
            begin :yloop
            for (z = 0; z < 64; z = z + 1)
                begin :zloop
                assign o_v_string[64*(5*y+x) + z] = i_v_string[64*(5*((2*x+3*y)%5)+y%5) + z];
                end
            end
        end
    endgenerate
endmodule
