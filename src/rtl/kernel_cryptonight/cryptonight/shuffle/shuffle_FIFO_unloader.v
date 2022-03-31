
module shuffle_FIFO_unloader
    #(
        parameter nonce_width = 7,
        parameter buffer_depth = 128
    )
    (
        input clk,
        input rst,
        input i_shuffle_done,
        input [nonce_width-1:0] i_data,
        output [nonce_width-1:0] o_data,
        output o_handshake,
        input i_handshake_recv
    );

    localparam IDLE = 0;
    localparam INIT_HANDSHAKE = 1;
    localparam END_HANDSHAKE = 2;
    localparam READ = 3;

    reg [1:0] next_state;
    wire [1:0] current_state;

    reg handshake, handshake_recv;
    always @(posedge clk)
        if (rst)
            next_state <= 0;
        else case (current_state)
            IDLE: next_state <= i_shuffle_done ? READ : IDLE;
            READ: next_state <= INIT_HANDSHAKE;
            INIT_HANDSHAKE: next_state <= handshake_recv ? END_HANDSHAKE : INIT_HANDSHAKE;
            END_HANDSHAKE: next_state <= handshake_recv ? END_HANDSHAKE : IDLE;
            default: next_state <= IDLE;
        endcase
    assign current_state = next_state;

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
        .READ_DATA_WIDTH(nonce_width),      // DECIMAL
        .READ_MODE("std"),         // String
        .SIM_ASSERT_CHK(0),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES("0000"), // String
        .WAKEUP_TIME(0),           // DECIMAL
        .WRITE_DATA_WIDTH(nonce_width),     // DECIMAL
        .WR_DATA_COUNT_WIDTH(1)    // DECIMAL
    )
    xpm_fifo_sync_inst (
        .dout(o_data),
        .empty(empty),
        .full(full),
        .din(i_data),
        .rd_en(current_state == READ),
        .rst(rst),
        .sleep(1'b0),
        .wr_clk(clk),
        .wr_en(i_shuffle_done)
    );

    always @(posedge clk)
        handshake_recv <= i_handshake_recv;

    always @(posedge clk)
        if (rst)
            handshake <= 0;
        else case (current_state)
            INIT_HANDSHAKE: handshake <= 1;
            END_HANDSHAKE: handshake <= 0;
            default: handshake <= handshake;
        endcase
    assign o_handshake = handshake;
endmodule
