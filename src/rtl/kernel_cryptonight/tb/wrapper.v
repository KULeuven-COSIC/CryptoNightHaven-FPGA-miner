`timescale 1 ps / 1 ps

module test_wrapper
   (axi_base_addr,
    clk,
    clk_fast,
    clk_slow,
    i_nonce,
    i_state,
    i_valid,
    o_data,
    o_done,
    o_nonce,
    o_ready,
    rstn,
    rstn_fast,
    rstn_slow);
  input [63:0]axi_base_addr;
  input clk;
  input clk_fast;
  input clk_slow;
  input [7:0]i_nonce;
  input [1599:0]i_state;
  input i_valid;
  output [1599:0]o_data;
  output o_done;
  output [7:0]o_nonce;
  output o_ready;
  input rstn;
  input rstn_fast;
  input rstn_slow;

  wire [63:0]axi_base_addr;
  wire clk;
  wire clk_fast;
  wire clk_slow;
  wire [7:0]i_nonce;
  wire [1599:0]i_state;
  wire i_valid;
  wire [1599:0]o_data;
  wire o_done;
  wire [7:0]o_nonce;
  wire o_ready;
  wire rstn;
  wire rstn_fast;
  wire rstn_slow;

  cryptonight_logic_bd_tb cryptonight_logic_bd_tb_i
       (.axi_base_addr(axi_base_addr),
        .clk(clk),
        .clk_fast(clk_fast),
        .clk_slow(clk_slow),
        .i_nonce(i_nonce),
        .i_state(i_state),
        .i_valid(i_valid),
        .o_data(o_data),
        .o_done(o_done),
        .o_nonce(o_nonce),
        .o_ready(o_ready),
        .rstn(rstn),
        .rstn_fast(rstn_fast),
        .rstn_slow(rstn_slow));
endmodule
