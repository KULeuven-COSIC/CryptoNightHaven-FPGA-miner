
module shuffle_unloader #(
    parameter nonce_width = 7
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

    // The handshake should end before shuffle is done with a new entry. Due to
    // the time shift because of explode's significant running time this should
    // always be the case

    localparam IDLE = 0;
    localparam INIT_HANDSHAKE = 1;
    localparam END_HANDSHAKE = 2;

    reg [1:0] next_state;
    wire [1:0] current_state;

    always @(posedge clk)
        if (rst)
            next_state <= 0;
        else case (current_state)
            IDLE: next_state <= i_shuffle_done ? INIT_HANDSHAKE : IDLE;
            INIT_HANDSHAKE: next_state <= handshake_recv ? END_HANDSHAKE : INIT_HANDSHAKE;
            END_HANDSHAKE: next_state <= handshake_recv ? END_HANDSHAKE : IDLE;
            default: next_state <= IDLE;
        endcase
    assign current_state = next_state;

    reg [nonce_width-1:0] data_reg;
    reg handshake, handshake_recv;

    always @(posedge clk)
        handshake_recv <= i_handshake_recv;
    always @(posedge clk)
        if (rst) 
            data_reg <= 0;
        else if (i_shuffle_done)
            data_reg <= i_data;
    assign o_data = data_reg;

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
