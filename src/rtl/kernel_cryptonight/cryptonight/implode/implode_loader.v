module implode_loader #(
    parameter state_width = 'd1600,
    parameter block_width = 'd1024,
    parameter key_width = 'd256,
    parameter nonce_width = 'd7,
    parameter BRAM_addr_width = 'd9,
    parameter BRAM_delay = 3
)
    (
        input clk,
        input rstn,
        input [state_width-1:0] i_state,
        input [nonce_width-1:0] i_nonce,
        input i_nonce_valid,
        output [key_width-1:0] key_bytes,
        output [block_width-1:0] block_bytes,
        output [nonce_width-1:0] o_nonce,
        output rd_en,
        output o_ready, // indicate to shuffle we are ready to receive
        output o_valid, // indicate to implode we are ready to provide
        output [BRAM_addr_width-1:0] o_BRAM_addr,
        output o_rstn_implode,
        input i_implode_done,
        output [state_width-1:0] o_state
    );

    function integer clogb2 (input integer bit_depth);
        begin
            for(clogb2=0; bit_depth>0; clogb2=clogb2+1)
                bit_depth = bit_depth >> 1;
        end
    endfunction

    localparam IDLE = 0;
    localparam READ = 1;
    localparam WAIT = 2;
    localparam OUT = 3;
    localparam WAIT_IMP = 5;

    wire [2:0] current_state;
    reg [2:0] next_state;
    reg [clogb2(BRAM_delay)-1:0] wait_counter;
    reg [state_width-1:0] state_reg;
    reg [nonce_width-1:0] nonce;


    always @(posedge clk)
        if (~rstn)
            next_state <= IDLE;
        else case (current_state)
            IDLE: next_state <= i_nonce_valid ? READ : IDLE;
            READ: next_state <= WAIT;
            WAIT: next_state <= wait_counter == BRAM_delay ? OUT : WAIT;
            OUT: next_state <= ~i_nonce_valid ? WAIT_IMP : OUT;
            WAIT_IMP: next_state <= i_implode_done ? IDLE : WAIT_IMP;
            default: next_state <= IDLE;
        endcase
    assign current_state = next_state;
            
    always @(posedge clk)
        if (~rstn)
            wait_counter <= 0;
        else case (current_state)
            WAIT: wait_counter <= wait_counter + 1;
            default: wait_counter <= 0;
        endcase

    always @(posedge clk)
        if (~rstn)
            state_reg <= 0;
        else if (wait_counter == BRAM_delay)
            state_reg <= i_state;

    always @(posedge clk)
        if (~rstn)
            nonce <= 0;
        else if (current_state == IDLE && i_nonce_valid)
            nonce <= i_nonce;

    reg handshake;
    always @(posedge clk)
        if (~rstn)
            handshake <= 0;
        else if (current_state == IDLE || handshake == 1)
            handshake <= i_nonce_valid;

    assign key_bytes = state_reg[key_width*2-1:key_width];
    assign block_bytes = state_reg[key_width*2+block_width-1:key_width*2];
    assign rd_en = current_state == READ;
    assign o_ready = handshake;
    assign o_nonce = nonce;
    assign o_valid = current_state == OUT && ~i_nonce_valid;
    assign o_BRAM_addr = {{BRAM_addr_width-nonce_width{1'b0}},nonce};
    assign o_state = state_reg;
    
    reg rstn_implode;
    always @(posedge clk)
        rstn_implode <= rstn && ~i_implode_done;
    assign o_rstn_implode = rstn_implode;

endmodule
