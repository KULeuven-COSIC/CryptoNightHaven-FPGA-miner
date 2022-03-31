`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/14/2021 09:38:37 AM
// Design Name: 
// Module Name: multadd_proper
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: The original multadd version was not entirely according to
// specification. This version is a proper implementation, but it uses more DSP
// slices and is slower.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module multadd_proper(
    input clk,
    input rst,
    input [63:0] a,
    input [63:0] b,
    input [127:0] c,
    output [127:0] p
    );
    // input format
    // a, b = uint64
    // c = {ah0, al0}
    // output format
    // p = {ah0, al0}
    // note: to preserve FF's, c needs to be provided multiplier_latency after
    // a, b

    localparam multiplier_latency = 18;
    localparam adder_latency = 6;
    localparam multadd_latency = adder_latency + multiplier_latency;
    integer i;
    reg [127:0] add_result [adder_latency-1:0];
    reg [127:0] mult_result [multiplier_latency-1:0];
    wire [63:0] helper_wire_0, helper_wire_1;
    always @(posedge clk)
        if (rst)
            for (i=0; i < adder_latency; i = i + 1)
                add_result[i] <= 0;
        else begin
            add_result[0] <= {helper_wire_1, helper_wire_0};
            for (i=1; i < adder_latency; i = i + 1)
                add_result[i] <= add_result[i-1];
        end
    always @(posedge clk)
        if (rst)
            for (i=0; i < multiplier_latency; i = i + 1)
                mult_result[i] <= 0;
        else begin
            mult_result[0] <= a * b;
            for (i=1; i < multiplier_latency; i = i + 1)
                mult_result[i] <= mult_result[i-1];
        end
    assign p = add_result[adder_latency-1];
    assign helper_wire_0 = mult_result[multiplier_latency-1][63:0] + c[63:0];
    assign helper_wire_1 = mult_result[multiplier_latency-1][127:64] + c[127:64];
    /* wire [127:0] mult_out; */
    /* mult_gen_0 multiplier( */
    /*     .CLK(clk), */
    /*     .A(a), */
    /*     .B(b), */
    /*     .P(mult_out) */
    /* ); */
    /* adder_64 lo( */
    /*     .CLK(clk), */
    /*     .A(c[127:64]), */
    /*     .B(mult_out[63:0]), */
    /*     .S(p[127:64]) */
    /* ); */
    /* adder_64 hi( */
    /*     .CLK(clk), */
    /*     .A(c[63:0]), */
    /*     .B(mult_out[127:64]), */
    /*     .S(p[63:0]) */
    /* ); */
endmodule
