
module protocol_converter #(
    parameter IN_PROTOCOL = 0,
    parameter OUT_PROTOCOL = 0,
    parameter data_width = 1,
    parameter busy_reg = 0 // only relevant for pulse in_protocol
)
    (
        input clk,
        input rstn,
        input src_in,
        output src_out,
        input [data_width-1:0] src_data,
        input dst_in,
        output dst_out,
        output [data_width-1:0] dst_data,
        input pre_src_in // this input is only necessary for pulse in_protocols
    );

    localparam PULSE = 1;
    localparam VALID_READY = 2;
    localparam HANDSHAKE = 3;

    localparam IDLE = 1'b0;
    localparam LOADED = 1'b1;

    reg [data_width-1:0] data;
    wire reg_enable;
    reg state;
    assign reg_enable = src_in && state == IDLE;
    always @(posedge clk)
        if (~rstn)
            data <= 0;
        else if (reg_enable)
            data <= src_data;

    assign dst_data = data;
    // in logic
    wire switch_valid_in, switch_valid_out;

    always @(posedge clk)
        if (~rstn)
            state <= IDLE;
        else case (state)
            IDLE: state <= src_in && switch_valid_in ? LOADED : IDLE;
            LOADED: state <= dst_in && switch_valid_out ? IDLE : LOADED;
        endcase

    generate begin
        case (IN_PROTOCOL)
            PULSE: begin 
                // keep track of whether previous module is busy
                if (busy_reg == 1) begin
                    reg busy;
                    always @(posedge clk)
                        if (~rstn)
                            busy <= 0;
                        else if (~busy && pre_src_in)
                            busy <= 1;
                        else if (busy && src_in)
                            busy <= 0;
                    assign src_out = state == IDLE && ~busy; 
                end
                else
                    assign src_out = state == IDLE;
                assign switch_valid_in = 1'b1;
            end
            VALID_READY: begin
                assign src_out = state == IDLE;
                assign switch_valid_in = 1'b1;
            end
            HANDSHAKE: begin
                assign src_out = state == LOADED;
                reg handshake;
                always @(posedge clk)
                    handshake <= src_in;
                assign switch_valid_in = ~handshake;
            end
        endcase
        case (OUT_PROTOCOL)
            PULSE: begin 
                // need pulse reg to generate pulse
                assign dst_out = state == LOADED && dst_in; // only generate pulse when dst ready
                assign switch_valid_out = 1'b1;
            end
            VALID_READY: begin
                assign dst_out = state == LOADED; // switch back when dst ready
                assign switch_valid_out = 1'b1;
            end
            HANDSHAKE: begin
                assign dst_out = state == LOADED;
                reg handshake;
                always @(posedge clk)
                    handshake <= dst_in;
                assign switch_valid_out = ~handshake;
            end
        endcase
    end
    endgenerate

endmodule
