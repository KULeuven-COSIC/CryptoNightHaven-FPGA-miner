
`timescale 1 ns / 1 ps

module implode_axi #
    (
        // Users to add parameters here
        parameter NUM_ROUNDS = 'h20,
        parameter nonce_width = 7,
        parameter buffer_treshold1 = 8,
        parameter buffer_treshold2 = 16,

        // User parameters ends
        // Do not modify the parameters beyond this line

        // Burst Length. Supports 1, 2, 4, 8, 16, 32, 64, 128, 256 burst lengths
        parameter integer C_M_AXI_BURST_LEN	 =  16,
        // Width of Address Bus
        parameter integer C_M_AXI_ADDR_WIDTH =  64,
        // Width of Data Bus
        parameter integer C_M_AXI_DATA_WIDTH = 128
    )
    (
        // Users to add ports here
        input i_request_read,
        output [C_M_AXI_DATA_WIDTH-1:0] o_data,
        output o_data_valid,
        input [nonce_width-1:0] i_nonce,
        input i_nonce_valid,
        
        input wire [C_M_AXI_ADDR_WIDTH-1 : 0] axi_base_addr,
        // User ports ends
        // Do not modify the ports beyond this line

        // Global Clock Signal.
        input wire  M_AXI_ACLK,
        // Global Reset Singal. This Signal is Active Low
        input wire  M_AXI_ARESETN,
        // Read address. This signal indicates the initial
        // address of a read burst transaction.
        output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_ARADDR,
        // Burst length. The burst length gives the exact number of transfers in a burst
        output wire [7 : 0] M_AXI_ARLEN,
        // Burst size. This signal indicates the size of each transfer in the burst
        output wire [2 : 0] M_AXI_ARSIZE,
        // Burst type. The burst type and the size information,
        // determine how the address for each transfer within the burst is calculated.
        output wire [1 : 0] M_AXI_ARBURST,
        // Write address valid. This signal indicates that
        // the channel is signaling valid read address and control information
        output wire  M_AXI_ARVALID,
        // Read address ready. This signal indicates that
        // the slave is ready to accept an address and associated control signals
        input wire  M_AXI_ARREADY,
        // Master Read Data
        input wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_RDATA,
        // Read last. This signal indicates the last transfer in a read burst
        input wire  M_AXI_RLAST,
        // Read valid. This signal indicates that the channel
        // is signaling the required read data.
        input wire  M_AXI_RVALID,
        // Read ready. This signal indicates that the master can
        // accept the read data and response information.
        output wire  M_AXI_RREADY
    );

    reg [C_M_AXI_ADDR_WIDTH-1 : 0] axi_base_addr_r;
    always @(posedge M_AXI_ACLK)
        axi_base_addr_r <= axi_base_addr;

    // function called clogb2 that returns an integer which has the
    // value of the ceiling of the log base 2.
    function automatic integer clogb2 (input integer bit_depth);
        begin
            for(clogb2=0; bit_depth>0; clogb2=clogb2+1)
                bit_depth = bit_depth >> 1;
        end
    endfunction

    // C_TRANSACTIONS_NUM is the width of the index counter for
    // number of write or read transaction.
    localparam integer C_TRANSACTIONS_NUM = clogb2(C_M_AXI_BURST_LEN-1);
    localparam integer C_DATA_BYTE_NUM = clogb2(C_M_AXI_DATA_WIDTH/8);
    localparam integer addr_width = clogb2(8*NUM_ROUNDS)-1;
    localparam integer max_addr = NUM_ROUNDS*8*'d16;

    // AXI4LITE signals
    //AXI4 internal temp signals
    reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
    reg  	axi_arvalid;
    reg  	axi_rready;
    //size of C_M_AXI_BURST_LEN length burst in bytes
    wire [C_TRANSACTIONS_NUM+C_DATA_BYTE_NUM : 0] 	burst_size_bytes;
    //The burst counters are used to track the number of burst transfers of C_M_AXI_BURST_LEN burst length needed to transfer 2^C_MASTER_LENGTH bytes of data.
    reg  	start_single_burst_read;
    //Interface response error flags
    wire  	rnext;
    wire data_buffer_empty, data_buffer_full, data_buffer_pop, data_buffer_push;
    wire [C_M_AXI_DATA_WIDTH-1:0] data_buffer_out, data_buffer_in;
    reg [clogb2(C_M_AXI_BURST_LEN-1):0] FIFO_free_spots, real_FIFO_contents, burst_counter;
    wire [addr_width+3:0] max_burst_len;
    reg [nonce_width-1:0] nonce;
    reg nonce_arrived, data_valid_reg;

    // Add user logic here
    assign burst_size_bytes = C_M_AXI_DATA_WIDTH / 8 * (burst_counter + 1);
    assign max_burst_len = max_addr - M_AXI_ARADDR[addr_width+3:0] - 'h10;

    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0)
            nonce <= 0;
        else if (i_nonce_valid)
            nonce <= i_nonce;

    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0)
            nonce_arrived <= 0;
        else
            nonce_arrived <= i_nonce_valid;

    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0)
            data_valid_reg <= 0;
        else
            data_valid_reg <= data_buffer_pop && ~data_buffer_empty;

    xpm_fifo_sync #(
        .CASCADE_HEIGHT(0),        // DECIMAL
        .DOUT_RESET_VALUE("0"),    // String
        .ECC_MODE("no_ecc"),       // String
        .FIFO_MEMORY_TYPE("auto"), // String
        .FIFO_READ_LATENCY(1),     // DECIMAL
        .FIFO_WRITE_DEPTH(C_M_AXI_BURST_LEN),     // DECIMAL
        .FULL_RESET_VALUE(0),      // DECIMAL
        .PROG_EMPTY_THRESH(10),    // DECIMAL
        .PROG_FULL_THRESH(10),     // DECIMAL
        .RD_DATA_COUNT_WIDTH(5),   // DECIMAL
        .READ_DATA_WIDTH(C_M_AXI_DATA_WIDTH),     // DECIMAL
        .READ_MODE("std"),         // String
        .SIM_ASSERT_CHK(1),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES("0000"), // String
        .WAKEUP_TIME(0),           // DECIMAL
        .WRITE_DATA_WIDTH(C_M_AXI_DATA_WIDTH),    // DECIMAL
        .WR_DATA_COUNT_WIDTH(5)    // DECIMAL
    )
    data_buffer (
        .dout(data_buffer_out),    // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
        // when reading the FIFO.

        .empty(data_buffer_empty), // 1-bit output: Empty Flag: When asserted, this signal indicates that the
        // FIFO is empty. Read requests are ignored when the FIFO is empty,
        // initiating a read while empty is not destructive to the FIFO.

        .full(data_buffer_full),   // 1-bit output: Full Flag: When asserted, this signal indicates that the
        // FIFO is full. Write requests are ignored when the FIFO is full,
        // initiating a write when the FIFO is full is not destructive to the
        // contents of the FIFO.

        .din(data_buffer_in),      // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
        // writing the FIFO.

        .rd_en(data_buffer_pop),   // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
        // signal causes data (on dout) to be read from the FIFO. Must be held
        // active-low when rd_rst_busy is active high.

        .rst(~M_AXI_ARESETN),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
        // unstable at the time of applying reset, but reset must be released only
        // after the clock(s) is/are stable.
        .wr_clk(M_AXI_ACLK),                  // 1-bit input: Write clock: Used for write operation. wr_clk must be a
        // free running clock.

        .wr_en(data_buffer_push)   // 1-bit input: Write Enable: If the FIFO is not full, asserting this
        // signal causes data (on din) to be written to the FIFO Must be held
        // active-low when rst or wr_rst_busy or rd_rst_busy is active high
    );

    reg data_buffer_pop_reg; // to deal with empty FIFO
    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0)
            data_buffer_pop_reg <= 0;
        else if (data_buffer_empty && i_request_read) // this remembers a pop if the data buffer is empty
            data_buffer_pop_reg <= 1;
        else if (~data_buffer_empty) // but if it is not empty it is non-functional
            data_buffer_pop_reg <= 0;
    assign data_buffer_in = M_AXI_RDATA;
    assign data_buffer_push = rnext; // only push if next read is requested
    assign data_buffer_pop = i_request_read || data_buffer_pop_reg;
    assign o_data = data_buffer_out;
    assign o_data_valid = data_valid_reg;

    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0)
            real_FIFO_contents <= 0;
        else case ({data_buffer_push && ~data_buffer_full, data_buffer_pop && ~data_buffer_empty})
            2'b10: real_FIFO_contents <= real_FIFO_contents + 1;
            2'b01: real_FIFO_contents <= real_FIFO_contents - 1;
            default:  real_FIFO_contents <= real_FIFO_contents;
        endcase

    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0)
            // FIFO is initialized to empty
            FIFO_free_spots <= 'h0;
        else if (i_nonce_valid)
            FIFO_free_spots <= ~'h0;
        else if (start_single_burst_read)
            FIFO_free_spots <= data_buffer_pop && ~data_buffer_empty;
        else if (data_buffer_pop && ~data_buffer_empty)
            FIFO_free_spots <= FIFO_free_spots + 1;
        else
            FIFO_free_spots <= FIFO_free_spots;

    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0)
            burst_counter <= 0;
        else if (axi_arvalid)
            burst_counter <= burst_counter;
        else if (data_buffer_pop)
            burst_counter <= (max_burst_len >> 4 > FIFO_free_spots + 1) ? FIFO_free_spots + 1 : max_burst_len >> 4;
        else
            burst_counter <= (max_burst_len >> 4 > FIFO_free_spots + 1) ? FIFO_free_spots : max_burst_len >> 4;

    wire start_read_condition;
    reg start_single_burst_read_pulse, rlast_arrived;
    
    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0)
            rlast_arrived <= 1'b1;
        else if (axi_arvalid)
            rlast_arrived <= 1'b0;
        else if (M_AXI_RLAST)
            rlast_arrived <= 1'b1;
        else
            rlast_arrived <= rlast_arrived;
    
    assign start_read_condition = rlast_arrived && ((FIFO_free_spots > buffer_treshold1 && M_AXI_ARREADY) || (FIFO_free_spots > buffer_treshold2) || (FIFO_free_spots == max_burst_len >> 4));

    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0)
            start_single_burst_read_pulse <= 0;
        else
            start_single_burst_read_pulse <= start_read_condition;
    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0)
            start_single_burst_read <= 0;
        else
            start_single_burst_read <= start_read_condition && ~start_single_burst_read_pulse;
    // User logic ends


    //Read Address (AR)
    assign M_AXI_ARADDR	= axi_base_addr_r + axi_araddr;
    //Burst LENgth is number of transaction beats, minus 1
    assign M_AXI_ARLEN	= burst_counter;
    //Size should be C_M_AXI_DATA_WIDTH, in 2^n bytes, otherwise narrow bursts are used
    assign M_AXI_ARSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
    //INCR burst type is usually used, except for keyhole bursts
    assign M_AXI_ARBURST	= 2'b01;
    assign M_AXI_ARVALID	= axi_arvalid;
    //Read and Read Response (R)
    assign M_AXI_RREADY	= axi_rready;

    //----------------------------
    //Read Address Channel
    //----------------------------

    //The Read Address Channel (AW) provides a similar function to the
    //Write Address channel- to provide the tranfer qualifiers for the burst.

    //In this example, the read address increments in the same
    //manner as the write address channel.

    always @(posedge M_AXI_ACLK)
    begin

        if (M_AXI_ARESETN == 0 )
        begin
            axi_arvalid <= 1'b0;
        end
        // If previously not valid , start next transaction
        else if (~axi_arvalid && start_single_burst_read)
        begin
            axi_arvalid <= 1'b1;
        end
        else if (M_AXI_ARREADY && axi_arvalid)
        begin
            axi_arvalid <= 1'b0;
        end
        else
            axi_arvalid <= axi_arvalid;
    end


    // Next address after ARREADY indicates previous address acceptance
    wire [addr_width+3:0] helper_addr_wire;
    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0)
            axi_araddr <= 'b0;
        else if (nonce_arrived)
            axi_araddr <= {{C_M_AXI_ADDR_WIDTH-addr_width-nonce_width-4{1'b0}}, nonce[nonce_width-1:0], {addr_width+4{1'b0}}};
        else if (M_AXI_ARREADY && axi_arvalid)
            axi_araddr <= {{C_M_AXI_ADDR_WIDTH-addr_width-nonce_width-4{1'b0}}, nonce[nonce_width-1:0], helper_addr_wire};
        else
            axi_araddr <= axi_araddr;
    assign helper_addr_wire = (axi_araddr + burst_size_bytes) % max_addr;

    //--------------------------------
    //Read Data (and Response) Channel
    //--------------------------------

    // Forward movement occurs when the channel is valid and ready
    assign rnext = M_AXI_RVALID && axi_rready;

    /*
    The Read Data channel returns the results of the read request

    In this example the data checker is always able to accept
    more data, so no need to throttle the RREADY signal
    */
    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0 )
            axi_rready <= 1'b0;
        // accept/acknowledge rdata/rresp with axi_rready by the master
        // when M_AXI_RVALID is asserted by slave
        else
            axi_rready <= ~data_buffer_full;
endmodule
