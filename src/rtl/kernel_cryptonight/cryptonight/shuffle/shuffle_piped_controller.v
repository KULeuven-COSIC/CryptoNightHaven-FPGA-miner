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


module shuffle_piped_controller (
    input clk, // clock
    input rst, // active high reset
    
    // accept new input state
    input  i_state_valid, // axi-like valid-ready structure
    output o_state_ready,
    output o_load_state_reg,
    output o_r1_addr_mux_select,
    output o_a_mux_select,
    output o_b_mux_select,
    output o_dividend_valid,
    output o_divisor_valid,

    // memory requests
    output o_r1_request,
    output o_first_read,
    input  i_r1_valid,
    output o_w1_valid,
    output o_r2_request,
    input  i_r2_valid,
    output o_w2_valid,
    output o_r3_request,
    input  i_r3_valid,
    output o_w3_valid,

    // datapath buffers
    output o_a2_buffer_pop,
    output o_a2_buffer_push,
    output o_a3_buffer_pop,
    output o_a3_buffer_push,
    output o_a4_buffer_pop,
    output o_a4_buffer_push,
    output o_c1_buffer_pop,
    output o_c1_buffer_push,
    output o_c2_buffer_pop,
    output o_c2_buffer_push,
    output o_r1_addr_buffer_pop,
    output o_r1_addr_buffer_push,
    output o_r1_nonce_buffer_pop,
    output o_r1_nonce_buffer_push,
    output o_r2_nonce_buffer_pop,
    output o_r2_nonce_buffer_push,
    output o_r3_nonce_buffer_pop,
    output o_r3_nonce_buffer_push,

    // end execution (datapath releases nonce at the same time)
    output o_done,
    output o_nonce_pop // indicate release of nonce to datapath
);
    // parameters
    parameter FIFO_READ_LATENCY = 1;
    parameter AES_latency = 1 + (FIFO_READ_LATENCY-1);
    parameter multadd_latency = 24 + (FIFO_READ_LATENCY-1);
    parameter multadd_multiplier_latency = 18;
    parameter div_latency = 68;
    parameter shuffle_rounds = 'h40000;
    parameter buffer_depth = 128;
    integer i; // iteration variable

    // accept a new state and get ready to perform a first read request
    // 
    // Once state is accepted, it is loaded into the state regs and the
    // controller tries to perform a read request when nothing in the pipeline
    // is hindering the exchange. Once accepted it identifies the corresponding
    // incoming read and generates selector signals for the MUX'es in the
    // datapath. When ax and bx are both read from the state regs, the state
    // regs are freed and the controller asserts the state_ready signal again.
    //
    // for timing when b is empty, similar to the regular aes_process_tracker
    reg new_aes_process_tracker [AES_latency+2:0]; 
    // for performing r1_req
    reg div_process_tracker [div_latency+1:0]; 
    reg state_ready, new_r1_request, new_r1_request_done;
    wire new_r1_arrived, r1_valid;
    wire state_valid;
    assign state_valid = i_state_valid;
    always @(posedge clk)
        if (rst) 
            state_ready <= 1;
        else if (state_ready && state_valid) 
            state_ready <= 0;
        else if (new_aes_process_tracker[AES_latency-1]) // this is the condition for popping b1/c2
            state_ready <= 1;
    assign o_state_ready = state_ready;
    assign o_load_state_reg = state_ready && state_valid;
    always @(posedge clk)
        if (rst) 
            new_r1_request <= 0;
        else if (~(state_ready || div_process_tracker[div_latency] || new_r1_request_done))
            new_r1_request <= 1;
        else
            new_r1_request <= 0;
    assign o_r1_addr_mux_select = new_r1_request;
    always @(posedge clk)
        if (rst)
            new_r1_request_done <= 0;
        else if (state_ready)
            new_r1_request_done <= 0;
        else if (~div_process_tracker[div_latency])
            new_r1_request_done <= 1;

    // identify whether an incoming r1 belongs to a first or an xth round
    reg [31:0] r1_counter, r1_countdown;
    reg r1_countdown_valid;
    always @(posedge clk)
        // keep track of pending r1's
        if (rst)
            r1_counter <= 0;
        else
            case ({i_r1_valid, o_r1_request})
                2'b01: r1_counter <= r1_counter + 1;
                2'b10: r1_counter <= r1_counter - 1;
                default: r1_counter <= r1_counter;
            endcase
    always @(posedge clk)
        // count down to the new r1
        if (rst)
            r1_countdown <= 0;
        else if (new_r1_request) // load countdown
            r1_countdown <= r1_counter + 1;
        else if (r1_countdown_valid && r1_valid) // count
            r1_countdown <= r1_countdown - 1;
    always @(posedge clk)
        // enable or disable this countdown
        if (rst)
            r1_countdown_valid <= 0;
        else if (new_r1_request)
            r1_countdown_valid <= 1;
        else if (r1_countdown == 0)
            r1_countdown_valid <= 0;
    // signal that current r1 is a first r1
    // this signal is asserted in the same clockperiod r1_valid is asserted
    assign new_r1_arrived = r1_countdown_valid && r1_countdown == 1 && r1_valid;
    // consider a separate AES tracker to keep track of when to release the state regs
    always @(posedge clk)
        if (rst)
            for (i=0; i <= AES_latency+2; i = i + 1)
                new_aes_process_tracker[i] <= 0;
        else begin
            new_aes_process_tracker[0] <= new_r1_arrived;
            for (i=1; i <= AES_latency+2; i = i + 1)
                new_aes_process_tracker[i] <= new_aes_process_tracker[i-1];
        end

    // process r1
    wire a2_buffer_push, c1_buffer_push, c2_buffer_pop, a4_buffer_pop,
    r1_addr_buffer_pop, r2_nonce_buffer_pop, r3_nonce_buffer_push;
    reg a_mux_select, b_mux_select;
    wire w1_valid, r2_request;
    reg aes_process_tracker [AES_latency+2:0];
    always @(posedge clk)
        if (rst)
            for (i=0; i <= AES_latency+2; i = i + 1)
                aes_process_tracker[i] <= 0;
        else begin
            aes_process_tracker[0] <= r1_valid;
            for (i=1; i <= AES_latency+2; i = i + 1)
                aes_process_tracker[i] <= aes_process_tracker[i-1];
        end
    // note the difference between AES_latency-1 and 0:
    // if AES is modified to take longer then this will still be correct
    // provided the parameter in this file is modified as well.
    always @(posedge clk)
        if (rst) begin
            a_mux_select <= 0;
            b_mux_select <= 0;
        end
        else begin
            a_mux_select <= new_aes_process_tracker[FIFO_READ_LATENCY-1];
            b_mux_select <= new_aes_process_tracker[AES_latency];//-1];
        end
    assign a2_buffer_push = aes_process_tracker[FIFO_READ_LATENCY];
    // either pop a4, or read the state regs
    assign a4_buffer_pop = aes_process_tracker[0] && ~new_aes_process_tracker[0]; //r1_valid && ~new_r1_arrived;
    assign c1_buffer_push = aes_process_tracker[AES_latency+1];
    // either pop c2, or read the state regs
    assign c2_buffer_pop = aes_process_tracker[AES_latency+1-FIFO_READ_LATENCY] && ~new_aes_process_tracker[AES_latency+1-FIFO_READ_LATENCY];
    assign r1_addr_buffer_pop = aes_process_tracker [0] & ~new_aes_process_tracker[0];//r1_valid && ~new_r1_arrived;
    assign w1_valid = aes_process_tracker[AES_latency+2];
    assign r2_nonce_buffer_pop = aes_process_tracker[AES_latency+1-FIFO_READ_LATENCY];
    assign r3_nonce_buffer_push = aes_process_tracker[AES_latency+2];
    assign r2_request = aes_process_tracker[AES_latency+1];
    assign r1_valid = i_r1_valid;

    assign o_a_mux_select = a_mux_select;
    assign o_a2_buffer_push = a2_buffer_push;
    assign o_a4_buffer_pop = a4_buffer_pop;
    assign o_b_mux_select = b_mux_select;
    assign o_c1_buffer_push = c1_buffer_push;
    assign o_c2_buffer_pop = c2_buffer_pop;
    assign o_r1_addr_buffer_pop = r1_addr_buffer_pop;
    assign o_w1_valid = w1_valid;
    assign o_r2_nonce_buffer_pop = r2_nonce_buffer_pop;
    assign o_r3_nonce_buffer_push = r3_nonce_buffer_push;
    assign o_r2_request = r2_request;

    // process r2
    wire a2_buffer_pop, c1_buffer_pop, a3_buffer_push, c2_buffer_push, prevent_c2_out;
    wire r3_request, r2_valid, w2_valid, r3_nonce_buffer_pop, r1_nonce_buffer_push;
    reg multadd_process_tracker [multadd_latency+1:0];
    always @(posedge clk)
        if (rst)
            for (i=0; i <= multadd_latency+1; i = i + 1)
                multadd_process_tracker[i] <= 0;
        else begin
            multadd_process_tracker[0] <= r2_valid;
            for (i=1; i <= multadd_latency+1; i = i + 1)
                multadd_process_tracker[i] <= multadd_process_tracker[i-1];
        end
    assign a2_buffer_pop = multadd_process_tracker[multadd_multiplier_latency+1-FIFO_READ_LATENCY];
    assign c1_buffer_pop = r2_valid;
    assign r3_request = multadd_process_tracker[multadd_latency+1];
    assign c2_buffer_push = multadd_process_tracker[multadd_latency+1] && ~prevent_c2_out;
    assign a3_buffer_push = multadd_process_tracker[multadd_latency+1];
    assign w2_valid = multadd_process_tracker[multadd_latency+1];
    assign r2_valid = i_r2_valid;
    assign r3_nonce_buffer_pop = multadd_process_tracker[multadd_latency-FIFO_READ_LATENCY+1]; // 1 before write valid
    assign r1_nonce_buffer_push = multadd_process_tracker[multadd_latency+1]; // 1 after the previous pops

    assign o_a2_buffer_pop = a2_buffer_pop;
    assign o_c1_buffer_pop = c1_buffer_pop;
    assign o_r3_request = r3_request;
    assign o_c2_buffer_push = c2_buffer_push;
    assign o_a3_buffer_push = a3_buffer_push;
    assign o_w2_valid = w2_valid;
    assign o_r3_nonce_buffer_pop = r3_nonce_buffer_pop;
    assign o_r1_nonce_buffer_push = r1_nonce_buffer_push;

    // process r3
    wire a3_buffer_pop, a4_buffer_push, r1_addr_buffer_push, r3_valid,
    w3_valid, r1_request, dividend_ready, divisor_ready, r1_nonce_buffer_pop,
    r2_nonce_buffer_push, prevent_a4_out, prevent_r1_addr_out,
    prevent_r2_nonce_out, shuffle_done; 
    // declaration above repeated for clarity
    // reg div_process_tracker [div_latency+1:0];
    always @(posedge clk)
        if (rst)
            for (i=0; i <= div_latency+1; i = i + 1)
                div_process_tracker[i] <= 0;
        else begin
            div_process_tracker[0] <= r3_valid;
            for (i=1; i <= div_latency+1; i = i + 1)
                div_process_tracker[i] <= div_process_tracker[i-1];
        end
    assign dividend_valid = div_process_tracker[0];
    assign divisor_valid = div_process_tracker[0];
    assign a3_buffer_pop = div_process_tracker[div_latency-FIFO_READ_LATENCY+1];
    assign a4_buffer_push = div_process_tracker[div_latency+1] && ~prevent_a4_out;
    assign r1_addr_buffer_push = div_process_tracker[div_latency+1] && ~prevent_r1_addr_out;
    assign w3_valid = div_process_tracker[div_latency+1];
    assign r1_nonce_buffer_pop = div_process_tracker[div_latency-FIFO_READ_LATENCY+1];
    assign r2_nonce_buffer_push = div_process_tracker[div_latency+1] && ~prevent_r2_nonce_out;
    assign r1_request = div_process_tracker[div_latency+1] && ~shuffle_done; // no new r1_request if shuffle is done
    assign r3_valid = i_r3_valid;
    assign prevent_r1_addr_out = prevent_a4_out;
    assign prevent_r2_nonce_out = prevent_a4_out;

    assign o_dividend_valid = dividend_valid;
    assign o_divisor_valid = divisor_valid;
    assign o_a3_buffer_pop = a3_buffer_pop;
    assign o_a4_buffer_push = a4_buffer_push;
    assign o_r1_addr_buffer_push = r1_addr_buffer_push;
    assign o_w3_valid = w3_valid;
    assign o_r1_request = r1_request | new_r1_request;
    assign o_first_read = new_r1_request;
    assign o_r1_nonce_buffer_pop = r1_nonce_buffer_pop;
    assign o_r2_nonce_buffer_push = r2_nonce_buffer_push || new_r1_request;


    // counter to keep track of the amount of iterations
    localparam counter_width = 19;
    localparam max_counter = shuffle_rounds;
    wire counter_push, counter_pop, counter_empty, counter_full, counter_sel;
    reg counter_push_reg, counter_pop_reg, shuffle_done_reg, shuffle_done_pulse;
    reg [counter_width-1:0] counter_data;
    wire [counter_width-1:0] counter_in, counter_out;
    xpm_fifo_sync #(
        .CASCADE_HEIGHT(0),        // DECIMAL
        .DOUT_RESET_VALUE("0"),    // String
        .ECC_MODE("no_ecc"),       // String
        .FIFO_MEMORY_TYPE("auto"), // String
        .FIFO_READ_LATENCY(1),     // DECIMAL
        .FIFO_WRITE_DEPTH(buffer_depth),   // DECIMAL
        .FULL_RESET_VALUE(0),      // DECIMAL
        .PROG_EMPTY_THRESH(10),    // DECIMAL
        .PROG_FULL_THRESH(10),     // DECIMAL
        .RD_DATA_COUNT_WIDTH(1),   // DECIMAL
        .READ_DATA_WIDTH(counter_width),      // DECIMAL
        .READ_MODE("std"),         // String
        .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES("0000"), // String
        .WAKEUP_TIME(0),           // DECIMAL
        .WRITE_DATA_WIDTH(counter_width),     // DECIMAL
        .WR_DATA_COUNT_WIDTH(1)    // DECIMAL
    )
    counter_FIFO (
        .dout(counter_out),                   // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
        // when reading the FIFO.

        .empty(counter_empty),                 // 1-bit output: Empty Flag: When asserted, this signal indicates that the
        // FIFO is empty. Read requests are ignored when the FIFO is empty,
        // initiating a read while empty is not destructive to the FIFO.

        .full(counter_full),                   // 1-bit output: Full Flag: When asserted, this signal indicates that the
        // FIFO is full. Write requests are ignored when the FIFO is full,
        // initiating a write when the FIFO is full is not destructive to the
        // contents of the FIFO.

        .din(counter_in),                     // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
        // writing the FIFO.

        .rd_en(counter_pop),                 // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
        // signal causes data (on dout) to be read from the FIFO. Must be held
        // active-low when rd_rst_busy is active high.

        .rst(rst),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
        // unstable at the time of applying reset, but reset must be released only
        // after the clock(s) is/are stable.

        .wr_clk(clk),               // 1-bit input: Write clock: Used for write operation. wr_clk must be a
        // free running clock.

        .wr_en(counter_push)                  // 1-bit input: Write Enable: If the FIFO is not full, asserting this
        // signal causes data (on din) to be written to the FIFO Must be held
        // active-low when rst or wr_rst_busy or rd_rst_busy is active high

    );
    assign counter_in = counter_sel ? 0 : counter_data;
    assign counter_pop = div_process_tracker[div_latency];
    assign shuffle_done = (counter_out == max_counter - 1) && ~shuffle_done_pulse;
    always @(posedge clk)
        if (rst) begin
            counter_push_reg <= 0;
            counter_pop_reg <= 0;
            shuffle_done_reg <= 0;
            counter_data <= 0;
        end
        else begin
            counter_push_reg <= counter_pop_reg && ~shuffle_done; 
            counter_pop_reg <= counter_pop; 
            shuffle_done_reg <= shuffle_done;
            counter_data <= counter_out + 1;
        end
    always @(posedge clk)
        if (rst) 
            shuffle_done_pulse <= 0;
        else if (counter_pop)
            shuffle_done_pulse <= 0;
        else if (shuffle_done)
            shuffle_done_pulse <= 1;
    assign counter_push = counter_push_reg | new_r1_request;
    assign counter_sel = new_r1_request;
    assign o_done = shuffle_done_reg;
    assign o_nonce_pop = 0;//shuffle_done;

    // prevent loading of buffers in the last round
    wire prevent_c2_push, prevent_c2_pop, prevent_c2_empty, prevent_c2_full, prevent_c2_in;

    xpm_fifo_sync #(
        .CASCADE_HEIGHT(0),        // DECIMAL
        .DOUT_RESET_VALUE("0"),    // String
        .ECC_MODE("no_ecc"),       // String
        .FIFO_MEMORY_TYPE("auto"), // String
        .FIFO_READ_LATENCY(1),     // DECIMAL
        .FIFO_WRITE_DEPTH(buffer_depth),   // DECIMAL
        .FULL_RESET_VALUE(0),      // DECIMAL
        .PROG_EMPTY_THRESH(10),    // DECIMAL
        .PROG_FULL_THRESH(10),     // DECIMAL
        .RD_DATA_COUNT_WIDTH(1),   // DECIMAL
        .READ_DATA_WIDTH(1),      // DECIMAL
        .READ_MODE("std"),         // String
        .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES("0000"), // String
        .WAKEUP_TIME(0),           // DECIMAL
        .WRITE_DATA_WIDTH(1),     // DECIMAL
        .WR_DATA_COUNT_WIDTH(1)    // DECIMAL
    )
    prevent_c2_FIFO (
        .dout(prevent_c2_out),                   // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
        // when reading the FIFO.

        .empty(prevent_c2_empty),                 // 1-bit output: Empty Flag: When asserted, this signal indicates that the
        // FIFO is empty. Read requests are ignored when the FIFO is empty,
        // initiating a read while empty is not destructive to the FIFO.

        .full(prevent_c2_full),                   // 1-bit output: Full Flag: When asserted, this signal indicates that the
        // FIFO is full. Write requests are ignored when the FIFO is full,
        // initiating a write when the FIFO is full is not destructive to the
        // contents of the FIFO.

        .din(prevent_c2_in),                     // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
        // writing the FIFO.

        .rd_en(prevent_c2_pop),                 // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
        // signal causes data (on dout) to be read from the FIFO. Must be held
        // active-low when rd_rst_busy is active high.

        .rst(rst),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
        // unstable at the time of applying reset, but reset must be released only
        // after the clock(s) is/are stable.

        .wr_clk(clk),               // 1-bit input: Write clock: Used for write operation. wr_clk must be a
        // free running clock.

        .wr_en(prevent_c2_push)                  // 1-bit input: Write Enable: If the FIFO is not full, asserting this
        // signal causes data (on din) to be written to the FIFO Must be held
        // active-low when rst or wr_rst_busy or rd_rst_busy is active high

    );

    wire prevent_a4_push, prevent_a4_pop, prevent_a4_empty, prevent_a4_full, prevent_a4_in;
    xpm_fifo_sync #(
        .CASCADE_HEIGHT(0),        // DECIMAL
        .DOUT_RESET_VALUE("0"),    // String
        .ECC_MODE("no_ecc"),       // String
        .FIFO_MEMORY_TYPE("auto"), // String
        .FIFO_READ_LATENCY(1),     // DECIMAL
        .FIFO_WRITE_DEPTH(buffer_depth),   // DECIMAL
        .FULL_RESET_VALUE(0),      // DECIMAL
        .PROG_EMPTY_THRESH(10),    // DECIMAL
        .PROG_FULL_THRESH(10),     // DECIMAL
        .RD_DATA_COUNT_WIDTH(1),   // DECIMAL
        .READ_DATA_WIDTH(1),      // DECIMAL
        .READ_MODE("std"),         // String
        .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES("0000"), // String
        .WAKEUP_TIME(0),           // DECIMAL
        .WRITE_DATA_WIDTH(1),     // DECIMAL
        .WR_DATA_COUNT_WIDTH(1)    // DECIMAL
    )
    prevent_a4_FIFO (
        .dout(prevent_a4_out),                   // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
        // when reading the FIFO.

        .empty(prevent_a4_empty),                 // 1-bit output: Empty Flag: When asserted, this signal indicates that the
        // FIFO is empty. Read requests are ignored when the FIFO is empty,
        // initiating a read while empty is not destructive to the FIFO.

        .full(prevent_a4_full),                   // 1-bit output: Full Flag: When asserted, this signal indicates that the
        // FIFO is full. Write requests are ignored when the FIFO is full,
        // initiating a write when the FIFO is full is not destructive to the
        // contents of the FIFO.

        .din(prevent_a4_in),                     // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
        // writing the FIFO.

        .rd_en(prevent_a4_pop),                 // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
        // signal causes data (on dout) to be read from the FIFO. Must be held
        // active-low when rd_rst_busy is active high.

        .rst(rst),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
        // unstable at the time of applying reset, but reset must be released only
        // after the clock(s) is/are stable.

        .wr_clk(clk),               // 1-bit input: Write clock: Used for write operation. wr_clk must be a
        // free running clock.

        .wr_en(prevent_a4_push)                  // 1-bit input: Write Enable: If the FIFO is not full, asserting this
        // signal causes data (on din) to be written to the FIFO Must be held
        // active-low when rst or wr_rst_busy or rd_rst_busy is active high

    );

    assign prevent_c2_push = counter_push;
    // see above:
    /* assign c2_buffer_push = multadd_process_tracker[multadd_latency+1]; */
    assign prevent_c2_pop = multadd_process_tracker[multadd_latency];
    assign prevent_c2_in = counter_sel ? 1'b0 : counter_out == max_counter - 2;

    assign prevent_a4_push = multadd_process_tracker[multadd_latency+1];
    // see above:
    /* assign a4_buffer_push = div_process_tracker[div_latency+1]; */
    assign prevent_a4_pop = div_process_tracker[div_latency];
    assign prevent_a4_in = prevent_c2_out;

endmodule

