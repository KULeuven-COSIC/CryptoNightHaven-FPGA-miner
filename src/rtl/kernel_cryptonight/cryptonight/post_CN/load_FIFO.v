`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.08.2020 10:14:21
// Design Name: 
// Module Name: load_FIFO
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


module load_FIFO(
    input clk,
    input rst,
    input enable,
    input [1:0] hash_type,     // Blake, Groestl, JH or Skein
    output reg select_input,   // output from this module or from final state
    output reg [63:0] dout,    // data output for this module
    output reg [10:0] counter  // counter to select proper final_state output
    );
    
    localparam DOBLAKE = 2'b0;
    localparam DOGROESTL = 2'b1;
    localparam DOJH = 2'b10;
    localparam DOSKEIN = 2'b11;
    
    wire[63:0] Blake_prepend, Groestl_prepend, JH_prepend, Skein_prepend, second_prepend;
    
    // 1 || length of padded message
    assign Blake_prepend   = 64'h8000000000000800;
    assign Groestl_prepend = 64'h8000000000000800;
    assign JH_prepend      = 64'h8000000000000a00;
    assign Skein_prepend   = 64'h8000000000000800;
    // 0 || length of unpadded message
    assign second_prepend  = 64'h0000000000000640;
    
    always @(posedge clk)
        if (rst)
            counter <= 0;
        else if (enable)
            case(hash_type)
                DOBLAKE: counter <= (counter + 1) % 34;
                DOGROESTL: counter <= (counter + 1) % 34;
                DOJH: counter <= (counter + 1) % 42;
                DOSKEIN: counter <= (counter + 1) % 34;
            endcase
    
    always @(posedge clk)
        if (rst) begin
            dout <= 0;
            select_input <= 0;
            end
        else if (enable)
            if (counter == 0) begin
                case(hash_type)
                    DOBLAKE: dout <= Blake_prepend;
                    DOGROESTL: dout <= Groestl_prepend;
                    DOJH: dout <= JH_prepend;
                    DOSKEIN: dout <= Skein_prepend;
                endcase
                select_input <= 1;
                end
            else if (counter == 1) begin
                dout <= second_prepend;
                select_input <= 1;
                end
            else if (counter < 27) begin
                select_input <= 0;
                dout <= 0;
                end
            else if (counter >= 27) begin
                select_input <= 1;
                case (hash_type)
                    DOBLAKE:
                        if (counter == 27)
                            dout <= 64'h80 << 56;
                        else if (counter == 32)
                            dout <= 64'h01;
                        else if (counter == 33)
                            dout <= 64'h0640;
                        else
                            dout <= 64'h0;
                    DOGROESTL:
                        if (counter == 27)
                            dout <= 64'h80 << 56;
                        else if (counter == 33)
                            dout <= 64'h04;
                        else
                            dout <= 64'h0;
                    DOJH:
                        if (counter == 27)
                            dout <= 64'h80 << 56;
                        else if (counter == 41)
                            dout <= 64'h0640;
                        else
                            dout <= 64'h0;
                    DOSKEIN:
                        dout <= 64'h0;
                    endcase
                end
                
endmodule
