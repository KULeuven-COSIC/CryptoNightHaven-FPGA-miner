// default_nettype of none prevents implicit wire declaration.
`default_nettype none

`timescale 1 ns / 1 ps

`define AXI_ADDR_WIDTH   64
`define AXI_DATA_WIDTH  128

module cryptonight_top #(
  parameter input_width                =             2144,
  parameter output_width               =              256,
  parameter nonce_width                =               32,
  parameter nonce_width_cn             =                7,
  parameter nonce_byte_position        =               39,
  parameter scratch_rounds             =          'h40000, // amount of rounds to generate scratchpad
  parameter shuffle_rounds             =          'h40000, // amount of rounds performed by shuffle
  parameter CN_XHV                     =                0, // CN XHV (1) or CN Heavy (0)
  parameter state_width                =             1600,
  parameter buffer_depth               =              128,

  parameter C_S_AXI_CONTROL_ADDR_WIDTH =               12,
  parameter C_S_AXI_CONTROL_DATA_WIDTH =               32,
  parameter C_M00_AXI_DATA_WIDTH       =  `AXI_DATA_WIDTH,
  parameter C_M00_AXI_ADDR_WIDTH       =  `AXI_ADDR_WIDTH,
  parameter C_M01_AXI_DATA_WIDTH       =  `AXI_DATA_WIDTH,
  parameter C_M01_AXI_ADDR_WIDTH       =  `AXI_ADDR_WIDTH,
  parameter C_M02_AXI_DATA_WIDTH       =  `AXI_DATA_WIDTH,
  parameter C_M02_AXI_ADDR_WIDTH       =  `AXI_ADDR_WIDTH
)
(
  // Note: A minimum subset of AXI4 memory mapped signals are declared.
  // AXI signals omitted from these interfaces are automatically inferred with
  // the optimal values for Xilinx SDx systems.
  // This allows Xilinx AXI4 Interconnects within the system to be optimized by
  // removing logic for AXI4 protocol features that are not necessary.
  // When adapting AXI4 masters within the RTL kernel that have signals not
  // declared below, it is suitable to add the signals to the declarations
  // below to connect them to the AXI4 Master.

  // List of ommited signals - effect
  // -------------------------------
  // ID     - Transaction ID are used for multithreading and out of order
  //          transactions.  This increases complexity. This saves logic and
  //          increases Fmax in the system when ommited.
  // SIZE   - Default value is log2(data width in bytes). Needed for subsize
  //          bursts. This saves logic and increases Fmax in the system when
  //          ommited.
  // BURST  - Default value (0b01) is incremental. Wrap and fixed bursts are
  //          not recommended. This saves logic and increases Fmax in the
  //          system when ommited.
  // LOCK   - Not supported in AXI4
  // CACHE  - Default value (0b0011) allows modifiable transactions. No benefit
  //          to changing this.
  // PROT   - Has no effect in SDx systems.
  // QOS    - Has no effect in SDx systems.
  // REGION - Has no effect in SDx systems.
  // USER   - Has no effect in SDx systems.
  // RESP   - Not useful in most SDx systems.

  // AXI4-Lite slave interface
  input  wire                                     s_axi_control_aclk    ,
  input  wire                                     s_axi_control_awvalid ,
  output wire                                     s_axi_control_awready ,
  input  wire [C_S_AXI_CONTROL_ADDR_WIDTH-1:0]    s_axi_control_awaddr  ,
  input  wire                                     s_axi_control_wvalid  ,
  output wire                                     s_axi_control_wready  ,
  input  wire [C_S_AXI_CONTROL_DATA_WIDTH-1:0]    s_axi_control_wdata   ,
  input  wire [C_S_AXI_CONTROL_DATA_WIDTH/8-1:0]  s_axi_control_wstrb   ,
  input  wire                                     s_axi_control_arvalid ,
  output wire                                     s_axi_control_arready ,
  input  wire [C_S_AXI_CONTROL_ADDR_WIDTH-1:0]    s_axi_control_araddr  ,
  output wire                                     s_axi_control_rvalid  ,
  input  wire                                     s_axi_control_rready  ,
  output wire [C_S_AXI_CONTROL_DATA_WIDTH-1:0]    s_axi_control_rdata   ,
  output wire [2-1:0]                             s_axi_control_rresp   ,
  output wire                                     s_axi_control_bvalid  ,
  input  wire                                     s_axi_control_bready  ,
  output wire [2-1:0]                             s_axi_control_bresp   ,

  // AXI4 master interface m00_axi
  output wire [C_M00_AXI_ADDR_WIDTH-1:0]          m00_axi_awaddr        ,
  output wire [8-1:0]                             m00_axi_awlen         ,
  output wire [2:0]                               m00_axi_awsize        ,
  output wire [1:0]                               m00_axi_awburst       ,
  output wire                                     m00_axi_awvalid       ,
  input  wire                                     m00_axi_awready       ,
  output wire [C_M00_AXI_DATA_WIDTH-1:0]          m00_axi_wdata         ,
  output wire [C_M00_AXI_DATA_WIDTH/8-1:0]        m00_axi_wstrb         ,
  output wire                                     m00_axi_wlast         ,
  output wire                                     m00_axi_wvalid        ,
  input  wire                                     m00_axi_wready        ,
  input  wire [1:0]                               m00_axi_bresp         ,
  input  wire                                     m00_axi_bvalid        ,
  output wire                                     m00_axi_bready        ,
//output wire [C_M00_AXI_ADDR_WIDTH-1:0]          m00_axi_araddr        ,
//output wire [8-1:0]                             m00_axi_arlen         ,
//output wire [2:0]                               m00_axi_arsize        ,
//output wire [1:0]                               m00_axi_arburst       ,
//output wire                                     m00_axi_arvalid       ,
//input  wire                                     m00_axi_arready       ,
//input  wire [C_M00_AXI_DATA_WIDTH-1:0]          m00_axi_rdata         ,
//input  wire                                     m00_axi_rlast         ,
//input  wire [1:0]                               m00_axi_rresp         ,
//input  wire                                     m00_axi_rvalid        ,
//output wire                                     m00_axi_rready        ,

  // AXI4 master interface m01_axi
  output wire [C_M01_AXI_ADDR_WIDTH-1:0]          m01_axi_awaddr        ,
  output wire [8-1:0]                             m01_axi_awlen         ,
  output wire [2:0]                               m01_axi_awsize        ,
  output wire [1:0]                               m01_axi_awburst       ,
  output wire                                     m01_axi_awvalid       ,
  input  wire                                     m01_axi_awready       ,
  output wire [C_M01_AXI_DATA_WIDTH-1:0]          m01_axi_wdata         ,
  output wire [C_M01_AXI_DATA_WIDTH/8-1:0]        m01_axi_wstrb         ,
  output wire                                     m01_axi_wlast         ,
  output wire                                     m01_axi_wvalid        ,
  input  wire                                     m01_axi_wready        ,
  input  wire [1:0]                               m01_axi_bresp         ,
  input  wire                                     m01_axi_bvalid        ,
  output wire                                     m01_axi_bready        ,
  output wire [C_M01_AXI_ADDR_WIDTH-1:0]          m01_axi_araddr        ,
  output wire [8-1:0]                             m01_axi_arlen         ,
  output wire [2:0]                               m01_axi_arsize        ,
  output wire [1:0]                               m01_axi_arburst       ,
  output wire                                     m01_axi_arvalid       ,
  input  wire                                     m01_axi_arready       ,
  input  wire [C_M01_AXI_DATA_WIDTH-1:0]          m01_axi_rdata         ,
  input  wire                                     m01_axi_rlast         ,
  input  wire [1:0]                               m01_axi_rresp         ,
  input  wire                                     m01_axi_rvalid        ,
  output wire                                     m01_axi_rready        ,

  // AXI4 master interface m02_axi
//output wire [C_M02_AXI_ADDR_WIDTH-1:0]          m02_axi_awaddr        ,
//output wire [8-1:0]                             m02_axi_awlen         ,
//output wire [2:0]                               m02_axi_awsize        ,
//output wire [1:0]                               m02_axi_awburst       ,
//output wire                                     m02_axi_awvalid       ,
//input  wire                                     m02_axi_awready       ,
//output wire [C_M02_AXI_DATA_WIDTH-1:0]          m02_axi_wdata         ,
//output wire [C_M02_AXI_DATA_WIDTH/8-1:0]        m02_axi_wstrb         ,
//output wire                                     m02_axi_wlast         ,
//output wire                                     m02_axi_wvalid        ,
//input  wire                                     m02_axi_wready        ,
//input  wire [1:0]                               m02_axi_bresp         ,
//input  wire                                     m02_axi_bvalid        ,
//output wire                                     m02_axi_bready        ,
  output wire [C_M02_AXI_ADDR_WIDTH-1:0]          m02_axi_araddr        ,
  output wire [8-1:0]                             m02_axi_arlen         ,
  output wire [2:0]                               m02_axi_arsize        ,
  output wire [1:0]                               m02_axi_arburst       ,
  output wire                                     m02_axi_arvalid       ,
  input  wire                                     m02_axi_arready       ,
  input  wire [C_M02_AXI_DATA_WIDTH-1:0]          m02_axi_rdata         ,
  input  wire                                     m02_axi_rlast         ,
  input  wire [1:0]                               m02_axi_rresp         ,
  input  wire                                     m02_axi_rvalid        ,
  output wire                                     m02_axi_rready        ,

  input  wire                                     m00_axi_aclk          ,
  input  wire                                     m01_axi_aclk          ,
  input  wire                                     m02_axi_aclk          ,

  output wire                                     slow_clk              ,
  output wire                                     fast_clk              ,

  input  wire                                     ap_clk                ,
  input  wire                                     ap_rst_n              ,
  output wire                                     interrupt
);

