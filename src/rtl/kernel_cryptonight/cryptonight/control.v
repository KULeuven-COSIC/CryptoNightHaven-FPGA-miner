`timescale 1ns/1ps

// ==============================================================
// Vivado(TM) HLS - High-Level Synthesis from C, C++ and SystemC v2019.2 (64-bit)
// Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
// ==============================================================

module csrs
#(parameter
  C_S_AXI_ADDR_WIDTH = 12,
  C_S_AXI_DATA_WIDTH = 32
)(
  input  wire                             ACLK,
  input  wire                             ARESET,
  input  wire                             ACLK_EN,
  input  wire [C_S_AXI_ADDR_WIDTH-1:0]    AWADDR,
  input  wire                             AWVALID,
  output wire                             AWREADY,
  input  wire [C_S_AXI_DATA_WIDTH-1:0]    WDATA,
  input  wire [C_S_AXI_DATA_WIDTH/8-1:0]  WSTRB,
  input  wire                             WVALID,
  output wire                             WREADY,
  output wire [1:0]                       BRESP,
  output wire                             BVALID,
  input  wire                             BREADY,
  input  wire [C_S_AXI_ADDR_WIDTH-1:0]    ARADDR,
  input  wire                             ARVALID,
  output wire                             ARREADY,
  output wire [C_S_AXI_DATA_WIDTH-1:0]    RDATA,
  output wire [1:0]                       RRESP,
  output wire                             RVALID,
  input  wire                             RREADY,
  output wire                             interrupt,
  output wire                             ap_start,
  input  wire                             ap_done,
  input  wire                             ap_ready,
  input  wire                             ap_idle,
  // 
  output wire [64-1:0]                    hbm_addr,
  input  wire [32-1:0]                    csr0_i,
  output wire [32-1:0]                    csr0_o,
  input  wire [32-1:0]                    csr1_i,
  output wire [32-1:0]                    csr1_o,
  input  wire [32-1:0]                    csr2_i,
  output wire [32-1:0]                    csr2_o,
  input  wire [32-1:0]                    csr3_i,
  output wire [32-1:0]                    csr3_o,
  input  wire [32-1:0]                    csr4_i,
  output wire [32-1:0]                    csr4_o,
  input  wire [32-1:0]                    csr5_i,
  output wire [32-1:0]                    csr5_o,
  input  wire [32-1:0]                    csr6_i,
  output wire [32-1:0]                    csr6_o,
  input  wire [32-1:0]                    csr7_i,
  output wire [32-1:0]                    csr7_o
);
  //------------------------Address Info-------------------
  // 0x00 : Control signals
  //        bit 0  - ap_start (Read/Write/COH)
  //        bit 1  - ap_done (Read/COR)
  //        bit 2  - ap_idle (Read)
  //        bit 3  - ap_ready (Read)
  //        bit 7  - auto_restart (Read/Write)
  //        others - reserved
  //
  // 0x04 : Global Interrupt Enable Register
  //        bit 0  - Global Interrupt Enable (Read/Write)
  //        others - reserved
  //
  // 0x08 : IP Interrupt Enable Register (Read/Write)
  //        bit 0  - Channel 0 (ap_done)
  //        bit 1  - Channel 1 (ap_ready)
  //        others - reserved
  //
  // 0x0c : IP Interrupt Status Register (Read/TOW)
  //        bit 0  - Channel 0 (ap_done)
  //        bit 1  - Channel 1 (ap_ready)
  //        others - reserved

  // SC  = Self Clear
  // COR = Clear on Read
  // TOW = Toggle on Write
  // COH = Clear on Handshake


  //------------------------Parameter----------------------
  localparam
    ADDR_AP_CTRL         = 9'h000,
    ADDR_GIE             = 9'h004,
    ADDR_IER             = 9'h008,
    ADDR_ISR             = 9'h00c,
    // 
    ADDR_HBM_ADDR_L      = 9'h010,
    ADDR_HBM_ADDR_H      = 9'h014,
    ADDR_CSR0            = 9'h018,
    ADDR_CSR1            = 9'h01c,
    ADDR_CSR2            = 9'h020,
    ADDR_CSR3            = 9'h024,
    ADDR_CSR4            = 9'h028,
    ADDR_CSR5            = 9'h02c,
    ADDR_CSR6            = 9'h030,
    ADDR_CSR7            = 9'h034,
    // 
    WRIDLE               = 2'd0,
    WRDATA               = 2'd1,
    WRRESP               = 2'd2,
    WRRESET              = 2'd3,
    RDIDLE               = 2'd0,
    RDDATA               = 2'd1,
    RDRESET              = 2'd2,
    ADDR_BITS            = 9;

  //------------------------Local signal-------------------
  reg  [1:0]           wstate = WRRESET;
  reg  [1:0]           wnext;
  reg  [ADDR_BITS-1:0] waddr;
  wire [31:0]          wmask;
  wire                 aw_hs;
  wire                 w_hs;
  reg  [1:0]           rstate = RDRESET;
  reg  [1:0]           rnext;
  reg  [31:0]          rdata;
  wire                 ar_hs;
  wire [ADDR_BITS-1:0] raddr;

  wire                 int_ap_idle;
  wire                 int_ap_ready;
  wire                 int_ap_done;

  // internal registers
  reg                  int_ap_done_q = 1'b0;
  reg                  int_ap_start = 1'b0;
  reg                  int_auto_restart = 1'b0;
  reg                  int_gie = 1'b0;
  reg  [ 1:0]          int_ier = 2'b0;
  reg  [ 1:0]          int_isr = 2'b0;
  // 
  reg  [63:0]          int_hbm_addr = 'b0;
  reg  [31:0]          int_csr0     = 'b0;
  reg  [31:0]          int_csr1     = 'b0;
  reg  [31:0]          int_csr2     = 'b0;
  reg  [31:0]          int_csr3     = 'b0;
  reg  [31:0]          int_csr4     = 'b0;
  reg  [31:0]          int_csr5     = 'b0;
  reg  [31:0]          int_csr6     = 'b0;
  reg  [31:0]          int_csr7     = 'b0;

  //------------------------Instantiation------------------

  //------------------------AXI write fsm------------------
  assign AWREADY = (wstate == WRIDLE);
  assign WREADY  = (wstate == WRDATA);
  assign BRESP   = 2'b00;  // OKAY
  assign BVALID  = (wstate == WRRESP);
  assign wmask   = {{8{WSTRB[3]}}, {8{WSTRB[2]}}, {8{WSTRB[1]}}, {8{WSTRB[0]}}};
  assign aw_hs   = AWVALID & AWREADY;
  assign w_hs    = WVALID & WREADY;

  // wstate
  always @(posedge ACLK) begin
    if (ARESET)
      wstate <= WRRESET;
    else if (ACLK_EN)
      wstate <= wnext;
  end

  // wnext
  always @(*) begin
    case (wstate)
      WRIDLE:
        if (AWVALID)
          wnext = WRDATA;
        else
          wnext = WRIDLE;
      WRDATA:
        if (WVALID)
          wnext = WRRESP;
        else
          wnext = WRDATA;
      WRRESP:
        if (BREADY)
          wnext = WRIDLE;
        else
          wnext = WRRESP;
      default:
        wnext = WRIDLE;
    endcase
  end

  // waddr
  always @(posedge ACLK) begin
    if (ACLK_EN) begin
      if (aw_hs)
        waddr <= AWADDR[ADDR_BITS-1:0];
    end
  end

  //------------------------AXI read fsm-------------------
  assign ARREADY = (rstate == RDIDLE);
  assign RDATA   = rdata;
  assign RRESP   = 2'b00;  // OKAY
  assign RVALID  = (rstate == RDDATA);
  assign ar_hs   = ARVALID & ARREADY;
  assign raddr   = ARADDR[ADDR_BITS-1:0];

  // rstate
  always @(posedge ACLK) begin
    if (ARESET)
      rstate <= RDRESET;
    else if (ACLK_EN)
      rstate <= rnext;
  end

  // rnext
  always @(*) begin
    case (rstate)
      RDIDLE:
        if (ARVALID)
          rnext = RDDATA;
        else
          rnext = RDIDLE;
      RDDATA:
        if (RREADY & RVALID)
          rnext = RDIDLE;
        else
          rnext = RDDATA;
      default:
        rnext = RDIDLE;
    endcase
  end

  // rdata
  always @(posedge ACLK) begin
    if (ACLK_EN) begin
      if (ar_hs) begin
        rdata <= 1'b0;
        case (raddr)
          ADDR_AP_CTRL: begin
            rdata[0] <= int_ap_start;
            rdata[1] <= int_ap_done;
            rdata[2] <= int_ap_idle;
            rdata[3] <= int_ap_ready;
            rdata[7] <= int_auto_restart;
            end
          ADDR_GIE          : rdata <= int_gie;
          ADDR_IER          : rdata <= int_ier;
          ADDR_ISR          : rdata <= int_isr;
          // 
          ADDR_HBM_ADDR_L   : rdata <= int_hbm_addr[31: 0];
          ADDR_HBM_ADDR_H   : rdata <= int_hbm_addr[63:32];
          ADDR_CSR0         : rdata <= csr0_i;
          ADDR_CSR1         : rdata <= csr1_i;
          ADDR_CSR2         : rdata <= csr2_i;
          ADDR_CSR3         : rdata <= csr3_i;
          ADDR_CSR4         : rdata <= csr4_i;
          ADDR_CSR5         : rdata <= csr5_i;
          ADDR_CSR6         : rdata <= csr6_i;
          ADDR_CSR7         : rdata <= csr7_i;
        endcase
      end
    end
  end

  //------------------------Register logic-----------------

  assign interrupt     = int_gie & (|int_isr);
  assign ap_start      = int_ap_start;

  // int_ap_start
  always @(posedge ACLK) begin
    if (ARESET)
      int_ap_start <= 1'b0;
    else if (ACLK_EN) begin
      if (w_hs && waddr == ADDR_AP_CTRL && WSTRB[0] && WDATA[0]) begin
        int_ap_start <= 1'b1;
        $display("ap_start");
      end
      else if (ap_ready)
        int_ap_start <= int_auto_restart; // clear on handshake/auto restart
    end
  end

  assign int_ap_done = ap_done | int_ap_done_q;
  // int_ap_done_q
  always @(posedge ACLK) begin
    if (ARESET)
      int_ap_done_q <= 1'b0;
    else if (ACLK_EN) begin
      if (ap_done) begin
        int_ap_done_q <= 1'b1;
        $display("ap_done");
      end
      else if (ar_hs && raddr == ADDR_AP_CTRL)
        int_ap_done_q <= 1'b0; // clear on read
    end
  end

  assign int_ap_idle = ap_idle;

  assign int_ap_ready = ap_ready;

  // int_auto_restart
  always @(posedge ACLK) begin
    if (ARESET)
      int_auto_restart <= 1'b0;
    else if (ACLK_EN) begin
      if (w_hs && waddr == ADDR_AP_CTRL && WSTRB[0])
        int_auto_restart <=  WDATA[7];
    end
  end

  // int_gie
  always @(posedge ACLK) begin
    if (ARESET)
      int_gie <= 1'b0;
    else if (ACLK_EN) begin
      if (w_hs && waddr == ADDR_GIE && WSTRB[0])
        int_gie <= WDATA[0];
    end
  end

  // int_ier
  always @(posedge ACLK) begin
    if (ARESET)
      int_ier <= 1'b0;
    else if (ACLK_EN) begin
      if (w_hs && waddr == ADDR_IER && WSTRB[0])
        int_ier <= WDATA[1:0];
    end
  end

  // int_isr[0]
  always @(posedge ACLK) begin
    if (ARESET)
      int_isr[0] <= 1'b0;
    else if (ACLK_EN) begin
      if (int_ier[0] & ap_done)
        int_isr[0] <= 1'b1;
      else if (w_hs && waddr == ADDR_ISR && WSTRB[0])
        int_isr[0] <= int_isr[0] ^ WDATA[0]; // toggle on write
    end
  end

  // int_isr[1]
  always @(posedge ACLK) begin
    if (ARESET)
      int_isr[1] <= 1'b0;
    else if (ACLK_EN) begin
      if (int_ier[1] & ap_ready)
        int_isr[1] <= 1'b1;
      else if (w_hs && waddr == ADDR_ISR && WSTRB[0])
        int_isr[1] <= int_isr[1] ^ WDATA[1]; // toggle on write
    end
  end

  // int_hbm_addr
  always @(posedge ACLK) 
    if (ARESET) begin
      int_hbm_addr <= 'b0;
    end
    else if (ACLK_EN) begin
      if (w_hs && waddr == ADDR_HBM_ADDR_L) int_hbm_addr[31: 0] <= (WDATA & wmask) | (int_hbm_addr[31: 0] & ~wmask);
      if (w_hs && waddr == ADDR_HBM_ADDR_H) int_hbm_addr[63:32] <= (WDATA & wmask) | (int_hbm_addr[63:32] & ~wmask);
    end
  assign hbm_addr = int_hbm_addr;


  // int_csr*
  always @(posedge ACLK) 
    if (ARESET) begin
      int_csr0 <= 'b0;
      int_csr1 <= 'b0;
      int_csr2 <= 'b0;
      int_csr3 <= 'b0;
      int_csr4 <= 'b0;
      int_csr5 <= 'b0;
      int_csr6 <= 'b0;
      int_csr7 <= 'b0;
    end
    else if (ACLK_EN) begin
      if (w_hs && waddr == ADDR_CSR0) int_csr0 <= (WDATA & wmask) | (int_csr0 & ~wmask);
      if (w_hs && waddr == ADDR_CSR1) int_csr1 <= (WDATA & wmask) | (int_csr1 & ~wmask);
      if (w_hs && waddr == ADDR_CSR2) int_csr2 <= (WDATA & wmask) | (int_csr2 & ~wmask);
      if (w_hs && waddr == ADDR_CSR3) int_csr3 <= (WDATA & wmask) | (int_csr3 & ~wmask);
      if (w_hs && waddr == ADDR_CSR4) int_csr4 <= (WDATA & wmask) | (int_csr4 & ~wmask);
      if (w_hs && waddr == ADDR_CSR5) int_csr5 <= (WDATA & wmask) | (int_csr5 & ~wmask);
      if (w_hs && waddr == ADDR_CSR6) int_csr6 <= (WDATA & wmask) | (int_csr6 & ~wmask);
      if (w_hs && waddr == ADDR_CSR7) int_csr7 <= (WDATA & wmask) | (int_csr7 & ~wmask);
    end

  assign csr0_o = int_csr0;
  assign csr1_o = int_csr1;
  assign csr2_o = int_csr2;
  assign csr3_o = int_csr3;
  assign csr4_o = int_csr4;
  assign csr5_o = int_csr5;
  assign csr6_o = int_csr6;
  assign csr7_o = int_csr7;
  
//------------------------Memory logic-------------------

endmodule