`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.02.2021 09:49:02
// Design Name: 
// Module Name: aes_genkey_compact
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: More compact version of the original genkey
//    This module only uses 2 128 bit registers instead of 12
//    The key registers are moved outside such that creating a shift register
//    becomes possible, this should ultimately result in a more compact explode
//    because less buffering is needed
//    It is slower as it provides only 1 key per clock period instead of 2
//    this however does not really matter since AES starts as soon as the first
//    key is available. All keys will thus be just in time for the next round
//    Furthermore this means that clock speed may be increased if so desired
//    
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module aes_genkey_compact(input clk, input rstn, input start,
    input [127:0] in0, input[127:0] in1, output key_available,
    output [127:0] key
    );
    reg [3:0] key_counter, rcon;
    reg working;  // Idle 0 or working 1
    reg[127:0] key_in0, key_in1;
    wire[127:0] key_out0, key_out1, rev_key_in0, rev_key_in1;
    assign key = key_counter[0] ? key_in1 : key_in0;
    assign key_available = working;
    always @(posedge clk)
        if (~rstn)
            working <= 0;
        else if (key_counter == 9)
            working <= 0;
        else if (start)
            working <= 1;
            
    always @(posedge clk)
        if (~rstn) begin
            key_counter <= 0;
            end
        else if (working ^ start) begin
            case(key_counter)
            0: begin 
                key_in0 <= rev_key_in0;
                key_in1 <= rev_key_in1; 
                rcon <= 1;
            end
            1, 3, 5, 7: begin 
                key_in0 <= key_out0;
                key_in1 <= key_out1;
                rcon <= rcon << 1;
                end
            endcase
            if (working)
                key_counter <= key_counter + 1;
            end
    
    // This is entirely combinatorial, it doesn't really need a clock
    // The original author included it and I do not feel like breaking stuff    
    aes_genkey_sub sub0(.clk(clk), .rcon(rcon), .xin0(key_in0), 
                .xin2(key_in1), .xout0(key_out0), .xout2(key_out1));
    rev_bytes #(.SIZE(128)) rev_in0(.in(in0), .out(rev_key_in0));
    rev_bytes #(.SIZE(128)) rev_in1(.in(in1), .out(rev_key_in1));
    
    
    
endmodule