////////////////////////////////////////////////////////////////////////////////
// Clocks
////////////////////////////////////////////////////////////////////////////////

  wire clk_ap = ap_clk;

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
    .CLKIN1       (clk_ap         ),
    .CLKFBOUT     (pll_fb         ),
    .CLKFBIN      (pll_fb         ),
    .CLKOUT0      (clk_slow_local ),
    .CLKOUT1      (clk_fast_local ),
    .LOCKED       (               )
  );

  BUFG bufg_slow ( .I(clk_slow_local), .O(clk_slow) );
  BUFG bufg_fast ( .I(clk_fast_local), .O(clk_fast) );

  assign slow_clk = clk_slow;
  assign fast_clk = clk_fast;

////////////////////////////////////////////////////////////////////////////////
// Resets
////////////////////////////////////////////////////////////////////////////////

  wire rst_n_ap = ap_rst_n;

  reg  enable = 1'b0;
  wire rst_n_c = (enable) ? ap_rst_n : 1'b0;

  reg [1:0] rst_n_c_slow_meta = 2'b0;
  reg rst_n_c_slow_r = 1'b0;
  always @ (posedge clk_slow) begin
    rst_n_c_slow_meta <= {rst_n_c_slow_meta[0], rst_n_c};
    rst_n_c_slow_r <= rst_n_c_slow;
  end
  wire rst_n_c_slow = rst_n_c_slow_meta[1];
  wire start_pulse_slow = rst_n_c_slow & ~rst_n_c_slow_r;

  reg [1:0] rst_n_c_fast_meta = 2'b0;
  reg rst_n_c_fast_r = 1'b0;
  always @ (posedge clk_fast) begin
    rst_n_c_fast_meta <= {rst_n_c_fast_meta[0], rst_n_c};
    rst_n_c_fast_r <= rst_n_c_fast;
  end
  wire rst_n_c_fast = rst_n_c_fast_meta[1];
  wire start_pulse_fast = rst_n_c_fast & ~rst_n_c_fast_r;

