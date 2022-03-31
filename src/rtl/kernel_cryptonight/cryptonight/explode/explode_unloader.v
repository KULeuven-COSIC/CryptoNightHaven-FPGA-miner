
module explode_unloader #(
    parameter nonce_width = 7,
    parameter explode_width = 512
)
    (
        input clk,
        input rstn,
        input i_compact_start,
        input i_compact_done,
        input i_AXI_done,
        input [explode_width-1:0] i_state_bytes,
        input [nonce_width-1:0] i_nonce,
        output o_handshake,
        output [nonce_width+explode_width-1:0] o_data,
        input i_handshake_recv
    );

    // requirements for FSM
    //  1. explode may start before the FSM reaches the IDLE state
    //  2. explode may not end before the FSM reaches WAIT_EX (given the long
    //     running time of explode this will always be the case unless some error
    //     occurs elsewhere in the design)

    localparam IDLE = 0;
    localparam WAIT_EX = 1; // wait for explode to finish
    localparam INIT_HAND = 3;
    localparam WAIT_HAND = 4;
    localparam END_HAND = 5;

    reg[3:0] next_state;
    wire[3:0] current_state;
    reg ex_done, ex_started;
    reg [nonce_width + explode_width-1:0] data_reg [1:0];

    always @(posedge clk)
        if (~rstn)
            ex_done <= 0;
        else case (current_state)
            WAIT_EX: ex_done <= i_compact_done && i_AXI_done;
            default: ex_done <= 0;
        endcase

    always @(posedge clk)
        if (~rstn) begin
            ex_started <= 0;
            data_reg[0] <= 0;
            data_reg[1] <= 0;
        end
        else if (i_compact_start) begin
            data_reg[0] <= {i_nonce, i_state_bytes};
            ex_started <= 1;
        end
        else if (current_state == WAIT_EX) begin
            ex_started <= 0;
            data_reg[1] <= data_reg[0];
        end

    reg handshake, handshake_recv;
    always @(posedge clk)
        if (~rstn)
            next_state <= IDLE;
        else case(current_state)
            IDLE: next_state <= ex_started ? WAIT_EX : IDLE;
            WAIT_EX: next_state <= ex_done ? INIT_HAND : WAIT_EX;
            INIT_HAND: next_state <= WAIT_HAND;
            WAIT_HAND: next_state <= handshake_recv ? END_HAND : WAIT_HAND;
            END_HAND: next_state <= handshake_recv ? END_HAND : IDLE;
            default: next_state <= IDLE;
        endcase
    assign current_state = next_state;

    always @(posedge clk)
        handshake_recv <= i_handshake_recv; // safety register

    always @(posedge clk)
        if (~rstn)
            handshake <= 0;
        else case(current_state)
            INIT_HAND: handshake <= 1;
            END_HAND: handshake <= 0;
            default: handshake <= handshake;
        endcase

    assign o_handshake = handshake;
    assign o_data = data_reg[1];

endmodule
