`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/09/2021 11:57:16 AM
// Design Name: 
// Module Name: shuffle_piped_datapath
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


module shuffle_piped_datapath #(
    parameter FIFO_READ_LATENCY = 1,
    parameter CN_XHV=0,
    parameter addr_width = 18,
    parameter nonce_width = 7,
    parameter AES_latency = 1 + (FIFO_READ_LATENCY-1),
    parameter multadd_latency = 24 + (FIFO_READ_LATENCY-1),
    parameter div_latency = 68,
    parameter buffer_depth = 128
)
    (
        input clk, // clock
        input rst, // active low reset
        input [127:0] i_state, // state input for starting iteration
        input [nonce_width-1:0] i_state_nonce, // nonce corresponding to input state

        // controller signals 
        input i_load_state_reg, // load input registers
        input i_r1_addr_mux_select, // mux for determining r1_addr
        input i_a_mux_select, // mux for determining a in AES
        input i_b_mux_select, // mux for determining b in XOR with c
        input i_dividend_valid, // inputs for div core
        input i_divisor_valid, // inputs for div core

        // FIFO signals
        input i_a2_buffer_pop,
        input i_a2_buffer_push,
        input i_a3_buffer_pop,
        input i_a3_buffer_push,
        input i_a4_buffer_pop,
        input i_a4_buffer_push,
        input i_c1_buffer_pop,
        input i_c1_buffer_push,
        input i_c2_buffer_pop,
        input i_c2_buffer_push,
        input i_r1_addr_buffer_pop,
        input i_r1_addr_buffer_push,
        input i_r1_nonce_buffer_pop,
        input i_r1_nonce_buffer_push,
        input i_r2_nonce_buffer_pop,
        input i_r2_nonce_buffer_push,
        input i_r3_nonce_buffer_pop,
        input i_r3_nonce_buffer_push,

        // memory interfacing
        output [31:0] o_r1_addr,
        input [127:0] i_r1_data,
        output [31:0] o_w1_addr,
        output [127:0] o_w1_data,

        output [31:0] o_r2_addr,
        input [127:0] i_r2_data,
        output [31:0] o_w2_addr,
        output [127:0] o_w2_data,

        output [31:0] o_r3_addr,
        input [127:0] i_r3_data,
        output [31:0] o_w3_addr,
        output [127:0] o_w3_data,

        // release nonce after execution
        input i_nonce_pop,
        output [nonce_width-1:0] o_nonce
    );

        // parameters
    integer i; // iteration variable

    // instantiation of operator modules

    wire [127:0] AES_result, AES_in, AES_key;
    /* rev_col rev_in (.in(AES_in), .out(rev_AES_in)); */
    /* rev_col rev_key (.in(AES_key), .out(rev_AES_key)); */
    /* rev_col rev_out (.in(rev_AES_result), .out(AES_result)); */
    shuffle_aes AES(.clk(clk), .in(AES_in), .key(AES_key), .out(AES_result));

    wire [63:0] multadder_a, multadder_b;
    wire [127:0] multadder_c, multadder_p, multadder_p_switched;
    multadd_proper multadder(
        .clk(clk),
        .rst(rst),
        .a(multadder_a),
        .b(multadder_b),
        .c(multadder_c),
        .p(multadder_p_switched)
    );
    assign multadder_p = {multadder_p_switched[63:0], multadder_p_switched[127:64]};

    wire [63:0] div_dividend, div_quotient;
    wire [31:0] div_divisor, div_remainder;
    wire div_dividend_valid, div_divisor_valid, div_quotient_valid;
    div_gen_0 divider (
        .aclk(clk),                                  // input wire aclk
        .s_axis_divisor_tvalid(div_divisor_valid),   // input wire s_axis_divisor_tvalid
        .s_axis_divisor_tdata(div_divisor),          // input wire [31 : 0] s_axis_divisor_tdata
        .s_axis_dividend_tvalid(div_dividend_valid), // input wire s_axis_dividend_tvalid
        .s_axis_dividend_tdata(div_dividend),        // input wire [63 : 0] s_axis_dividend_tdata
        .m_axis_dout_tvalid(div_quotient_valid),     // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata({div_quotient, div_remainder})             // output wire [95 : 0] m_axis_dout_tdata
    );

    // instantiation of memory elements and buffers

    // input select (for starting algo)
    reg in_mux_select [3:0];
    reg load_state_reg [3:0];

    // ax buffers
    // The ax chain is as follows (starting from ax0 and ax1, ignoring ax0_next...):
    //
    //    this part separate from main loop
    // ---------------------------------------
    // ax0, ax1 -> ax0 gives r1_addr -> wait -> ax gives AES key -> ax0 gives
    // ---------------------------------------
    // w1_addr -> FIFO ax2_buffer -> ax gives multadd input -> multadd output
    // XOR r2_data becomes the new ax with intermediate reg -> FIFO ax3_buffer
    // -> ax3 gives w3_addr -> FIFO ax4_buffer -> ax gives AES key (iterate)
    reg [63:0] ax0, ax1;

    // these buffers start at 2 for historical reasons
    wire a2_buffer_push, a2_buffer_pop, a2_buffer_full, a2_buffer_empty;
    wire [127:0] a2_in, a2_out;

    xpm_fifo_sync #(
        .CASCADE_HEIGHT(0),        // DECIMAL
        .DOUT_RESET_VALUE("0"),    // String
        .ECC_MODE("no_ecc"),       // String
        .FIFO_MEMORY_TYPE("auto"), // String
        .FIFO_READ_LATENCY(FIFO_READ_LATENCY),     // DECIMAL
        .FIFO_WRITE_DEPTH(buffer_depth),     // DECIMAL
        .FULL_RESET_VALUE(0),      // DECIMAL
        .PROG_EMPTY_THRESH(10),    // DECIMAL
        .PROG_FULL_THRESH(10),     // DECIMAL
        .RD_DATA_COUNT_WIDTH(5),   // DECIMAL
        .READ_DATA_WIDTH(128),     // DECIMAL
        .READ_MODE("std"),         // String
        .SIM_ASSERT_CHK(1),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES("0000"), // String
        .WAKEUP_TIME(0),           // DECIMAL
        .WRITE_DATA_WIDTH(128),    // DECIMAL
        .WR_DATA_COUNT_WIDTH(5)    // DECIMAL
    )
    a2_buffer (
        .wr_clk(clk),      // input wire clk
        .rst(rst),    // input wire rst
        .din(a2_in),      // input wire [127 : 0] din
        .wr_en(a2_buffer_push),  // input wire wr_en
        .rd_en(a2_buffer_pop),  // input wire rd_en
        .dout(a2_out),    // output wire [127 : 0] dout
        .full(a2_buffer_full),    // output wire full
        .empty(a2_buffer_empty)  // output wire empty
    );

    reg [127:0] a3_reg;
    wire a3_buffer_push, a3_buffer_pop, a3_buffer_full, a3_buffer_empty;
    wire [127:0] a3_in, a3_out;
    xpm_fifo_sync #(
        .CASCADE_HEIGHT(0),        // DECIMAL
        .DOUT_RESET_VALUE("0"),    // String
        .ECC_MODE("no_ecc"),       // String
        .FIFO_MEMORY_TYPE("auto"), // String
        .FIFO_READ_LATENCY(FIFO_READ_LATENCY),     // DECIMAL
        .FIFO_WRITE_DEPTH(buffer_depth),     // DECIMAL
        .FULL_RESET_VALUE(0),      // DECIMAL
        .PROG_EMPTY_THRESH(10),    // DECIMAL
        .PROG_FULL_THRESH(10),     // DECIMAL
        .RD_DATA_COUNT_WIDTH(5),   // DECIMAL
        .READ_DATA_WIDTH(128),     // DECIMAL
        .READ_MODE("std"),         // String
        .SIM_ASSERT_CHK(1),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES("0000"), // String
        .WAKEUP_TIME(0),           // DECIMAL
        .WRITE_DATA_WIDTH(128),    // DECIMAL
        .WR_DATA_COUNT_WIDTH(5)    // DECIMAL
    )
    a3_buffer(
        .wr_clk(clk),      // input wire clk
        .rst(rst),    // input wire rst
        .din(a3_in),      // input wire [127 : 0] din
        .wr_en(a3_buffer_push),  // input wire wr_en
        .rd_en(a3_buffer_pop),  // input wire rd_en
        .dout(a3_out),    // output wire [127 : 0] dout
        .full(a3_buffer_full),    // output wire full
        .empty(a3_buffer_empty)  // output wire empty
    );

    wire a4_buffer_push, a4_buffer_pop, a4_buffer_full, a4_buffer_empty;
    wire [127:0] a4_in, a4_out;
    xpm_fifo_sync #(
        .CASCADE_HEIGHT(0),        // DECIMAL
        .DOUT_RESET_VALUE("0"),    // String
        .ECC_MODE("no_ecc"),       // String
        .FIFO_MEMORY_TYPE("auto"), // String
        .FIFO_READ_LATENCY(FIFO_READ_LATENCY),     // DECIMAL
        .FIFO_WRITE_DEPTH(buffer_depth),     // DECIMAL
        .FULL_RESET_VALUE(0),      // DECIMAL
        .PROG_EMPTY_THRESH(10),    // DECIMAL
        .PROG_FULL_THRESH(10),     // DECIMAL
        .RD_DATA_COUNT_WIDTH(5),   // DECIMAL
        .READ_DATA_WIDTH(128),     // DECIMAL
        .READ_MODE("std"),         // String
        .SIM_ASSERT_CHK(1),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES("0000"), // String
        .WAKEUP_TIME(0),           // DECIMAL
        .WRITE_DATA_WIDTH(128),    // DECIMAL
        .WR_DATA_COUNT_WIDTH(5)    // DECIMAL
    )
    a4_buffer(
        .wr_clk(clk),      // input wire clk
        .rst(rst),    // input wire rst
        .din(a4_in),      // input wire [127 : 0] din
        .wr_en(a4_buffer_push),  // input wire wr_en
        .rd_en(a4_buffer_pop),  // input wire rd_en
        .dout(a4_out),    // output wire [127 : 0] dout
        .full(a4_buffer_full),    // output wire full
        .empty(a4_buffer_empty)  // output wire empty
    );

    // bx buffers
    // these are only used when a new state is read
    reg [63:0] bx0, bx1;

    // cx buffers
    // cx is necessary at multiple steps such that the chain is complex
    //
    // AES_result -> cx -> FIFO cx_buffer -> cx is read as r2_addr -> fixed latency
    // chain (during multadd) -> cx is read as w2_addr -> FIFO c2_buffer ->
    // cx now becomes bx in the next iteration
    reg [127:0] cx;

    wire c1_buffer_pop, c1_buffer_push, c1_buffer_full, c1_buffer_empty;
    wire [127:0] c1_in, c1_out;
    xpm_fifo_sync #(
        .CASCADE_HEIGHT(0),        // DECIMAL
        .DOUT_RESET_VALUE("0"),    // String
        .ECC_MODE("no_ecc"),       // String
        .FIFO_MEMORY_TYPE("auto"), // String
        .FIFO_READ_LATENCY(FIFO_READ_LATENCY),     // DECIMAL
        .FIFO_WRITE_DEPTH(buffer_depth),     // DECIMAL
        .FULL_RESET_VALUE(0),      // DECIMAL
        .PROG_EMPTY_THRESH(10),    // DECIMAL
        .PROG_FULL_THRESH(10),     // DECIMAL
        .RD_DATA_COUNT_WIDTH(5),   // DECIMAL
        .READ_DATA_WIDTH(128),     // DECIMAL
        .READ_MODE("std"),         // String
        .SIM_ASSERT_CHK(1),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES("0000"), // String
        .WAKEUP_TIME(0),           // DECIMAL
        .WRITE_DATA_WIDTH(128),    // DECIMAL
        .WR_DATA_COUNT_WIDTH(5)    // DECIMAL
    )
    c1_buffer(
        .wr_clk(clk),      // input wire clk
        .rst(rst),    // input wire rst
        .din(c1_in),      // input wire [127 : 0] din
        .wr_en(c1_buffer_push),  // input wire wr_en
        .rd_en(c1_buffer_pop),  // input wire rd_en
        .dout(c1_out),    // output wire [127 : 0] dout
        .full(c1_buffer_full),    // output wire full
        .empty(c1_buffer_empty)  // output wire empty
    );

    reg [127:0] c_fixed_latency [multadd_latency-FIFO_READ_LATENCY+1:0];

    wire c2_buffer_pop, c2_buffer_push, c2_buffer_full, c2_buffer_empty;
    wire [127:0] c2_in, c2_out;
    xpm_fifo_sync #(
        .CASCADE_HEIGHT(0),        // DECIMAL
        .DOUT_RESET_VALUE("0"),    // String
        .ECC_MODE("no_ecc"),       // String
        .FIFO_MEMORY_TYPE("auto"), // String
        .FIFO_READ_LATENCY(FIFO_READ_LATENCY),     // DECIMAL
        .FIFO_WRITE_DEPTH(buffer_depth),     // DECIMAL
        .FULL_RESET_VALUE(0),      // DECIMAL
        .PROG_EMPTY_THRESH(10),    // DECIMAL
        .PROG_FULL_THRESH(10),     // DECIMAL
        .RD_DATA_COUNT_WIDTH(5),   // DECIMAL
        .READ_DATA_WIDTH(128),     // DECIMAL
        .READ_MODE("std"),         // String
        .SIM_ASSERT_CHK(1),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES("0000"), // String
        .WAKEUP_TIME(0),           // DECIMAL
        .WRITE_DATA_WIDTH(128),    // DECIMAL
        .WR_DATA_COUNT_WIDTH(5)    // DECIMAL
    )
    c2_buffer(
        .wr_clk(clk),      // input wire clk
        .rst(rst),    // input wire rst
        .din(c2_in),      // input wire [127 : 0] din
        .wr_en(c2_buffer_push),  // input wire wr_en
        .rd_en(c2_buffer_pop),  // input wire rd_en
        .dout(c2_out),    // output wire [127 : 0] dout
        .full(c2_buffer_full),    // output wire full
        .empty(c2_buffer_empty)  // output wire empty
    );

    // r1_data buffer
    wire r1_addr_buffer_push, r1_addr_buffer_pop, r1_addr_buffer_full,
    r1_addr_buffer_empty;
    wire [31:0] r1_addr_in, r1_addr_out;
    xpm_fifo_sync #(
        .CASCADE_HEIGHT(0),        // DECIMAL
        .DOUT_RESET_VALUE("0"),    // String
        .ECC_MODE("no_ecc"),       // String
        .FIFO_MEMORY_TYPE("auto"), // String
        .FIFO_READ_LATENCY(FIFO_READ_LATENCY),     // DECIMAL
        .FIFO_WRITE_DEPTH(buffer_depth),     // DECIMAL
        .FULL_RESET_VALUE(0),      // DECIMAL
        .PROG_EMPTY_THRESH(10),    // DECIMAL
        .PROG_FULL_THRESH(10),     // DECIMAL
        .RD_DATA_COUNT_WIDTH(5),   // DECIMAL
        .READ_DATA_WIDTH(32),     // DECIMAL
        .READ_MODE("std"),         // String
        .SIM_ASSERT_CHK(1),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES("0000"), // String
        .WAKEUP_TIME(0),           // DECIMAL
        .WRITE_DATA_WIDTH(32),    // DECIMAL
        .WR_DATA_COUNT_WIDTH(5)    // DECIMAL
    )
    r1_address_buffer(
        .wr_clk(clk),
        .rst(rst),
        .din(r1_addr_in),
        .wr_en(r1_addr_buffer_push),
        .rd_en(r1_addr_buffer_pop),
        .dout(r1_addr_out),
        .full(r1_addr_buffer_full),
        .empty(r1_addr_buffer_empty)
    );

    // state nonce buffer
    reg [nonce_width-1:0] state_nonce;

    // r1_nonce buffer
    wire [nonce_width-1:0] r1_nonce_buffer_out, r1_nonce_buffer_in, r1_nonce;
    wire r1_nonce_buffer_pop, r1_nonce_buffer_push, r1_nonce_buffer_full, r1_nonce_buffer_empty;
    xpm_fifo_sync #(
        .CASCADE_HEIGHT(0),        // DECIMAL
        .DOUT_RESET_VALUE("0"),    // String
        .ECC_MODE("no_ecc"),       // String
        .FIFO_MEMORY_TYPE("auto"), // String
        .FIFO_READ_LATENCY(FIFO_READ_LATENCY),     // DECIMAL
        .FIFO_WRITE_DEPTH(buffer_depth),     // DECIMAL
        .FULL_RESET_VALUE(0),      // DECIMAL
        .PROG_EMPTY_THRESH(10),    // DECIMAL
        .PROG_FULL_THRESH(10),     // DECIMAL
        .RD_DATA_COUNT_WIDTH(5),   // DECIMAL
        .READ_DATA_WIDTH(nonce_width),      // DECIMAL
        .READ_MODE("std"),         // String
        .SIM_ASSERT_CHK(1),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES("0000"), // String
        .WAKEUP_TIME(0),           // DECIMAL
        .WRITE_DATA_WIDTH(nonce_width),     // DECIMAL
        .WR_DATA_COUNT_WIDTH(5)    // DECIMAL
    )
    r1_nonce_buffer (
        .dout(r1_nonce_buffer_out),    // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
        // when reading the FIFO.

        .empty(r1_nonce_buffer_empty), // 1-bit output: Empty Flag: When asserted, this signal indicates that the
        // FIFO is empty. Read requests are ignored when the FIFO is empty,
        // initiating a read while empty is not destructive to the FIFO.

        .full(r1_nonce_buffer_full),   // 1-bit output: Full Flag: When asserted, this signal indicates that the
        // FIFO is full. Write requests are ignored when the FIFO is full,
        // initiating a write when the FIFO is full is not destructive to the
        // contents of the FIFO.

        .din(r1_nonce_buffer_in),      // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
        // writing the FIFO.

        .rd_en(r1_nonce_buffer_pop),   // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
        // signal causes data (on dout) to be read from the FIFO. Must be held
        // active-low when rd_rst_busy is active high.

        .rst(rst),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
        // unstable at the time of applying reset, but reset must be released only
        // after the clock(s) is/are stable.
        .wr_clk(clk),                  // 1-bit input: Write clock: Used for write operation. wr_clk must be a
        // free running clock.

        .wr_en(r1_nonce_buffer_push)   // 1-bit input: Write Enable: If the FIFO is not full, asserting this
        // signal causes data (on din) to be written to the FIFO Must be held
        // active-low when rst or wr_rst_busy or rd_rst_busy is active high
    );

    // w1_nonce
    reg [31:0] w1_nonce;

    // r2_data buffers
    // note: in the C++ code this signifies ch and cl
    // r2 is only required for (and one clock period after) the multadd
    // operation, thus only registers are required

    reg [127:0] r2_data[multadd_latency:0];

    // r2_nonce buffer
    wire [nonce_width-1:0] r2_nonce_buffer_out, r2_nonce_buffer_in;
    wire r2_nonce_buffer_pop, r2_nonce_buffer_push, r2_nonce_buffer_full, r2_nonce_buffer_empty;
    xpm_fifo_sync #(
        .CASCADE_HEIGHT(0),        // DECIMAL
        .DOUT_RESET_VALUE("0"),    // String
        .ECC_MODE("no_ecc"),       // String
        .FIFO_MEMORY_TYPE("auto"), // String
        .FIFO_READ_LATENCY(FIFO_READ_LATENCY),     // DECIMAL
        .FIFO_WRITE_DEPTH(buffer_depth),     // DECIMAL
        .FULL_RESET_VALUE(0),      // DECIMAL
        .PROG_EMPTY_THRESH(10),    // DECIMAL
        .PROG_FULL_THRESH(10),     // DECIMAL
        .RD_DATA_COUNT_WIDTH(5),   // DECIMAL
        .READ_DATA_WIDTH(nonce_width),      // DECIMAL
        .READ_MODE("std"),         // String
        .SIM_ASSERT_CHK(1),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES("0000"), // String
        .WAKEUP_TIME(0),           // DECIMAL
        .WRITE_DATA_WIDTH(nonce_width),     // DECIMAL
        .WR_DATA_COUNT_WIDTH(5)    // DECIMAL
    )
    r2_nonce_buffer (
        .dout(r2_nonce_buffer_out),    // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
        // when reading the FIFO.

        .empty(r2_nonce_buffer_empty), // 1-bit output: Empty Flag: When asserted, this signal indicates that the
        // FIFO is empty. Read requests are ignored when the FIFO is empty,
        // initiating a read while empty is not destructive to the FIFO.

        .full(r2_nonce_buffer_full),   // 1-bit output: Full Flag: When asserted, this signal indicates that the
        // FIFO is full. Write requests are ignored when the FIFO is full,
        // initiating a write when the FIFO is full is not destructive to the
        // contents of the FIFO.

        .din(r2_nonce_buffer_in),      // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
        // writing the FIFO.

        .rd_en(r2_nonce_buffer_pop),   // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
        // signal causes data (on dout) to be read from the FIFO. Must be held
        // active-low when rd_rst_busy is active high.

        .rst(rst),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
        // unstable at the time of applying reset, but reset must be released only
        // after the clock(s) is/are stable.
        .wr_clk(clk),                  // 1-bit input: Write clock: Used for write operation. wr_clk must be a
        // free running clock.

        .wr_en(r2_nonce_buffer_push)   // 1-bit input: Write Enable: If the FIFO is not full, asserting this
        // signal causes data (on din) to be written to the FIFO Must be held
        // active-low when rst or wr_rst_busy or rd_rst_busy is active high

    );


    // n, d data buffers
    // these are only required during and after division thus only
    // registers required

    wire [63:0] n [div_latency:0];
    wire [31:0] d [div_latency:0];

    // rw_data and address buffers
    reg [127:0] r1_data[AES_latency:0], r3_data[div_latency:0];
    wire [31:0] r1_addr, r2_addr, r3_addr;
    reg [31:0] r1_addr_reg; // because of necessary extra calculations
    reg [127:0] w1_data, w2_data, w3_data;
    wire [31:0] w1_addr, w2_addr, w3_addr;
    reg [31:0] w1_addr_reg [AES_latency-FIFO_READ_LATENCY+1:0]; 

    // r3_nonce buffer
    wire [nonce_width-1:0] r3_nonce_buffer_out, r3_nonce_buffer_in;
    wire r3_nonce_buffer_pop, r3_nonce_buffer_push, r3_nonce_buffer_full, r3_nonce_buffer_empty;
    xpm_fifo_sync #(
        .CASCADE_HEIGHT(0),        // DECIMAL
        .DOUT_RESET_VALUE("0"),    // String
        .ECC_MODE("no_ecc"),       // String
        .FIFO_MEMORY_TYPE("auto"), // String
        .FIFO_READ_LATENCY(FIFO_READ_LATENCY),     // DECIMAL
        .FIFO_WRITE_DEPTH(buffer_depth),     // DECIMAL
        .FULL_RESET_VALUE(0),      // DECIMAL
        .PROG_EMPTY_THRESH(10),    // DECIMAL
        .PROG_FULL_THRESH(10),     // DECIMAL
        .RD_DATA_COUNT_WIDTH(5),   // DECIMAL
        .READ_DATA_WIDTH(nonce_width),      // DECIMAL
        .READ_MODE("std"),         // String
        .SIM_ASSERT_CHK(1),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES("0000"), // String
        .WAKEUP_TIME(0),           // DECIMAL
        .WRITE_DATA_WIDTH(nonce_width),     // DECIMAL
        .WR_DATA_COUNT_WIDTH(5)    // DECIMAL
    )
    r3_nonce_buffer (
        .dout(r3_nonce_buffer_out),    // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
        // when reading the FIFO.

        .empty(r3_nonce_buffer_empty), // 1-bit output: Empty Flag: When asserted, this signal indicates that the
        // FIFO is empty. Read requests are ignored when the FIFO is empty,
        // initiating a read while empty is not destructive to the FIFO.

        .full(r3_nonce_buffer_full),   // 1-bit output: Full Flag: When asserted, this signal indicates that the
        // FIFO is full. Write requests are ignored when the FIFO is full,
        // initiating a write when the FIFO is full is not destructive to the
        // contents of the FIFO.

        .din(r3_nonce_buffer_in),      // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
        // writing the FIFO.

        .rd_en(r3_nonce_buffer_pop),   // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
        // signal causes data (on dout) to be read from the FIFO. Must be held
        // active-low when rd_rst_busy is active high.

        .rst(rst),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
        // unstable at the time of applying reset, but reset must be released only
        // after the clock(s) is/are stable.
        .wr_clk(clk),                  // 1-bit input: Write clock: Used for write operation. wr_clk must be a
        // free running clock.

        .wr_en(r3_nonce_buffer_push)   // 1-bit input: Write Enable: If the FIFO is not full, asserting this
        // signal causes data (on din) to be written to the FIFO Must be held
        // active-low when rst or wr_rst_busy or rd_rst_busy is active high

    );


    // state input buffer
    reg [127:0] state;

    ////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////

    // module, register and wire connections
    // state nonce
    always @(posedge clk)
        if (rst)
            state_nonce <= 0;
        else if (i_load_state_reg)
            state_nonce <= i_state_nonce;

    // ax
    always @(posedge clk)
        if (rst) begin
            ax0 <= 0;
            ax1 <= 0;
        end
        else if (load_state_reg[0]) begin
            ax0 <= state[127:64] ^ state[63:0]; 
        end
        else if (load_state_reg[1])
            ax1 <= state[127:64] ^ state[63:0]; 

    assign a2_in = i_a_mux_select ? {ax1, ax0} : a4_out;

    always @(posedge clk)
        if (rst)
            a3_reg <= 0;
        else
            a3_reg <= r2_data[multadd_latency] ^ multadder_p;

    assign a3_in = a3_reg;
    assign a4_in = a3_out;

    // bx
    always @(posedge clk)
        if (rst) begin
            bx0 <= 0;
            bx1 <= 0;
        end
        else if (load_state_reg[2])
            bx0 <= state[127:64] ^ state[63:0]; 
        else if (load_state_reg[3])
            bx1 <= state[127:64] ^ state[63:0]; 

    // cx
    always @(posedge clk)
        if (rst)
            cx <= 0;
        else
            cx <= AES_result;
    assign c1_in = cx;
    assign r2_addr = cx[31:0];
    assign o_r2_addr = {{32-addr_width-nonce_width-4{1'b0}}, r2_nonce_buffer_out[nonce_width-1:0], r2_addr[addr_width+3:4], {4{1'b0}}};

    always @(posedge clk)
        if (rst)
            for (i=0; i <= multadd_latency-FIFO_READ_LATENCY+1; i = i + 1) 
                c_fixed_latency[i] <= 0;
        else begin
            c_fixed_latency[0] <= c1_out;
            for (i=1; i <= multadd_latency-FIFO_READ_LATENCY+1; i = i + 1) 
                c_fixed_latency[i] <= c_fixed_latency[i-1];
        end
    assign c2_in = c_fixed_latency[multadd_latency-FIFO_READ_LATENCY+1];
    assign w2_addr = c_fixed_latency[multadd_latency-FIFO_READ_LATENCY+1];
    assign o_w2_addr = {{32-addr_width-nonce_width-4{1'b0}}, r3_nonce_buffer_out[nonce_width-1:0], w2_addr[addr_width+3:4], {4{1'b0}}};

    // r1_data
    always @(posedge clk)
        if (rst) begin
            for (i = 0; i <= AES_latency; i = i + 1)
                r1_data[i] <= 0;
        end
        else begin
            r1_data[0] <= i_r1_data;
            for (i = 1; i <= AES_latency; i = i + 1)
                r1_data[i] <= r1_data[i-1];
        end

    // r1_nonce
    assign r1_nonce_buffer_in = r3_nonce_buffer_out;

    // w1_addr
    always @(posedge clk)
        if (rst)
            for (i=0; i <= AES_latency - FIFO_READ_LATENCY + 1; i = i+1)
                w1_addr_reg[i] <= 0;
        else begin
            w1_addr_reg[0] <= i_a_mux_select ? ax0[31:0] : r1_addr_out[31:0];
            for (i=1; i <= AES_latency - FIFO_READ_LATENCY + 1; i = i+1)
                w1_addr_reg[i] <= w1_addr_reg[i-1];
        end
    assign w1_addr = w1_addr_reg[AES_latency-FIFO_READ_LATENCY+1];
    assign o_w1_addr = {{32-addr_width-nonce_width-4{1'b0}}, w1_nonce[nonce_width-1:0], w1_addr[addr_width+3:4], {4{1'b0}}};

    // w1_nonce
    always @(posedge clk)
        if (rst)
            w1_nonce <= 0;
        else
            w1_nonce <= r2_nonce_buffer_out;

    // w1_data
    always @(posedge clk)
        if (rst)
            w1_data <= 0;
        else
            w1_data <= i_b_mux_select ? cx ^ {bx1, bx0} : cx ^ c2_out;
    assign o_w1_data = w1_data;

    // r2_data
    always @(posedge clk)
        if (rst) 
            for (i=0; i <= multadd_latency; i = i + 1)
                r2_data[i] <= 0;
        else begin
            r2_data [0] <= i_r2_data;
            for (i=1; i <=  multadd_latency; i = i + 1)
                r2_data[i] <= r2_data[i-1];
        end

    // w2_data
    always @(posedge clk)
        if (rst)
            w2_data <= 0;
        else
            w2_data <= multadder_p;
    assign o_w2_data = w2_data;

    // r3_addr
    assign r3_addr = a3_reg[31:0];
    assign o_r3_addr = {{32-addr_width-nonce_width-4{1'b0}}, r3_nonce_buffer_out[nonce_width-1:0], r3_addr[addr_width+3:4], {4{1'b0}}};

    // r3_nonce
    assign r3_nonce_buffer_in = w1_nonce;

    // r3_data
    always @(posedge clk)
        if (rst)
            for (i=0; i <= div_latency; i = i + 1)
                r3_data[i] <= 0;
        else begin
            r3_data[0] <= i_r3_data;
            for (i=1; i <= div_latency; i = i + 1)
                r3_data[i] <= r3_data[i-1];
        end
    // n, d
    genvar j;
    generate
        for (j=0; j <= div_latency; j = j + 1) begin
            assign n[j] = r3_data[j][63:0];
            assign d[j] = r3_data[j][95:64];
        end
    endgenerate

    // w3_addr
    assign w3_addr = a3_out;
    assign o_w3_addr = {{32-addr_width-nonce_width-4{1'b0}}, r1_nonce_buffer_out[nonce_width-1:0], w3_addr[addr_width+3:4], {4{1'b0}}};

    // w3_data
    always @(posedge clk)
        if (rst)
            w3_data <= 0;
        else
            w3_data <= {r3_data[div_latency][127:64], n[div_latency] ^ div_quotient};
    assign o_w3_data = w3_data;

    // r1_addr
    generate
        if (CN_XHV)
            always @(posedge clk)
                if (rst)
                    r1_addr_reg <= 0;
                else
                    r1_addr_reg <= (~d[div_latency]) ^ div_quotient[31:0];
                else
                    always @(posedge clk)
                        if (rst)
                            r1_addr_reg <= 0;
                        else
                            r1_addr_reg <= d[div_latency] ^ div_quotient[31:0];
    endgenerate
    assign r1_addr = i_r1_addr_mux_select ? ax0 : r1_addr_reg;
    assign r1_nonce = i_r1_addr_mux_select ? state_nonce : r1_nonce_buffer_out;
    assign r1_addr_in = r1_addr_reg;
    assign r2_nonce_buffer_in = r1_nonce;
    assign o_r1_addr = {{32-addr_width-nonce_width-4{1'b0}}, r1_nonce[nonce_width-1:0], r1_addr[addr_width+3:4], {4{1'b0}}};

    // AES
    assign AES_in = r1_data[AES_latency];
    assign AES_key = i_a_mux_select ? {ax1, ax0} : a4_out;

    // multadd
    assign multadder_a = r2_data[FIFO_READ_LATENCY-1];
    assign multadder_b = c1_out;
    assign multadder_c = {a2_out[63:0], a2_out[127:64]};

    // div
    assign div_dividend = n[0];
    assign div_divisor = d[0] | 32'h05;
    assign div_dividend_valid = i_dividend_valid;
    assign div_divisor_valid = i_divisor_valid;

    // state input register
    always @(posedge clk)
        if (rst)
            state <= 0;
        else
            state <= i_state;

    ////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////

    // control
    always @(posedge clk)
        if (rst)
            for (i=0; i < 4; i = i + 1)
                load_state_reg[i] <= 0;
        else begin
            load_state_reg[0] <= i_load_state_reg;
            for (i=1; i < 4; i = i + 1)
                load_state_reg[i] <= load_state_reg[i-1];
        end

    always @(posedge clk)
        if (rst)
            for (i=0; i < 4; i = i + 1)
                in_mux_select[i] <= 0;
        else begin
            in_mux_select[0] <= i_a_mux_select;
            for (i=1; i < 4; i = i + 1)
                in_mux_select[i] <= in_mux_select[i-1];
        end

    // FIFO control
    assign a2_buffer_pop  = i_a2_buffer_pop;
    assign a2_buffer_push = i_a2_buffer_push;
    assign a3_buffer_pop  = i_a3_buffer_pop;
    assign a3_buffer_push = i_a3_buffer_push;
    assign a4_buffer_pop  = i_a4_buffer_pop;
    assign a4_buffer_push = i_a4_buffer_push;
    assign c1_buffer_pop  = i_c1_buffer_pop;
    assign c1_buffer_push = i_c1_buffer_push;
    assign c2_buffer_pop  = i_c2_buffer_pop;
    assign c2_buffer_push = i_c2_buffer_push;
    assign r1_addr_buffer_pop  = i_r1_addr_buffer_pop;
    assign r1_addr_buffer_push = i_r1_addr_buffer_push;
    assign r1_nonce_buffer_pop  = i_r1_nonce_buffer_pop | i_nonce_pop;
    assign r1_nonce_buffer_push = i_r1_nonce_buffer_push;
    assign r2_nonce_buffer_pop  = i_r2_nonce_buffer_pop;
    assign r2_nonce_buffer_push = i_r2_nonce_buffer_push;
    assign r3_nonce_buffer_pop  = i_r3_nonce_buffer_pop;
    assign r3_nonce_buffer_push = i_r3_nonce_buffer_push;
    assign o_nonce = r1_nonce_buffer_out;

endmodule
