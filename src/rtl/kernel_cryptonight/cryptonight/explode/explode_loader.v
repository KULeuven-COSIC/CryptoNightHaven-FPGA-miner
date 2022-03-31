`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/16/2021 09:36:51 AM
// Design Name: 
// Module Name: explode_loader
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


module explode_loader
    #(
        parameter state_width = 'd1600,
        parameter block_width= 'd1024,
        parameter key_width = 'd256,
        parameter nonce_width = 'd7,
        parameter BRAM_addr_width = 'd9
    )
    (
        input clk,
        input rstn,
        input [state_width-1:0] i_v_state,
        input [nonce_width-1:0] i_v_nonce,
        input i_valid,
        input i_ex_done,
        input i_AXI_done,
        output o_ready,
        output [block_width-1:0] o_v_block,
        output [key_width-1:0] o_v_key,
        output o_start,
        output o_nonce_valid,
        output [nonce_width-1:0] o_v_nonce,
        output [state_width-1:0] o_v_state,
        output [BRAM_addr_width-1:0] o_v_addr,
        output o_wr_en,
        output o_rstn_explode
    );

    localparam IDLE = 2'b00;
    localparam LOAD_BRAM = 2'b01;
    localparam START = 2'b10;
    localparam WAIT = 2'b11;
    reg [1:0] next_state;
    wire [1:0] current_state;

    assign current_state = next_state;

    always @(posedge clk)
        if (~rstn)
            next_state <= IDLE;
        else
            case (current_state)
                IDLE: next_state <= i_valid ? LOAD_BRAM : IDLE;
                LOAD_BRAM: next_state <= START;
                START: next_state <= WAIT;
                WAIT: next_state <= (i_ex_done && i_AXI_done) ? IDLE : WAIT;
            endcase

    reg [state_width-1:0] state_reg;
    reg [nonce_width-1:0] nonce_reg;
    always @(posedge clk)
        if (~rstn) begin
            state_reg <= 0;
            nonce_reg <= 0;
        end
        else if (i_valid && o_ready) begin
            state_reg <= i_v_state;
            nonce_reg <= i_v_nonce;
        end

    assign o_ready = current_state == IDLE;
    assign o_v_block = state_reg[block_width+key_width*2-1:key_width*2];
    assign o_v_key = state_reg[key_width-1:0];
    assign o_start = current_state == START;
    assign o_nonce_valid = current_state == START;
    assign o_v_nonce = nonce_reg;
    assign o_v_state = state_reg;
    assign o_v_addr = {{BRAM_addr_width-nonce_width{1'b0}},nonce_reg};
    assign o_wr_en = current_state == LOAD_BRAM;

    reg rstn_explode;
    always @(posedge clk)
        rstn_explode <= ~(i_ex_done && i_AXI_done) && rstn; // reset explode after it's finished
    assign o_rstn_explode = rstn_explode;

endmodule
