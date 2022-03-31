`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.02.2021 11:12:30
// Design Name: 
// Module Name: explode_compact
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: This version of explode should be more compact since it requires less buffer
//     memory for writing to the BRAM. The interface is a little more elegant as well
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module explode_compact 
    #(
        parameter AXI = 1'b1, 
        parameter NUM_ROUNDS = 'h020
    )
    (
        input clk,
        input rstn,
        input start,
        input i_buffer_full,
        input[255:0] key_bytes,
        input [1023:0] block_bytes,
        input[31:0] max_mem_address,
        output reg[31:0] mem_address,
        output wire[127:0] scratch_write,
        output wire request_write,
        output done
    );

    // General modus operandi
    // Keys are kept in registers, blocks are shifted through a series of registers and AES modules
    // There are more block registers than blocks to correspond to the number of keys and buffer
    // data for the mixer.
    // after a back of the envelope calculation this is as compact as you can make it without
    // sacrificing speed. The alternative would be shifting the keys and keeping blocks static
    // but that results in the same amount of 128-bit registers and bigger MUX'es.
    // Critical path is expected to be block[9] -> AES -> MUX -> mix (XOR) -> MUX -> block[0]


    //// Key part ////
    reg[127:0] keys [9:0];
    reg keygen_done, started;

    wire[127:0] keygen_output, rev_keygen_output;
    wire keygen_available;

    aes_genkey_compact keygen(.clk(clk),
        .rstn(rstn),
        .start(start),
        .in0(key_bytes[127:0]), 
        .in1(key_bytes[255:128]),
        .key(keygen_output),
        .key_available(keygen_available)
    );

    rev_col keyout(.in(keygen_output), .out(rev_keygen_output));

    always @(posedge clk)
        if (~rstn)
            started <= 0;
        else if (start)
            started <= 1;

    always @(posedge clk)
        // start signal for AES
        if (~rstn)
            keygen_done <= 0;
        else if (~keygen_available && started)
            keygen_done <= 1;

    integer i; 
    always @(posedge clk)
        // key loading
        if (~rstn)
            for (i=0; i < 10; i = i+1) begin
                keys[i] <= 0;
            end
        else if (keygen_available) begin
            for (i=0; i < 9; i = i + 1) begin
                keys[i] <= keys[i+1];
            end
            keys[9] <= rev_keygen_output;
        end

    /////// block logic //////////

    reg[127:0] blocks [10:0]; // seven for the blocks, some extra for shifting to right keys
    reg[127:0] mix0buffer; // keep block 0 to mix with block 7
    // For AES module instantiation
    wire [127:0] rev_blocks[9:0], rev_AES_out[9:0], AES_out[9:0], rev_key[9:0], mixer_output;

    // Mux selection logic //
    reg preliminary; // Are we in preliminary rounds?
    reg first_round; // Are we in the first round?
    // Counters //
    reg[3:0] counter; // intra round counter
    reg[3:0] preliminary_round_counter; // counter to trigger preliminary, should trigger after counter = 7
    // different indexing for clarity
    wire AES_bypass [10:5]; // Bypass AES block when loading stuff at first
    // enable / disable logic
    wire enable_operation;
    generate
        if (AXI)
            assign enable_operation = ~i_buffer_full;
        else
            assign enable_operation = max_mem_address > mem_address;
    endgenerate

    //// control logic ////
    always @(posedge clk)
        if (~rstn)
            preliminary <= 1;
        else if (counter == 7 && preliminary_round_counter == 15)
            preliminary <= 0;

    always @(posedge clk)
        if (~rstn)
            counter <= 0;
        else if (keygen_done && enable_operation && ~done)
            if (preliminary)
                counter <= (counter + 1) % 11;
            else
                counter <= (counter + 1) % 10;

    always @(posedge clk)
        if (~rstn)
            first_round <= 1;
        else if (counter == 7) // everything after 6 is nonsense including extra clock periods
            first_round <= 0;

    always @(posedge clk)
        if (~rstn)
            preliminary_round_counter <= 0;
        else if (counter == 7 && ~first_round && preliminary)
            preliminary_round_counter <= preliminary_round_counter + 1;

    // mix buffer logic for the 0-7 mix
    always @(posedge clk)
        if (~rstn)
            mix0buffer <= 0;
        else if (counter == 9)
            mix0buffer <= AES_out[9];

    genvar j;
    generate
        for (j=5; j <= 10; j = j + 1) begin
            assign AES_bypass[j] = first_round & counter < j-4;
        end 
    endgenerate


    //// register inputs ////
    // To keep changes to higher level to a minimum this loads all values at once
    // there is no apparent benefit or problem to it, though gradual loading would be more elegant
    // Changing should require minimum effort

    wire [127:0] rev_block_bytes [10:0];
    rev_col blk_bytes0(.in(block_bytes[1023:896]),.out(rev_block_bytes[0]));
    rev_col blk_bytes1(.in(block_bytes[895:768]),.out(rev_block_bytes[10]));
    rev_col blk_bytes2(.in(block_bytes[767:640]),.out(rev_block_bytes[9]));
    rev_col blk_bytes3(.in(block_bytes[639:512]),.out(rev_block_bytes[8]));
    rev_col blk_bytes4(.in(block_bytes[511:384]),.out(rev_block_bytes[7]));
    rev_col blk_bytes5(.in(block_bytes[383:256]),.out(rev_block_bytes[6]));
    rev_col blk_bytes6(.in(block_bytes[255:128]),.out(rev_block_bytes[5]));
    rev_col blk_bytes7(.in(block_bytes[127:0]),.out(rev_block_bytes[4]));
    assign rev_block_bytes[3] = 0;
    assign rev_block_bytes[2] = 0;
    assign rev_block_bytes[1] = 0;

    always @(posedge clk)
        if (~rstn)
            for (i=0; i< 11; i=i+1) begin
                blocks[i] = 0;
            end
        else if (start) begin
            blocks[4] = rev_block_bytes[4];  // Block 10 will shift into 0 -> it's the second block here
            blocks[5] = rev_block_bytes[5]; // Block 10 will be used as mixer input during operation
            blocks[6] = rev_block_bytes[6];
            blocks[7] = rev_block_bytes[7];
            blocks[8] = rev_block_bytes[8];
            blocks[9] = rev_block_bytes[9];
            blocks[10] = rev_block_bytes[10];
            blocks[0] = rev_block_bytes[0];

        end
    // Blocks will always shift after keygen is done
    // reg -> AES -> MUX -> next reg
    //                ^
        // something else |       
        else if (keygen_done && enable_operation && ~done) begin
            for (i=1; i < 5; i = i + 1) begin // blocks without AES bypass
                blocks[i] <= AES_out[i-1];
            end
            for (i=5; i <= 10; i = i + 1) begin // blocks without AES bypass
                blocks[i] <= AES_bypass[i] ? blocks[i-1] : AES_out[i-1];
            end
            // The zero block is a special case due to the preliminary rounds
            blocks[0] <= first_round ? blocks[10] : preliminary ? mixer_output : AES_out[9];
        end

    /////// Instantiation of AES modules //////////
    generate
        for (j = 0; j < 10; j = j + 1) begin
            aes_data AES_step(.i_clk(clk), .i_plain(blocks[j]), .o_cipher(AES_out[j]), .i_key_ram(keys[j]));
        end
    endgenerate

    //////// Instantiation of mixer ///////////
    // MUX for mixing 0 and 7
    assign mixer_output = counter == 6 ? blocks[10] ^ mix0buffer : blocks[10] ^ AES_out[9];

    //////// I/O logic ////////

    always @(posedge clk)
        if (~rstn)
            mem_address <= 0;
        else if (~preliminary && counter < 8 && enable_operation && ~done)
            mem_address <= mem_address + 1;

    rev_col out_rev(.in(blocks[0]), .out(scratch_write));
    assign request_write = counter < 8 & ~preliminary;

    assign done = mem_address == NUM_ROUNDS << 3;

endmodule
