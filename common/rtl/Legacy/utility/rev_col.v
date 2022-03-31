`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.09.2020 10:17:16
// Design Name: 
// Module Name: rev_col
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


module rev_col (input wire [127:0] in, output wire[127:0] out);

    assign out[0+:8] = in[120+:8];
    assign out[8+:8] = in[88+:8];
    assign out[16+:8] = in[56+:8];
    assign out[24+:8] = in[24+:8];
    assign out[32+:8] = in[112+:8];
    assign out[40+:8] = in[80+:8];
    assign out[48+:8] = in[48+:8];
    assign out[56+:8] = in[16+:8];
    assign out[64+:8] = in[104+:8];
    assign out[72+:8] = in[72+:8];
    assign out[80+:8] = in[40+:8];
    assign out[88+:8] = in[8+:8];
    assign out[96+:8] = in[96+:8];
    assign out[104+:8] = in[64+:8];
    assign out[112+:8] = in[32+:8];
    assign out[120+:8] = in[0+:8];

//    assign out[7:0] = in[127:120];
//    assign out[15:8] = in[95:88];
//    assign out[23:16] = in[63:56];
//    assign out[31:24] = in[31:24];
//    assign out[39:32] = in[119:112];
//    assign out[47:40] = in[87:80];
//    assign out[55:48] = in[55:48];
//    assign out[63:56] = in[23:16];
//    assign out[71:64] = in[111:104];
//    assign out[79:72] = in[79:72];
//    assign out[87:80] = in[47:40];
//    assign out[95:88] = in[15:8];
//    assign out[103:96] = in[103:96];
//    assign out[111:104] = in[71:64];
//    assign out[119:112] = in[39:32];
//    assign out[127:0] = in[7:0];

endmodule
