
`timescale 1ns / 1ps

`define tRESET     20000
`define tWAIT      200
`define tCLK100    10

module tb_postcn();

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
  always @ (posedge clk_slow)
    rst_slow_meta <= {rst_slow_meta[0], rsten};
  wire rst_slow = rst_slow_meta[1];
  
  reg  [1:0] rst_fast_meta = 2'b0;
  always @ (posedge clk_fast)
    rst_fast_meta <= {rst_fast_meta[0], rsten};
  wire rst_fast = rst_fast_meta[1];

  //////////////////////////////////////////////////////////////////////////////
  // Input Data-Nonce

  localparam input_count         =    8;
  localparam output_width        =  256;
  localparam input_width         = 2144;
  localparam nonce_width         =    8;
  localparam nonce_byte_position =   39;
  localparam state_width         = 1600;

  wire [state_width-1:0] post_data_raw = 1600'h0E00F4BBFDEAC47F4D4BF29013ADCDFBBDFB860076EA3D618CFF6DA1920C7F8C60146F81DC2DCAF7A642A787F4DDF50C9607D9CC9580131593ED79D243A53AD712D06C89907632245A7C406C8DC2D0D252257E5D19A11624E894916D56E7DBD3D69C475CF4B7C809F8180AC0010DEB38D1F71CBEECBE5773A7217CA31AC91B434284413FBEC193141C3F1BFC9B361C224A8D2FFAAB8CE5D6351D543F6F0DD84F773F038DD54F7D6B115FC3DC15D2103038A8247E51DCB0D3_D5AC2B7D_21082F27_DB7A1B0F_753ADA4F;
  wire [state_width-1:0] post_data  ;
  wire [nonce_width-1:0] post_nonce    = 8'd0;
  wire                   post_valid ;
  wire                   post_ready ;

  wire [output_width-1:0] out_data       ; // D592B4E62764DEBE95787EDEA542E64D41377C3DE432411B7EA0032EC870572D68001663
  wire                    out_data_valid ;
  wire                    out_data_ready = 1'b1;

  rev_bytes #(.SIZE(state_width)) rev_result (.in(post_data_raw), .out(post_data));

  reg [7:0] counter = 'b0;
  always @(posedge clk_slow)
    if (rst_slow)
      counter <= 'b0;
    else if (post_valid & post_ready)
      counter <= counter + 1;
  
  assign post_valid = (counter < 1);

  //////////////////////////////////////////////////////////////////////////////
  // Post Computation with Keccak

  post_CN #(
    .state_width      (state_width        ),
    .nonce_width      (nonce_width        )
  ) inst_post (
    .clk              ( clk_slow          ),
    .rst              ( rst_slow          ),
    .rstn             (~rst_slow          ),
    .i_valid          ( post_valid        ),
    .o_ready          ( post_ready        ),
    .i_data           ( post_data         ),
    .i_nonce          ( post_nonce        ),
    //
    .o_result         ( out_data          ),
    .o_valid          ( out_data_valid    ),
    .i_ready          ( out_data_ready    )
  );

  //////////////////////////////////////////////////////////////////////////////
  // Simulation Control

  initial begin
    enable <= 1'b0;
    #`tRESET
    #`tWAIT
    enable <= 1'b1;

    @(posedge out_data_valid)
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

  wire [ state_width-1:0] post_data_rev;
  wire [output_width-1:0] out_data_rev ;

  rev_bytes #(.SIZE(state_width )) rev_postdata (.in(post_data), .out(post_data_rev));
  rev_bytes #(.SIZE(output_width)) rev_outdata  (.in(out_data ), .out(out_data_rev ));

  always @(posedge clk_slow) begin
    if (~rst_slow) begin
      if (post_valid      & post_ready    ) $display("CN   -> Post %h|%h", post_nonce, post_data_rev);
      if (out_data_valid  & out_data_ready) $display("Post -> Out  %h"   ,             out_data_rev );
    end
  end


endmodule