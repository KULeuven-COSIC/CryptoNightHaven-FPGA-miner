`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/16/2021 10:30:37 AM
// Design Name: 
// Module Name: shuffle_loader
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


module shuffle_loader
    #(
        parameter nonce_width = 7,
        parameter explode_width = 512
    )
    (
        input clk,
        input rst,
        input i_ex_valid,
        output o_ex_handshake,
        input [explode_width-1:0] i_ex_data,
        input [nonce_width-1:0] i_nonce,

        output o_sh_valid,
        input i_sh_ready,
        output [explode_width/4-1:0] o_sh_data,
        output [nonce_width-1:0] o_nonce
    );

    localparam [2:0] IDLE = 0;
    localparam [2:0] LOAD0 = 1;
    localparam [2:0] LOAD1 = 2;
    localparam [2:0] LOAD2 = 3;
    localparam [2:0] LOAD3 = 4;
    localparam shuffle_width = explode_width / 4;

    // do handshake with explode to cross clock domains
    // do an AXI-like transaction with shuffle

    wire [2:0] current_state;
    reg [2:0] next_state;

    assign current_state = next_state;
    always @(posedge clk)
        if (rst)
            next_state <= IDLE;
        else case (current_state)
            IDLE: next_state <= i_ex_valid ? LOAD0 : IDLE;
            LOAD0: next_state <= i_sh_ready ? LOAD1 : LOAD0;
            LOAD1: next_state <= LOAD2;
            LOAD2: next_state <= LOAD3;
            LOAD3: next_state <= i_ex_valid ? LOAD3 : IDLE; // since the handshake can be slow: don't go back to idle until handshake is done
            default: next_state <= IDLE;
        endcase

    reg [explode_width-1:0] data_reg;
    reg [nonce_width-1:0] nonce_reg;
    reg handshake;
    always @(posedge clk)
        if (rst) begin
            data_reg <= 0;
            nonce_reg <= 0;
        end
        else if (i_ex_valid) begin
            data_reg <= i_ex_data;
            nonce_reg <= i_nonce;
        end

    always @(posedge clk)
        if (rst)
            handshake <= 0;
        else if (current_state == IDLE || handshake == 1)
            handshake <= i_ex_valid;
    assign o_ex_handshake = handshake;

    function automatic [shuffle_width-1:0] sh_data(input[2:0] current_state, input [explode_width-1:0] data);
        case (current_state)
            IDLE: sh_data = 0;
            LOAD1: sh_data = {data[shuffle_width*2/2-1:shuffle_width*1/2], data[shuffle_width*6/2-1:shuffle_width*5/2]};
            LOAD0: sh_data = {data[shuffle_width*1/2-1:shuffle_width*0/2], data[shuffle_width*5/2-1:shuffle_width*4/2]};
            LOAD2: sh_data = {data[shuffle_width*3/2-1:shuffle_width*2/2], data[shuffle_width*7/2-1:shuffle_width*6/2]};
            LOAD3: sh_data = {data[shuffle_width*4/2-1:shuffle_width*3/2], data[shuffle_width*8/2-1:shuffle_width*7/2]};
            default: sh_data = 0;
        endcase
    endfunction

    assign o_sh_data = sh_data(current_state, data_reg);
    assign o_sh_valid = current_state == LOAD0;
    assign o_nonce = nonce_reg;

endmodule
