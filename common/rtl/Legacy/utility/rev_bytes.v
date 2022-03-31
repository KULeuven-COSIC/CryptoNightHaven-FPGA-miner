`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.08.2020 15:38:58
// Design Name: 
// Module Name: rev_bytes
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


module rev_bytes #(parameter SIZE = 128) (input [SIZE-1:0] in, output [SIZE-1:0] out);
    genvar k;
    generate
    for (k=0; k < SIZE; k = k + 8) begin
        assign out[k+7:k] = in[SIZE-1-k: SIZE-8-k];
    end
    endgenerate
endmodule
