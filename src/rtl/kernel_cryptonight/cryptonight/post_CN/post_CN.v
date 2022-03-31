
module post_CN #(
    parameter state_width = 1600,
    parameter nonce_width = 7
)
    (
        input clk,
        input rst,
        input rstn,
        // communication from CN (pulse)
        input i_valid,
        output o_ready,
        input [state_width-1:0] i_data,
        input [nonce_width-1:0] i_nonce,
        // communication to receiver module
        output o_valid,
        input i_ready,
        output [255:0] o_result
    );

    // general architecture:
    // input --- Keccak --- buffer --- FIFO + SHA3-finalists --- buffer --- out
    //        +------ nonce buffer ----------------------- nonce buffer -+
    // so Keccak and SHA3 can operate in "pipelined" fashion (although the design is not fully pipelined)

    wire state_ready, state_accepted;
    wire [state_width-1:0] state;
    wire [nonce_width-1:0] nonce;

    wire K1_start, K1_accepted, K1_nonce_ready, load_FIFO_data_ready, K1_finished;
    wire [state_width-1:0] load_FIFO_data, K1_out, K1_in, shuffled_output;
    wire [nonce_width-1:0] K1_nonce;

    protocol_converter #(
        .IN_PROTOCOL(1), // pulse
        .OUT_PROTOCOL(1), // ready_valid
        .data_width(state_width+nonce_width),
        .busy_reg(0))
    input_buffer (
        .clk(clk),
        .rstn(rstn),
        .src_in(i_valid),
        .src_out(o_ready),
        .src_data({i_nonce, i_data}),
        .dst_in(K1_finished && K1_nonce_ready),
        .dst_out(K1_start),
        .dst_data({K1_nonce, state})
    );

    // Keccak
    shuffle_Keccak shuffle_in(.i_v_data(state), .o_v_data(K1_in));
    shuffle_Keccak shuffle_out(.i_v_data(K1_out), .o_v_data(shuffled_output));
    Keccak_p1600 K1 (
        .i_clk(clk),
        .i_rst(rst),
        .i_start(K1_start),
        .i_v_state(K1_in),
        .i_v_numberOfRounds(24),
        .o_v_state(K1_out),
        .o_done(K1_done)
    );

    wire load_FIFO_data_valid, load_FIFO_nonce_valid;
    protocol_converter #(
        .IN_PROTOCOL(1),
        .OUT_PROTOCOL(2),
        .data_width(state_width),
        .busy_reg(1)
    )
    Keccak_data_buffer (
        .clk(clk),
        .rstn(rstn),
        .src_in(K1_done),
        .src_out(K1_finished),
        .src_data(shuffled_output),
        .dst_in(K1_accepted),
        .dst_out(load_FIFO_data_valid),
        .dst_data(load_FIFO_data),
        .pre_src_in(K1_start)
    );

    protocol_converter #(
        .IN_PROTOCOL(1),
        .OUT_PROTOCOL(2),
        .data_width(nonce_width),
        .busy_reg(0)
    )
    Keccak_nonce_buffer (
        .clk(clk),
        .rstn(rstn),
        .src_in(K1_start),
        .src_out(K1_nonce_ready),
        .src_data(K1_nonce),
        .dst_in(load_FIFO_nonce_ready),
        .dst_out(load_FIFO_nonce_valid),
        .dst_data(load_FIFO_nonce)
    );

    // the other nonce buffer
    protocol_converter #(
        .IN_PROTOCOL(2),
        .OUT_PROTOCOL(2),
        .data_width(nonce_width)
    )
    load_FIFO_nonce_buffer (
        .clk(clk),
        .rstn(rstn),
        .src_in(load_FIFO_nonce_valid),
        .src_out(load_FIFO_nonce_ready),
        .src_data(load_FIFO_nonce),
        .dst_in(i_ready),
        .dst_out(o_nonce_ready),
        .dst_data(o_nonce)
    );

    // handles FIFO loading for different hashes
    // this was adapted from last years work (don't expect too high performance here)

    // generate pulse for starting loader
    reg load_FIFO_pulse;
    wire FIFO_in_full;
    always @(posedge clk)
        if (~rstn)
            load_FIFO_pulse <= 0;
        else
            load_FIFO_pulse <= load_FIFO_data_valid && ~FIFO_in_full;
    wire load_FIFO;
    assign load_FIFO =  load_FIFO_data_valid && ~load_FIFO_pulse;
    reg [1:0] hash_select;
    always @(posedge clk)
        if (~rstn)
            hash_select <= 0;
        else if (load_FIFO)
            hash_select <= load_FIFO_data[1:0];

    wire FIFO_in_filled, in_loader_select, FIFO_in_pop;
    reg FIFO_in_push;
    wire [10:0] in_loader_counter;
    wire[63:0] in_loader_dout;
    load_FIFO in_loader (
        .clk(clk),
        .rst(rst),
        .enable((load_FIFO || in_loader_counter != 0) && ~FIFO_in_full),
        .hash_type(load_FIFO_data[1:0]),
        .select_input(in_loader_select),
        .dout(in_loader_dout),
        .counter(in_loader_counter)
    );

    // this is the done signal
    assign FIFO_in_filled = in_loader_counter == 0 && ~load_FIFO;
    assign K1_accepted = FIFO_in_filled;

    // correctly format input
    wire[63:0] final_rev_inpt;
    rev_bytes #(.SIZE(64))
    final_revver (
        .in(in_loader_counter >= 3 && in_loader_counter <= 27 ? load_FIFO_data[(in_loader_counter-3)<<6+:64] : 0),
        .out(final_rev_inpt)
    );

    // FIFO control
    wire [63:0] FIFO_din;
    assign FIFO_din = in_loader_select ? in_loader_dout : final_rev_inpt;
    always @(posedge clk)
        if (~rstn)
            FIFO_in_push <= 0;
        else if (load_FIFO)
            FIFO_in_push <= 1;
        else if (FIFO_in_filled)
            FIFO_in_push <= 0;

    wire [63:0] FIFO_in_dout;
    xpm_fifo_sync #(
        .CASCADE_HEIGHT(0),        // DECIMAL
        .DOUT_RESET_VALUE("0"),    // String
        .ECC_MODE("no_ecc"),       // String
        .FIFO_MEMORY_TYPE("auto"), // String
        .FIFO_READ_LATENCY(1),     // DECIMAL
        .FIFO_WRITE_DEPTH(64),   // DECIMAL
        .FULL_RESET_VALUE(0),      // DECIMAL
        .PROG_EMPTY_THRESH(10),    // DECIMAL
        .PROG_FULL_THRESH(10),     // DECIMAL
        .RD_DATA_COUNT_WIDTH(1),   // DECIMAL
        .READ_DATA_WIDTH(64),      // DECIMAL
        .READ_MODE("fwft"),         // String
        .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES("0000"), // String
        .WAKEUP_TIME(0),           // DECIMAL
        .WRITE_DATA_WIDTH(64),     // DECIMAL
        .WR_DATA_COUNT_WIDTH(1)    // DECIMAL
    )
    FIFO_in (
        .dout(FIFO_in_dout),
        .empty(FIFO_in_empty),
        .full(FIFO_in_full),
        .din(FIFO_din),
        .rd_en(FIFO_in_pop),
        .rst(rst),
        .sleep(1'b0),
        .wr_clk(clk),
        .wr_en(FIFO_in_push)
    );
    
    // instantiate SHA3 finalist cores
    reg result_valid; // this is for the end, but already needed here
    generate
        wire [63:0] blake_din, blake_dout, skein_din, skein_dout, JH_din,
        JH_dout, groestl_din, groestl_dout, hash_din, hash_dout;
        wire blake_read, blake_write, blake_out_ready, blake_in_ready;
        wire skein_read, skein_write, skein_out_ready, skein_in_ready;
        wire JH_read, JH_write, JH_out_ready, JH_in_ready;
        wire groestl_read, groestl_write, groestl_out_ready, groestl_in_ready;
        wire hash_read, hash_write, hash_out_ready;
        reg hash_in_ready;

        hls_blake blake_hash (
            .rst(rst),
            .clk(clk),
            .din(blake_din),
            .src_read(blake_read),
            .src_ready(blake_in_ready),
            .dout(blake_dout),
            .dst_write(blake_write),
            .dst_ready(blake_out_ready)
        );
        hls_skein skein_hash (
            .rst(rst),
            .clk(clk),
            .din(skein_din),
            .src_read(skein_read),
            .src_ready(skein_in_ready),
            .dout(skein_dout),
            .dst_write(skein_write),
            .dst_ready(skein_out_ready)
        );
        hls_JH JH_hash (
            .rst(rst),
            .clk(clk),
            .din(JH_din),
            .src_read(JH_read),
            .src_ready(JH_in_ready),
            .dout(JH_dout),
            .dst_write(JH_write),
            .dst_ready(JH_out_ready)
        );
        hls_groestl groestl_hash (
            .rst(rst),
            .clk(clk),
            .din(groestl_din),
            .src_read(groestl_read),
            .src_ready(groestl_in_ready),
            .dout(groestl_dout),
            .dst_write(groestl_write),
            .dst_ready(groestl_out_ready)
        );

        assign hash_read = hash_select[1] ? hash_select[0] ? skein_read 
                                                     : JH_read
                                       : hash_select[0] ? groestl_read 
                                                     : blake_read;

        assign hash_dout = hash_select[1] ? hash_select[0] ? skein_dout 
                                                     : JH_dout
                                       : hash_select[0] ? groestl_dout 
                                                     : blake_dout;

        assign hash_write = hash_select[1] ? hash_select[0] ? skein_write 
                                                      : JH_write
                                        : hash_select[0] ? groestl_write 
                                                      : blake_write;

        assign skein_in_ready   = hash_in_ready && hash_select == 2'b11;
        assign JH_in_ready      = hash_in_ready && hash_select == 2'b10;
        assign groestl_in_ready = hash_in_ready && hash_select == 2'b01;
        assign blake_in_ready   = hash_in_ready && hash_select == 2'b00;

        assign skein_out_ready   = hash_select == 2'b11 ? hash_out_ready : 0;
        assign JH_out_ready      = hash_select == 2'b10 ? hash_out_ready : 0;
        assign groestl_out_ready = hash_select == 2'b01 ? hash_out_ready : 0;
        assign blake_out_ready   = hash_select == 2'b00 ? hash_out_ready : 0;

        assign skein_din   = hash_select == 2'b11 ? hash_din : 0;
        assign JH_din      = hash_select == 2'b10 ? hash_din : 0;
        assign groestl_din = hash_select == 2'b01 ? hash_din : 0;
        assign blake_din   = hash_select == 2'b00 ? hash_din : 0;

        assign hash_din = FIFO_in_dout;
        assign hash_out_ready = ~result_valid;
        assign FIFO_in_pop = hash_read;
        always @(posedge clk)
            if (~rstn)
                hash_in_ready <= 0;
            else
                hash_in_ready <= ~FIFO_in_empty;
    endgenerate

    // store result of hash
    reg [255:0] hash_result;
    reg [1:0] hash_result_counter;

    always @(posedge clk)
        if (~rstn) begin
            hash_result <= 0;
            hash_result_counter <= 0;
        end
        else if (hash_write) begin
            hash_result <= {hash_result[191:0], hash_dout};
            hash_result_counter <= hash_result_counter + 1;
        end

    always @(posedge clk)
        if (~rstn)
            result_valid <= 0;
        else if (hash_write)
            result_valid <= hash_result_counter == 3;
        else if (result_valid && i_ready)
            result_valid <= 0;

    assign o_valid = result_valid;
    rev_bytes #(.SIZE(256)) rev_result (.in(hash_result), .out(o_result));

endmodule

