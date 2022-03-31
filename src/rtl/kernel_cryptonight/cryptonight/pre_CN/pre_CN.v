`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/20/2021 11:51:33 AM
// Design Name: 
// Module Name: XHV_datapath
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


module pre_CN #(
    parameter nonce_width = 7,
    parameter input_width = 2144
)
    (
        // global signals
        input clk,
        input rstn,
        input [nonce_width-1:0] i_nonce,
        input [input_width-1:0] i_data,
        input i_valid,
        output o_ready,
        input i_CN_ready,
        output o_CN_valid,
        output [nonce_width-1:0] o_CN_nonce,
        output [1599:0] o_CN_data
    );

    localparam state_width = 1600;

    wire [input_width-1:0] K0_in_rev, K0_in;
    wire [state_width-1:0] K0_out, CN_i_data;
    wire [nonce_width-1:0] CN_i_nonce, intermediate_nonce;
    wire post_K0_ready, o_nonce_ready, CN_valid, CN_data_valid, CN_nonce_valid, CN_ready;

    protocol_converter #(
        .IN_PROTOCOL(2), // valid-ready
        .OUT_PROTOCOL(1), // pulse
        .data_width(input_width+nonce_width)
    )
    input_keccak (
        .clk(clk),
        .rstn(rstn),
        .src_in(i_valid),
        .src_out(o_ready),
        .src_data({i_nonce, i_data}),
        .dst_in(post_K0_ready && o_nonce_ready),
        .dst_out(K0_start),
        .dst_data({intermediate_nonce, K0_in_rev})
    );

    rev_bytes #(.SIZE(input_width)) K0_rev(.in(K0_in_rev), .out(K0_in));
    
    Keccak_hash #(.L(input_width),
        .d(1),
        .b(1600),
        .r(1088)
    ) 
    K0 (.i_clk(clk),
        .i_rst(~rstn),
        .i_start(K0_start),
        .i_v_data(K0_in),
        .o_v_data(K0_stub),
        .o_v_state(K0_out), 
        .o_done(K0_done)
    );

    protocol_converter #(
        .IN_PROTOCOL(1), // pulse
        .OUT_PROTOCOL(2), // valid_ready
        .data_width(state_width),
        .busy_reg(0)
    )
    keccak_cryptonight (
        .clk(clk),
        .rstn(rstn),
        .src_in(K0_done),
        .src_out(post_K0_ready),
        .src_data(K0_out),
        .dst_in(CN_ready && CN_nonce_valid),
        .dst_out(CN_data_valid),
        .dst_data(CN_i_data)
    );

    protocol_converter #(
        .IN_PROTOCOL(1), // valid_ready
        .OUT_PROTOCOL(2), // valid_ready
        .data_width(nonce_width),
        .busy_reg(0)
    )
    nonce_cryptonight (
        .clk(clk),
        .rstn(rstn),
        .src_in(K0_start),
        .src_out(o_nonce_ready),
        .src_data(intermediate_nonce),
        .dst_in(CN_ready && CN_data_valid),
        .dst_out(CN_nonce_valid),
        .dst_data(CN_i_nonce)
    );

    assign CN_valid = CN_nonce_valid && CN_data_valid;
    assign o_CN_valid = CN_valid;
    assign o_CN_nonce = CN_i_nonce;
    assign CN_ready = i_CN_ready;
    assign o_CN_data = CN_i_data;
endmodule
