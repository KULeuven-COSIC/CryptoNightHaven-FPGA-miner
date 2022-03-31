`timescale 1 ns / 1 ps

module integrate_nonce #(
    parameter INPUT_COUNT =    8,
    parameter INPUT_WIDTH = 2144,
    parameter NONCE_WIDTH =   32,
    parameter NONCE_POS   =   39
  )
  (
    input  wire                   input_data_aclk  ,
    input  wire                   input_data_rst_n ,
    input  wire [INPUT_WIDTH-1:0] input_data_raw   ,
    input  wire [NONCE_WIDTH-1:0] input_nonce      ,
    output wire [INPUT_WIDTH-1:0] input_data       ,
    output wire [INPUT_WIDTH-1:0] input_data       ,
    output wire                   input_data_valid ,
    input  wire                   input_data_ready
  );

  reg [NONCE_WIDTH-1:0] nonce = 'b0;
  always @(posedge input_data_aclk)
    if (~input_data_rst_n)
      nonce <= 'b0;
    else if (input_data_valid & input_data_ready)
      nonce <= nonce + 1;

  wire [INPUT_WIDTH-1:0] input_data_raw_rev;
  rev_bytes #(.SIZE(INPUT_WIDTH)) rev_result (.in(input_data_raw), .out(input_data_raw_rev));

  wire [INPUT_WIDTH-1:0] input_data_raw_rev_nonce;
  assign input_data_raw_rev_nonce = {input_data_raw_rev[INPUT_WIDTH-1:NONCE_POS*8+NONCE_WIDTH], input_nonce, input_data_raw_rev[NONCE_POS*8-1:0]};

  assign input_data = input_data_raw_rev_nonce;

  assign input_data_valid = (nonce < INPUT_COUNT);

endmodule
