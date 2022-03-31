`timescale 1ns / 1ps

`define tRESET     20000
`define tWAIT      200
`define tCLK100    10

module tb_cryptonight_logic();

  //////////////////////////////////////////////////////////////////////////////
  // Clock Generation

  reg clk_100;

  initial begin
    clk_100 = 1'b1;
  end

  always begin
    #(`tCLK100*0.5) 
    clk_100 = ~clk_100;
  end

  wire clk_slow_local, clk_slow;
  wire clk_fast_local, clk_fast;
  wire pll_fb;
  MMCME2_BASE #(
    // For 100-400 MHz Clocks
    .CLKIN1_PERIOD    (10  ),
    .CLKFBOUT_MULT_F  ( 8  ),
    .DIVCLK_DIVIDE    ( 1  ),
    .CLKOUT0_DIVIDE_F ( 8.0),
    .CLKOUT1_DIVIDE   ( 2  )
    // For 200-500 MHz Clocks
    // .CLKIN1_PERIOD    (10  ),
    // .CLKFBOUT_MULT_F  (10  ),
    // .DIVCLK_DIVIDE    ( 1  ),
    // .CLKOUT0_DIVIDE_F ( 5.0),
    // .CLKOUT1_DIVIDE   ( 2  )
  ) pll_inst (
    .CLKIN1       (clk_100        ),
    .CLKFBOUT     (pll_fb         ),
    .CLKFBIN      (pll_fb         ),
    .CLKOUT0      (clk_slow_local ),
    .CLKOUT1      (clk_fast_local ),
    .LOCKED       (               )
  );

  BUFG bufg_slow ( .I(clk_slow_local), .O(clk_slow) );
  BUFG bufg_fast ( .I(clk_fast_local), .O(clk_fast) );

  //////////////////////////////////////////////////////////////////////////////
  // Reset Generation

  reg rst;  
  initial begin
    rst      <= 1'b1;    
    #`tRESET
    rst      <= 1'b0;
  end
  
  reg enable;
  wire rsten = (enable) ? rst : 1'b1;
  
  reg  [1:0] rst_slow_meta = 2'b0;
  reg rst_slow_r = 1'b0;
  always @ (posedge clk_slow) begin
    rst_slow_meta <= {rst_slow_meta[0], rsten};
    rst_slow_r <= rst_slow;
  end
  wire rst_slow = rst_slow_meta[1];
  wire start_pulse_slow = ~rst_slow & rst_slow_r;
  
  reg  [1:0] rst_fast_meta = 2'b0;
  reg rst_fast_r = 1'b0;
  always @ (posedge clk_fast) begin
    rst_fast_meta <= {rst_fast_meta[0], rsten};
    rst_fast_r <= rst_fast;
  end
  wire rst_fast = rst_fast_meta[1];
  wire start_pulse_slow = ~rst_fast & rst_fast_r;

  //////////////////////////////////////////////////////////////////////////////
  // Parameters

  localparam input_count         =    8;
  localparam input_width         = 2144;
  localparam nonce_width         =   32;
  localparam nonce_width_cn      =    8;
  localparam nonce_byte_position =   39;
  localparam state_width         = 1600;

  //////////////////////////////////////////////////////////////////////////////
  // Synchronisation Wires

  wire    [input_width-1:0] pre_data  ;
  wire    [nonce_width-1:0] pre_nonce ;
  wire                      pre_valid ;
  wire                      pre_ready ;
  
  wire    [state_width-1:0] CN_data  ;
  wire [nonce_width_cn-1:0] CN_nonce ;
  wire                      CN_valid ;
  wire                      CN_ready ;

  wire    [state_width-1:0] post_data  ;
  wire    [nonce_width-1:0] post_nonce ;
  wire                      post_valid ;
  wire                      post_ready = 1'b1;

  //////////////////////////////////////////////////////////////////////////////
  // Counters of how many times each module consumed data

  reg [nonce_width-1:0] pre_counter   = 'b0;
  reg [nonce_width-1:0] cn_counter    = 'b0;
  reg [nonce_width-1:0] post_counter  = 'b0;
  
  always @(posedge clk_slow) begin
    if (start_pulse_slow) begin
      pre_counter  <= 'b0;
      cn_counter   <= 'b0;
      post_counter <= 'b0;
    end
    else begin
      if (pre_valid  & pre_ready ) pre_counter  <= pre_counter  + 1;
      if (CN_valid   & CN_ready  ) cn_counter   <= cn_counter   + 1;
      if (post_valid & post_ready) post_counter <= post_counter + 1;
    end
  end

  reg [3:0] pipeline_counter = 4'd8;
  always @(posedge clk_slow) begin
    if (start_pulse_slow) begin
      pipeline_counter = 4'd2;
    end
    else begin
      if      ((CN_valid   & CN_ready  ) && pipeline_counter>4'd0) pipeline_counter  <= pipeline_counter - 4'd1;
      // else if ((post_valid & post_ready) && pipeline_counter<4'd8) pipeline_counter  <= pipeline_counter + 4'd1;
    end
  end

  //////////////////////////////////////////////////////////////////////////////
  // Input Data Preparation

  wire [input_width-1:0] in_data  ;
  wire [nonce_width-1:0] in_nonce ;

  wire [input_width-1:0] in_data_raw_rev = 2144'h1313BADED891061A41B9EA58109B44EA5DA3FA0AF8A55365B4C9FA7B50800F8D6EB94910A017AA00000000904E0C5709000000B021051F00000000808262C939010000B0016B01000000000000000000000000F05D7305D9000000F0AF2B15C90500004043734AD200000090781FA4B0000000000000000000000000000000000000000000000000000000004CC48FCF03000000F26F71F6030000009EB277F70300000063EA36BE0300003A2F3662000000006D4AEFB3B168F4D374890D8E31C99CAD6C878E9D3A4E1720B2F3302D0D38B9A7630800D5906202EB4FA31F73D99B2DEBC278B07B6F781FAB9F210FC0868A8E2C5511AFD06EAD64FDCF26E7C1DB100B03359CEAE373EF3E01CD;
  wire [input_width-1:0] in_data_raw;

  rev_bytes #(.SIZE(input_width)) rev_indata (.in(in_data_raw_rev), .out(in_data_raw));
  
  assign in_data = {
    in_data_raw[input_width-1:nonce_byte_position*8+nonce_width], 
    in_nonce, 
    in_data_raw[nonce_byte_position*8-1:0]
  };

  assign in_nonce = pre_counter;

  //////////////////////////////////////////////////////////////////////////////
  // Pre Computation with Keccak

  assign pre_data  = in_data;
  assign pre_nonce = pre_counter;
  assign pre_valid = pipeline_counter > 4'd0;

  pre_CN #(
    .nonce_width      (nonce_width        ),
    .input_width      (input_width        )
  ) inst_pre (
    .clk              (clk_slow           ),
    .rstn             (~rst_slow          ),
    //
    .i_data           (pre_data           ),
    .i_nonce          (pre_nonce          ), //pre_data[nonce_byte_position*8+:nonce_width]),
    .i_valid          (pre_valid          ),
    .o_ready          (pre_ready          ),
    //
    .o_CN_data        (CN_data            ),
    .o_CN_nonce       (                   ), // CN_nonce
    .o_CN_valid       (CN_valid           ),
    .i_CN_ready       (CN_ready           )
  );

  //////////////////////////////////////////////////////////////////////////////
  // Cryptonight Module Under Test

  assign CN_nonce   = cn_counter[nonce_width_cn-1:0];
  assign post_nonce = post_counter;

  test_wrapper test_wrapper (
    .clk           ( clk_100    ),
    .clk_slow      ( clk_slow   ),
    .clk_fast      ( clk_fast   ),
     //    
    .rstn          (~rst        ),
    .rstn_slow     (~rst_slow   ),
    .rstn_fast     (~rst_fast   ),
    // 
    .axi_base_addr ( 64'b0      ),
    .i_nonce       ( CN_nonce   ),
    .i_state       ( CN_data    ),
    .i_valid       ( CN_valid   ),
    .o_ready       ( CN_ready   ),
    .o_done        ( post_valid ),
    .o_data        ( post_data  ),
    .o_nonce       (            )
  );

  //////////////////////////////////////////////////////////////////////////////
  // Simulation Control

  initial begin
    enable <= 1'b0;
    #`tRESET
    #`tWAIT
    enable <= 1'b1;

    // @(posedge CN_valid)
    @(posedge post_valid)
    #`tWAIT

    // @(posedge post_valid)
    // // $display("%128x", post_data);
    // @(posedge post_valid)
    // // $display("%128x", post_data);
    // @(posedge post_valid)
    // // $display("%128x", post_data);
    // @(posedge post_valid)
    // // $display("%128x", post_data);
    // // #`tRESET
    $finish;
  end

  //////////////////////////////////////////////////////////////////////////////
  // Prints

  wire [ input_width-1:0] pre_data_rev ;
  wire [ state_width-1:0] CN_data_rev  ;
  wire [ state_width-1:0] post_data_rev;

  rev_bytes #(.SIZE(input_width )) rev_predata  (.in(pre_data ), .out(pre_data_rev ));
  rev_bytes #(.SIZE(state_width )) rev_cndata   (.in(CN_data  ), .out(CN_data_rev  ));
  rev_bytes #(.SIZE(state_width )) rev_postdata (.in(post_data), .out(post_data_rev));

  always @(posedge clk_slow) begin
    if (~rst_slow) begin
      if (pre_valid  & pre_ready  ) $display("In  ->Pre  %h|%h", pre_nonce , pre_data_rev );
      if (CN_valid   & CN_ready   ) $display("Pre ->CN   %h|%h", CN_nonce  , CN_data_rev  );
      if (post_valid & post_ready ) $display("CN  ->Post %h|%h", post_nonce, post_data_rev);
    end
  end


endmodule