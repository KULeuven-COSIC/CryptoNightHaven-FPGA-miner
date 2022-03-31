`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.08.2020 12:54:25
// Design Name: 
// Module Name: prep_Keccak
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


module prep_Keccak(
    input [1085:0] i_v_data, // input data
    input [10:0] i_v_size,   // size of input between 0 and 1085
    output [1599:0] o_v_data  // output data
    );
    // looks at input size and pads properly for any input less than 1087 bits long
    genvar i;
    generate
    for (i = 0; i < 1600; i = i + 1) begin
        assign o_v_data = i_v_size < i ? i_v_data[i] : (i == i_v_size || i == 1087) ? 1'b1 : 0; 
        end
    endgenerate
endmodule

