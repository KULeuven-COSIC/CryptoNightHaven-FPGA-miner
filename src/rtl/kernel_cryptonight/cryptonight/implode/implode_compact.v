`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/16/2021 09:18:07 PM
// Design Name: 
// Module Name: implode_compact
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: TODO: test (especially with BRAM), max mem address logic
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module implode_compact #(parameter NUM_ROUNDS = 'h020) (
    input clk,
    input rstn,
    input start, 
    input[255:0] key_bytes,
    input[1023:0] block_bytes,
    output wire[31:0] max_mem_address,
    output reg[31:0] mem_address,
    input wire[127:0] scratch_read,
    output reg[1023:0] newstate,
    output done,
    input data_valid,
    output request_read
);

    //// Key part ////
    // copied from explode_compact
    reg[127:0] keys [9:0];
    reg keygen_done, started;

    wire[127:0] keygen_output, rev_keygen_output;
    wire keygen_available;

    aes_genkey_compact keygen(.clk(clk), .rstn(rstn), .start(start), .in0(key_bytes[127:0]), 
        .in1(key_bytes[255:128]), .key(keygen_output), .key_available(keygen_available));

        wire [127:0] rev_scratch_read;
        rev_col keyout(.in(keygen_output), .out(rev_keygen_output));
        rev_col read_rev(.in(scratch_read), .out(rev_scratch_read));

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
        localparam BRAM_delay = 3;
        reg[127:0] blocks [10:0]; // seven for the blocks, some extra for shifting to right keys
        reg[127:0] mix0buffer; // keep block 0 to mix with block 7
        // For AES module instantiation
        wire [127:0] rev_blocks[9:0], rev_AES_out[9:0], AES_out[9:0], rev_key[9:0], mixer_output;

        // Mux selection logic //
        reg postliminary; // Are we in the 16 last rounds? (yes this is not a word)
        reg first_round; // Are we in the first round?
        // Counters //
        reg[3:0] counter; // intra round counter
        reg[4:0] postliminary_round_counter; // counter to trigger preliminary, should trigger after counter = 7
        // different indexing for clarity
        wire AES_bypass [10:4]; // Bypass AES block when loading stuff at first

        wire enable_counter, reads_required, enable_block_loading, increment_memory, select_block_0_input;
        assign reads_required = keygen_done && ~done && ~postliminary;

        reg invalid_data; // this is 1 when data_valid is not important
        always @(posedge clk)
            if (~rstn)
                invalid_data <= 0;
        // data at 'ha must be valid for the first block, and at 6 for last block,
        // Do not assert invalid data if the counter may not be increased to
            // prevent mistakes
            else if (counter == 6 && enable_counter && reads_required)
                invalid_data <= 1;
        // Deassert when transferring to clock 'ha
            else if (counter == 9 && enable_counter && reads_required)
                invalid_data <= 0;

        // TODO I don't like these being wires, it may result in a critical path on the enable terminal
        assign enable_counter = (reads_required && (invalid_data || data_valid)) || postliminary;
        assign enable_block_loading = enable_counter;
        assign increment_memory = enable_counter && data_valid;
        reg request_read_keeper; // if data_valid comes late, keep request_read up
        always @(posedge clk)
            if (~rstn)
                request_read_keeper <= 0;
            else if (reads_required && counter >= 8)
                request_read_keeper <= 1;
            else if (reads_required && counter == 5 && enable_counter)
                request_read_keeper <= 0;
            else if (~reads_required)
                request_read_keeper <= 0;
        assign request_read = request_read_keeper;

        // Trigger start: need to wait a little bit longer after keygen done to let the memory be read properly
        reg start_blocks, counter_trigger;

        // wire used to load the output register
        reg last_round;

        //// control logic ////
        // keep track of regime: first, second or post
        reg[1:0] iterations; // update not yet in order
        always @(posedge clk)
            if (~rstn)
                iterations <= 0;
            else if ((NUM_ROUNDS << 3)-1 == mem_address && iterations < 2 && increment_memory)
                iterations <= iterations + 1;

        always @(posedge clk)
            if (~rstn)
                postliminary <= 0;
            else if (iterations == 2 && counter == 8)
                postliminary <= 1;
        // assign postliminary = iterations == 2; // This should probably be refactored sometime

        always @(posedge clk)
            if (~rstn) 
                counter <= 'ha;
            else if (enable_counter)
                counter <= (counter + 1) % 11; // An extra round is always needed for mixing

        always @(posedge clk)
            if (~rstn)
                first_round <= 1;
            else if (counter == 7) // everything after 6 is nonsense including extra clock periods
                first_round <= 0;

        always @(posedge clk)
            if (~rstn)
                postliminary_round_counter <= 0;
            else if (counter == 9 && ~first_round && postliminary && ~last_round)
                postliminary_round_counter <= postliminary_round_counter + 1;

        // mix buffer logic for the 0-7 mix
        always @(posedge clk)
            if (~rstn)
                mix0buffer <= 0;
            else if (counter == 'h9)
                mix0buffer <= AES_out[9];

        genvar j;
        generate
            for (j=4; j <= 10; j = j + 1) begin
                assign AES_bypass[j] = first_round & (counter < j-2 || counter == 'ha);
            end 
        endgenerate


            //// Memory logic ////
            always @(posedge clk)
                if (~rstn)
                    mem_address <= 0;
                else if (increment_memory)
                    mem_address <= (mem_address + 1) % (NUM_ROUNDS << 3);

            //// Block start logic
            always @(posedge clk)
                if (~rstn)
                    start_blocks <= 0;
                else if (~start_blocks && mem_address == BRAM_delay-2)
                    start_blocks <= 1;

            //// register inputs ////
            // To keep changes to higher level to a minimum this loads all values at once
            // there is no apparent benefit or problem to it, though gradual loading would be more elegant
            // Changing should require minimum effort    wire [127:0] rev_block_bytes [10:0];

            wire [127:0] rev_block_bytes [10:0];
            rev_col blk_bytes0(.in(block_bytes[1023:896]),.out(rev_block_bytes[10]));
            rev_col blk_bytes1(.in(block_bytes[895:768]),.out(rev_block_bytes[9]));
            rev_col blk_bytes2(.in(block_bytes[767:640]),.out(rev_block_bytes[8]));
            rev_col blk_bytes3(.in(block_bytes[639:512]),.out(rev_block_bytes[7]));
            rev_col blk_bytes4(.in(block_bytes[511:384]),.out(rev_block_bytes[6]));
            rev_col blk_bytes5(.in(block_bytes[383:256]),.out(rev_block_bytes[5]));
            rev_col blk_bytes6(.in(block_bytes[255:128]),.out(rev_block_bytes[4]));
            rev_col blk_bytes7(.in(block_bytes[127:0]),.out(rev_block_bytes[3]));
            assign rev_block_bytes[0] = 0;
            assign rev_block_bytes[1] = 0;
            assign rev_block_bytes[2] = 0;



            always @(posedge clk)
                if (~rstn)
                    for (i=0; i< 11; i=i+1) begin
                        blocks[i] = 0;
                    end
                else if (start) begin
                    blocks[3] = rev_block_bytes[3];  // Block 10 will shift into 0 -> it's the second block here
                    blocks[4] = rev_block_bytes[4];  // Block 10 will be used as mixer input during operation
                    blocks[5] = rev_block_bytes[5];
                    blocks[6] = rev_block_bytes[6];
                    blocks[7] = rev_block_bytes[7];
                    blocks[8] = rev_block_bytes[8];
                    blocks[9] = rev_block_bytes[9];
                    blocks[10] = rev_block_bytes[10];
                end
            // Blocks will always shift after keygen is done
            // reg -> AES -> MUX -> next reg
            //                ^
            // something else |       
                else if (enable_block_loading) begin
                    for (i=1; i < 4; i = i + 1) begin // blocks without AES bypass
                        blocks[i] <= AES_out[i-1];
                    end
                    for (i=4; i <= 10; i = i + 1) begin // blocks without AES bypass
                        blocks[i] <= AES_bypass[i] ? blocks[i-1] : AES_out[i-1];
                    end
                    // The zero block is a special case due to the preliminary rounds
                    // first_round -> shift input around
                    // else: mixer output with or without BRAM XOR
                    blocks[0] <= first_round ? blocks[10] ^ rev_scratch_read : mixer_output;
                end

            /////// Instantiation of AES modules //////////
            generate
                for (j = 0; j < 10; j = j + 1) begin
                    aes_data AES_step(.i_clk(clk), .i_plain(blocks[j]), .o_cipher(AES_out[j]), .i_key_ram(keys[j]));
                end
            endgenerate

            //////// Instantiation of mixer ///////////
            // MUX for mixing 0 and 7 and including scratch_read
            wire[127:0] intermediate_XOR;
            assign intermediate_XOR = postliminary ? blocks[10] : blocks[10] ^ rev_scratch_read;
            assign mixer_output = counter == 6 ? intermediate_XOR ^ mix0buffer : intermediate_XOR ^ AES_out[9];

            //// Output logic ////
            always @(posedge clk)
                if (~rstn)
                    last_round <= 0;
                else if (postliminary && postliminary_round_counter == 'h11 && counter == 0)
                    last_round <= 1;

            assign done = last_round && counter == 8;

            wire [127:0] intermediate_rev, new_state_append;
            rev_col new_statecol(.in(blocks[0]), .out(new_state_append));
            /* rev_bytes #(.SIZE(128)) new_staterev(.in(intermediate_rev), .out(new_state_append)); */

            always @(posedge clk)
                if (~rstn)
                    newstate <= 0;
                else if ((last_round || (postliminary && postliminary_round_counter == 'h11 && counter == 0)) && ~done) begin
                    newstate[1023:128] <= newstate[895:0];
                    newstate[127:0] <= new_state_append;
                end

            //// Max address logic ////
            assign max_mem_address = iterations == 0 ? 0 : iterations == 1 ? mem_address-1 : ~32'h0; 

            // for debugging
            wire [127:0] intermediate_blocks[9:0];
            rev_col rev_c0(.in(blocks[0]), .out(intermediate_blocks[0]));
            rev_bytes #(.SIZE(128)) rev0(.in(intermediate_blocks[0]), .out(rev_blocks[0]));
            rev_col rev_c1(.in(blocks[1]), .out(intermediate_blocks[1]));
            rev_bytes #(.SIZE(128)) rev1(.in(intermediate_blocks[1]), .out(rev_blocks[1]));
            rev_col rev_c2(.in(blocks[2]), .out(intermediate_blocks[2]));
            rev_bytes #(.SIZE(128)) rev2(.in(intermediate_blocks[2]), .out(rev_blocks[2]));
            rev_col rev_c3(.in(blocks[3]), .out(intermediate_blocks[3]));
            rev_bytes #(.SIZE(128)) rev3(.in(intermediate_blocks[3]), .out(rev_blocks[3]));
            rev_col rev_c4(.in(blocks[4]), .out(intermediate_blocks[4]));
            rev_bytes #(.SIZE(128)) rev4(.in(intermediate_blocks[4]), .out(rev_blocks[4]));
            rev_col rev_c5(.in(blocks[5]), .out(intermediate_blocks[5]));
            rev_bytes #(.SIZE(128)) rev5(.in(intermediate_blocks[5]), .out(rev_blocks[5]));
            rev_col rev_c6(.in(blocks[6]), .out(intermediate_blocks[6]));
            rev_bytes #(.SIZE(128)) rev6(.in(intermediate_blocks[6]), .out(rev_blocks[6]));
            rev_col rev_c7(.in(blocks[7]), .out(intermediate_blocks[7]));
            rev_bytes #(.SIZE(128)) rev7(.in(intermediate_blocks[7]), .out(rev_blocks[7]));
            rev_col rev_c8(.in(blocks[8]), .out(intermediate_blocks[8]));
            rev_bytes #(.SIZE(128)) rev8(.in(intermediate_blocks[8]), .out(rev_blocks[8]));
            rev_col rev_c9(.in(blocks[9]), .out(intermediate_blocks[9]));
            rev_bytes #(.SIZE(128)) rev9(.in(intermediate_blocks[9]), .out(rev_blocks[9]));
endmodule