////////////////////////////////////////////////////////////////////////////////
// Wires and Variables
////////////////////////////////////////////////////////////////////////////////

  // HBM Base Address from SW
  wire [`AXI_ADDR_WIDTH-1:0] hbm_addr;

  // CSR Data from SW
  wire [32-1:0] csr0_from_sw;

  // CSR Data to SW
  reg [32-1:0] csr0_to_sw;
  reg [32-1:0] csr1_to_sw;
  reg [32-1:0] csr2_to_sw;
  reg [32-1:0] csr3_to_sw;
  reg [32-1:0] csr4_to_sw;
  reg [32-1:0] csr5_to_sw;
  reg [32-1:0] csr6_to_sw;
  reg [32-1:0] csr7_to_sw;

////////////////////////////////////////////////////////////////////////////////
// Control Interface: ap_ctrl_hs
////////////////////////////////////////////////////////////////////////////////

  wire ap_start ;
  wire ap_idle  ;
  wire ap_ready ;
  wire ap_done  ; reg ap_done_r = 1'b0;

  reg cmd_exit = 1'b0;

  reg ap_is_busy = 1'b0;
  always @(posedge clk_ap)
    if (~rst_n_ap || ap_done)
      ap_is_busy <= 1'b0;
    else if (ap_start)
      ap_is_busy <= 1'b1;

  always @(posedge clk_ap)
    if (~rst_n_ap)
      ap_done_r <= 1'b0;
    else if (cmd_exit)
      ap_done_r <= 1'b1;

  assign ap_idle  = ~ap_start & ~ap_is_busy;
  assign ap_ready = ap_done;
  assign ap_done  = cmd_exit & ~ap_done_r;

  always @(posedge clk_ap)
    enable <= ~ap_idle;

////////////////////////////////////////////////////////////////////////////////
// Control/Status Registers
////////////////////////////////////////////////////////////////////////////////

  csrs #(
    .C_S_AXI_ADDR_WIDTH ( C_S_AXI_CONTROL_ADDR_WIDTH ),
    .C_S_AXI_DATA_WIDTH ( C_S_AXI_CONTROL_DATA_WIDTH )
  )
  inst_csrs (
    .ACLK              ( ap_clk                ),
    .ARESET            ( 1'b0                  ),
    .ACLK_EN           ( 1'b1                  ),
    //
    .AWVALID           ( s_axi_control_awvalid ),
    .AWREADY           ( s_axi_control_awready ),
    .AWADDR            ( s_axi_control_awaddr  ),
    .WVALID            ( s_axi_control_wvalid  ),
    .WREADY            ( s_axi_control_wready  ),
    .WDATA             ( s_axi_control_wdata   ),
    .WSTRB             ( s_axi_control_wstrb   ),
    .ARVALID           ( s_axi_control_arvalid ),
    .ARREADY           ( s_axi_control_arready ),
    .ARADDR            ( s_axi_control_araddr  ),
    .RVALID            ( s_axi_control_rvalid  ),
    .RREADY            ( s_axi_control_rready  ),
    .RDATA             ( s_axi_control_rdata   ),
    .RRESP             ( s_axi_control_rresp   ),
    .BVALID            ( s_axi_control_bvalid  ),
    .BREADY            ( s_axi_control_bready  ),
    .BRESP             ( s_axi_control_bresp   ),
    //
    .interrupt         ( interrupt             ),
    .ap_start          ( ap_start              ),
    .ap_idle           ( ap_idle               ),
    .ap_ready          ( ap_ready              ),
    .ap_done           ( ap_done               ),
    //
    .hbm_addr          ( hbm_addr              ),
    .csr0_i            ( csr0_to_sw            ), // input  to   SW
    .csr0_o            ( csr0_from_sw          ), // output from SW
    .csr1_i            ( csr1_to_sw            ),
    .csr1_o            (                       ),
    .csr2_i            ( csr2_to_sw            ),
    .csr2_o            (                       ),
    .csr3_i            ( csr3_to_sw            ),
    .csr3_o            (                       ),
    .csr4_i            ( csr4_to_sw            ),
    .csr4_o            (                       ),
    .csr5_i            ( csr5_to_sw            ),
    .csr5_o            (                       ),
    .csr6_i            ( csr6_to_sw            ),
    .csr6_o            (                       ),
    .csr7_i            ( csr7_to_sw            ),
    .csr7_o            (                       )
  );

////////////////////////////////////////////////////////////////////////////////
// Computation Modules
////////////////////////////////////////////////////////////////////////////////

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
  wire                      post_ready ;

  wire   [output_width-1:0] out_data  ;
  wire                      out_valid ;
  wire                      out_ready = 1'b1;

  //////////////////////////////////////////////////////////////////////////////
  // Counters of how many times each module consumed data

  reg [nonce_width-1:0] pre_counter   = 'b0;
  reg [nonce_width-1:0] cn_counter    = 'b0;
  reg [nonce_width-1:0] post_counter  = 'b0;
  reg [nonce_width-1:0] out_counter   = 'b0;
  reg [64-1:0]          cycle_counter = 'b0;
  
  always @(posedge clk_slow) begin
    if (start_pulse_slow) begin
      pre_counter   <= 'b0;
      cn_counter    <= 'b0;
      post_counter  <= 'b0;
      out_counter   <= 'b0;
      cycle_counter <= 'b0;
    end
    else begin
      if (pre_valid  & pre_ready ) pre_counter   <= pre_counter   + 1;
      if (CN_valid   & CN_ready  ) cn_counter    <= cn_counter    + 1;
      if (post_valid & post_ready) post_counter  <= post_counter  + 1;
      if (out_valid  & out_ready ) out_counter   <= out_counter   + 1;
      if (enable                 ) cycle_counter <= cycle_counter + 1;
    end
  end

  //////////////////////////////////////////////////////////////////////////////
  // Input Data Preparation

  wire [input_width-1:0] in_data;
  wire [nonce_width-1:0] in_nonce;

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
  // assign pre_valid = (pre_counter < 5);
  assign pre_valid = 1'b1;

  pre_CN #(
    .nonce_width      (nonce_width        ),
    .input_width      (input_width        )
  ) inst_pre (
    .clk              (clk_slow           ),
    .rstn             (rst_n_c_slow       ),
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
  // Main Computation

  assign CN_nonce = cn_counter[nonce_width_cn-1:0];

  cryptonight_logic #(
    .scratch_rounds   (scratch_rounds     ),
    .shuffle_rounds   (shuffle_rounds     ),
    .CN_XHV           (CN_XHV             ),
    .nonce_width      (nonce_width_cn     ),
    .buffer_depth     (buffer_depth       ),
    .state_width      (state_width        ),
    .block_width      (1024               ),
    .key_width        (256                ),
    .INT_ADDR_WIDTH   (32                 ),
    .AXI_ADDR_WIDTH   (`AXI_ADDR_WIDTH    ),
    .AXI_DATA_WIDTH   (`AXI_DATA_WIDTH    )
  ) inst_cryptonight_logic (
    .m00_axi_aclk     (m00_axi_aclk       ),
    .m01_axi_aclk     (m01_axi_aclk       ),
    .m02_axi_aclk     (m02_axi_aclk       ),
    .clk_ap           (clk_ap             ),
    .clk_slow         (clk_slow           ),
    .clk_fast         (clk_fast           ),
    .rstn_slow        (rst_n_c_slow       ),
    .rstn_fast        (rst_n_c_fast       ),
    //
    .i_nonce          (CN_nonce           ),
    .i_state          (CN_data            ),
    .i_valid          (CN_valid           ),
    .o_ready          (CN_ready           ),
    //
    .o_done           (post_valid         ),
    .o_data           (post_data          ),
    .o_nonce          (                   ), // post_nonce
    //
    .axi_base_addr    (hbm_addr           ),
    // explode
    .m00_axi_awaddr   (m00_axi_awaddr     ),
    .m00_axi_awlen    (m00_axi_awlen      ),
    .m00_axi_awsize   (m00_axi_awsize     ),
    .m00_axi_awburst  (m00_axi_awburst    ),
    .m00_axi_awvalid  (m00_axi_awvalid    ),
    .m00_axi_awready  (m00_axi_awready    ),
    .m00_axi_wdata    (m00_axi_wdata      ),
    .m00_axi_wstrb    (m00_axi_wstrb      ),
    .m00_axi_wlast    (m00_axi_wlast      ),
    .m00_axi_wvalid   (m00_axi_wvalid     ),
    .m00_axi_wready   (m00_axi_wready     ),
    .m00_axi_bresp    (m00_axi_bresp      ),
    .m00_axi_bvalid   (m00_axi_bvalid     ),
    .m00_axi_bready   (m00_axi_bready     ),
  //.m00_axi_araddr   (                   ),
  //.m00_axi_arlen    (                   ),
  //.m00_axi_arsize   (                   ),
  //.m00_axi_arburst  (                   ),
  //.m00_axi_arvalid  (                   ),
  //.m00_axi_arready  (                   ),
  //.m00_axi_rdata    (                   ),
  //.m00_axi_rlast    (                   ),
  //.m00_axi_rresp    (                   ),
  //.m00_axi_rvalid   (                   ),
  //.m00_axi_rready   (                   ),

    // shuffle
    .m01_axi_awaddr   (m01_axi_awaddr     ),
    .m01_axi_awlen    (m01_axi_awlen      ),
    .m01_axi_awsize   (m01_axi_awsize     ),
    .m01_axi_awburst  (m01_axi_awburst    ),
    .m01_axi_awvalid  (m01_axi_awvalid    ),
    .m01_axi_awready  (m01_axi_awready    ),
    .m01_axi_wdata    (m01_axi_wdata      ),
    .m01_axi_wstrb    (m01_axi_wstrb      ),
    .m01_axi_wlast    (m01_axi_wlast      ),
    .m01_axi_wvalid   (m01_axi_wvalid     ),
    .m01_axi_wready   (m01_axi_wready     ),
    .m01_axi_bresp    (m01_axi_bresp      ),
    .m01_axi_bvalid   (m01_axi_bvalid     ),
    .m01_axi_bready   (m01_axi_bready     ),
    .m01_axi_araddr   (m01_axi_araddr     ),
    .m01_axi_arlen    (m01_axi_arlen      ),
    .m01_axi_arsize   (m01_axi_arsize     ),
    .m01_axi_arburst  (m01_axi_arburst    ),
    .m01_axi_arvalid  (m01_axi_arvalid    ),
    .m01_axi_arready  (m01_axi_arready    ),
    .m01_axi_rdata    (m01_axi_rdata      ),
    .m01_axi_rresp    (m01_axi_rresp      ),
    .m01_axi_rlast    (m01_axi_rlast      ),
    .m01_axi_rvalid   (m01_axi_rvalid     ),
    .m01_axi_rready   (m01_axi_rready     ),

    // implode
  //.m02_axi_awaddr   (                   ),
  //.m02_axi_awlen    (                   ),
  //.m02_axi_awsize   (                   ),
  //.m02_axi_awburst  (                   ),
  //.m02_axi_awvalid  (                   ),
  //.m02_axi_awready  (                   ),
  //.m02_axi_wdata    (                   ),
  //.m02_axi_wstrb    (                   ),
  //.m02_axi_wlast    (                   ),
  //.m02_axi_wvalid   (                   ),
  //.m02_axi_wready   (                   ),
  //.m02_axi_bresp    (                   ),
  //.m02_axi_bvalid   (                   ),
  //.m02_axi_bready   (                   ),
    .m02_axi_araddr   (m02_axi_araddr     ),
    .m02_axi_arlen    (m02_axi_arlen      ),
    .m02_axi_arsize   (m02_axi_arsize     ),
    .m02_axi_arburst  (m02_axi_arburst    ),
    .m02_axi_arvalid  (m02_axi_arvalid    ),
    .m02_axi_arready  (m02_axi_arready    ),
    .m02_axi_rdata    (m02_axi_rdata      ),
    .m02_axi_rresp    (m02_axi_rresp      ),
    .m02_axi_rlast    (m02_axi_rlast      ),
    .m02_axi_rvalid   (m02_axi_rvalid     ),
    .m02_axi_rready   (m02_axi_rready     )
  );

  //////////////////////////////////////////////////////////////////////////////
  // Post Computation

  // wire [state_width-1:0] post_data_raw = 1600'h0E00F4BBFDEAC47F4D4BF29013ADCDFBBDFB860076EA3D618CFF6DA1920C7F8C60146F81DC2DCAF7A642A787F4DDF50C9607D9CC9580131593ED79D243A53AD712D06C89907632245A7C406C8DC2D0D252257E5D19A11624E894916D56E7DBD3D69C475CF4B7C809F8180AC0010DEB38D1F71CBEECBE5773A7217CA31AC91B434284413FBEC193141C3F1BFC9B361C224A8D2FFAAB8CE5D6351D543F6F0DD84F773F038DD54F7D6B115FC3DC15D2103038A8247E51DCB0D3_D5AC2B7D_21082F27_DB7A1B0F_753ADA4F;
  // rev_bytes #(.SIZE(state_width)) rev_result (.in(post_data_raw), .out(post_data));
  // assign post_valid = (post_counter < 1);

  assign post_nonce = post_counter;

  post_CN #(
    .state_width      (state_width        ),
    .nonce_width      (nonce_width        )
  ) inst_post (
    .clk              (clk_slow           ),
    .rst              (~rst_n_c_slow      ),
    .rstn             (rst_n_c_slow       ),
    .i_valid          (post_valid         ),
    .o_ready          (post_ready         ),
    .i_data           (post_data          ),
    .i_nonce          (post_nonce         ),
    //
    .o_result         (out_data           ),
    .o_valid          (out_valid          ),
    .i_ready          (out_ready          )
  );

////////////////////////////////////////////////////////////////////////////////
// Output Processing
////////////////////////////////////////////////////////////////////////////////

  reg [nonce_width-1:0] m00_axi_w_counter = 'b0;
  reg [nonce_width-1:0] m01_axi_w_counter = 'b0;
  reg [nonce_width-1:0] m01_axi_r_counter = 'b0;
  reg [nonce_width-1:0] m02_axi_r_counter = 'b0;

  always @(posedge m00_axi_aclk)
    if (start_pulse_slow)
      m00_axi_w_counter <= 'b0;
    else
      if (m00_axi_wvalid & m00_axi_wready) m00_axi_w_counter <= m00_axi_w_counter + 1; 

  always @(posedge m01_axi_aclk)
    if (start_pulse_fast) begin
      m01_axi_w_counter <= 'b0;
      m01_axi_r_counter <= 'b0;
    end
    else begin
      if (m01_axi_wvalid & m01_axi_wready) m01_axi_w_counter <= m01_axi_w_counter + 1; 
      if (m01_axi_rvalid & m01_axi_rready) m01_axi_r_counter <= m01_axi_r_counter + 1; 
    end

  always @(posedge m02_axi_aclk)
    if (start_pulse_slow)
      m02_axi_r_counter <= 'b0;
    else
      if (m02_axi_rvalid & m02_axi_rready) m02_axi_r_counter <= m02_axi_r_counter + 1; 

  reg [31:0] latency;
  always @(posedge clk_slow)
    if (start_pulse_slow)
      latency <= 'b0;
    else if (latency == 32'b0 && (post_valid & post_ready))
      latency <= cycle_counter[31:0];

  always @(posedge clk_slow) begin
    if (cmd_exit) begin
      csr0_to_sw <= {cn_counter[15:0] , pre_counter[15:0] };
      csr1_to_sw <= {out_counter[15:0], post_counter[15:0]};
      csr2_to_sw <= cycle_counter[31: 0];
      // csr3_to_sw <= cycle_counter[63:32];
      csr3_to_sw <= latency;

      csr4_to_sw <= m00_axi_w_counter;
      csr5_to_sw <= m01_axi_w_counter;
      csr6_to_sw <= m01_axi_r_counter;
      csr7_to_sw <= m02_axi_r_counter;
    end
  end


  always @(posedge clk_slow)
    cmd_exit <= csr0_from_sw[0];
    // cmd_exit <= post_ready & post_valid;

////////////////////////////////////////////////////////////////////////////////
// Printing
////////////////////////////////////////////////////////////////////////////////

  wire [ input_width-1:0] pre_data_rev ;
  wire [ state_width-1:0] CN_data_rev  ;
  wire [ state_width-1:0] post_data_rev;
  wire [output_width-1:0] out_data_rev ;

  rev_bytes #(.SIZE(input_width )) rev_predata  (.in(pre_data ), .out(pre_data_rev ));
  rev_bytes #(.SIZE(state_width )) rev_cndata   (.in(CN_data  ), .out(CN_data_rev  ));
  rev_bytes #(.SIZE(state_width )) rev_postdata (.in(post_data), .out(post_data_rev));
  rev_bytes #(.SIZE(output_width)) rev_outdata  (.in(out_data ), .out(out_data_rev ));

  always @(posedge clk_slow) begin
    if (rst_n_c_slow) begin
      if (pre_valid  & pre_ready  ) $display("In  ->Pre  %h|%h", pre_nonce , pre_data_rev );
      if (CN_valid   & CN_ready   ) $display("Pre ->CN   %h|%h", CN_nonce  , CN_data_rev  );
      if (post_valid & post_ready ) $display("CN  ->Post %h|%h", post_nonce, post_data_rev);
      if (out_valid  & out_ready  ) $display("Post->Out  %h"   ,             out_data_rev );
    end
  end

  always @(posedge m00_axi_aclk) begin
    if (rst_n_c_slow) begin
      if (m00_axi_awvalid & m00_axi_awready) $display("m00_axi_awaddr %h", m00_axi_awaddr);
      if (m00_axi_wvalid  & m00_axi_wready ) $display("m00_axi_wdata  %h", m00_axi_wdata );
    end
  end

  always @(posedge m01_axi_aclk) begin
    if (rst_n_c_fast) begin
      if (m01_axi_awvalid & m01_axi_awready) $display("m01_axi_awaddr %h", m01_axi_awaddr);
      if (m01_axi_wvalid  & m01_axi_wready ) $display("m01_axi_wdata  %h", m01_axi_wdata );
      if (m01_axi_arvalid & m01_axi_arready) $display("m01_axi_araddr %h", m01_axi_araddr);
      if (m01_axi_rvalid  & m01_axi_rready ) $display("m01_axi_rdata  %h", m01_axi_rdata );
    end
  end

  always @(posedge m02_axi_aclk) begin
    if (rst_n_c_slow) begin
      if (m02_axi_arvalid & m02_axi_arready) $display("m02_axi_araddr %h", m02_axi_araddr);
      if (m02_axi_rvalid  & m02_axi_rready ) $display("m02_axi_rdata  %h", m02_axi_rdata );
    end
  end

endmodule
`default_nettype wire
