
`timescale 1 ns / 1 ps

module explode_axi #
    (
        // Users to add parameters here
        parameter NUM_ROUNDS = 'h20,
        parameter nonce_width = 7,
        parameter burst_counter_treshold1 = 8,
        parameter burst_counter_treshold2 = 32,
        // User parameters ends
        
        // Do not modify the parameters beyond this line
        // Burst Length. Supports 1, 2, 4, 8, 16, 32, 64, 128, 256 burst lengths
        parameter integer C_M_AXI_BURST_LEN	 =  16, // this is the maximum burst length
        // Width of Address Bus
        parameter integer C_M_AXI_ADDR_WIDTH =  64,
        // Width of Data Bus
        parameter integer C_M_AXI_DATA_WIDTH = 128
    )
    (
        // Users to add ports here
        input [C_M_AXI_DATA_WIDTH-1:0] i_data,
        input i_data_valid,
        input i_nonce_valid,
        input [nonce_width-1:0] i_nonce,
        output o_buffer_full,
        output o_done,

        input wire [C_M_AXI_ADDR_WIDTH-1 : 0] axi_base_addr,

        // User ports ends
        // Global Clock Signal.
        input wire  M_AXI_ACLK,
        // Global Reset Singal. This Signal is Active Low
        input wire  M_AXI_ARESETN,
        // Master Interface Write Address
        output wire [C_M_AXI_ADDR_WIDTH-1 : 0] M_AXI_AWADDR,
        // Burst length. The burst length gives the exact number of transfers in a burst
        output wire [7 : 0] M_AXI_AWLEN,
        // Burst size. This signal indicates the size of each transfer in the burst
        output wire [2 : 0] M_AXI_AWSIZE,
        // Burst type. The burst type and the size information,
        // determine how the address for each transfer within the burst is calculated.
        output wire [1 : 0] M_AXI_AWBURST,
        // Write address valid. This signal indicates that
        // the channel is signaling valid write address and control information.
        output wire  M_AXI_AWVALID,
        // Write address ready. This signal indicates that
        // the slave is ready to accept an address and associated control signals
        input wire  M_AXI_AWREADY,
        // Master Interface Write Data.
        output wire [C_M_AXI_DATA_WIDTH-1 : 0] M_AXI_WDATA,
        // Write strobes. This signal indicates which byte
        // lanes hold valid data. There is one write strobe
        // bit for each eight bits of the write data bus.
        output wire [C_M_AXI_DATA_WIDTH/8-1 : 0] M_AXI_WSTRB,
        // Write last. This signal indicates the last transfer in a write burst.
        output wire  M_AXI_WLAST,
        // Write valid. This signal indicates that valid write
        // data and strobes are available
        output wire  M_AXI_WVALID,
        // Write ready. This signal indicates that the slave
        // can accept the write data.
        input wire  M_AXI_WREADY,
        // Write response valid. This signal indicates that the
        // channel is signaling a valid write response.
        input wire  M_AXI_BVALID,
        // Response ready. This signal indicates that the master
        // can accept a write response.
        output wire  M_AXI_BREADY
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

    // Burst length for transactions, in C_M_AXI_DATA_WIDTHs.
    // Non-2^n lengths will eventually cause bursts across 4K address boundaries.
    localparam integer C_MASTER_LENGTH	= 12;
    // total number of burst transfers is master length divided by burst length and burst size
    localparam integer C_NO_BURSTS_REQ = C_MASTER_LENGTH-clogb2((C_M_AXI_BURST_LEN*C_M_AXI_DATA_WIDTH/8)-1);
    // Example State machine to initialize counter, initialize write transactions,
    // initialize read transactions and comparison of read data with the
    // written data words.

    // AXI4LITE signals
    //AXI4 internal temp signals
    reg [C_M_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
    reg  	axi_awvalid;
    wire [C_M_AXI_DATA_WIDTH-1 : 0] 	axi_wdata;
    /* reg  	axi_wlast; */
    wire axi_wlast;
    reg  	axi_wvalid;
    reg  	axi_bready;
    //size of C_M_AXI_BURST_LEN length burst in bytes
    wire [C_TRANSACTIONS_NUM+C_DATA_BYTE_NUM : 0]   burst_size_bytes;
    wire [addr_width+3:0] max_burst_len;
    assign max_burst_len = max_addr - M_AXI_AWADDR[addr_width+3:0] - 'h10;
    //The burst counters are used to track the number of burst transfers of C_M_AXI_BURST_LEN burst length needed to transfer 2^C_MASTER_LENGTH bytes of data.
    //Interface response error flags
    wire  	wnext;

    reg [clogb2(C_M_AXI_BURST_LEN-1):0] burst_counter, FIFO_contents, burst_tracker, real_FIFO_contents; // determine the amount of beats per burst and the amount of data left in the FIFO
    // I/O Connections assignments

    //I/O Connections. Write Address (AW)
    //The AXI address is a concatenation of the target base address + active offset range
    assign M_AXI_AWADDR	= axi_base_addr_r + axi_awaddr;
    //Burst LENgth is number of transaction beats, minus 1
    // assign M_AXI_AWLEN	= C_M_AXI_BURST_LEN - 1;
    assign M_AXI_AWLEN = burst_counter;
    //Size should be C_M_AXI_DATA_WIDTH, in 2^SIZE bytes, otherwise narrow bursts are used
    assign M_AXI_AWSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
    //INCR burst type is usually used, except for keyhole bursts
    assign M_AXI_AWBURST	= 2'b01;
    assign M_AXI_AWVALID	= axi_awvalid;
    //Write Data(W)
    assign M_AXI_WDATA	= axi_wdata;
    //All bursts are complete and aligned in this example
    assign M_AXI_WSTRB	= {(C_M_AXI_DATA_WIDTH/8){1'b1}};
    assign M_AXI_WLAST	= axi_wlast;
    assign M_AXI_WVALID	= axi_wvalid;
    //Write Response (B)
    assign M_AXI_BREADY	= axi_bready;

    // User signals
    wire data_buffer_empty, data_buffer_full, data_buffer_pop, data_buffer_push;
    wire [C_M_AXI_DATA_WIDTH-1:0] data_buffer_out, data_buffer_in;
    reg [nonce_width-1:0] nonce;
    wire start_single_burst_write;
    reg start_single_burst_write_reg, start_single_burst_write_pulse, start_single_burst_write_reg_late;
    reg nonce_arrived;
    assign burst_size_bytes =  C_M_AXI_DATA_WIDTH / 8  * (burst_counter + 1);

    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0)
            nonce_arrived <= 0;
        else
            nonce_arrived <= i_nonce_valid;

    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0)
            nonce <= 0;
        else if (i_nonce_valid)
            nonce <= i_nonce;

    //--------------------
    //Write Address Channel
    //--------------------

    // The purpose of the write address channel is to request the address and
    // command information for the entire transaction.  It is a single beat
    // of information.

    // The AXI4 Write address channel in this example will continue to initiate
    // write commands as fast as it is allowed by the slave/interconnect.
    // The address will be incremented on each accepted address transaction,
    // by burst_size_byte to point to the next address.

    always @(posedge M_AXI_ACLK)
    begin

        if (M_AXI_ARESETN == 0)
        begin
            axi_awvalid <= 1'b0;
        end
        // If previously not valid , start next transaction
        else if (~axi_awvalid && start_single_burst_write_reg)
        begin
            axi_awvalid <= 1'b1;
        end
        /* Once asserted, VALIDs cannot be deasserted, so axi_awvalid
        must wait until transaction is accepted */
        else if (M_AXI_AWREADY && axi_awvalid)
        begin
            axi_awvalid <= 1'b0;
        end
        else
            axi_awvalid <= axi_awvalid;
    end


    // Next address after AWREADY indicates previous address acceptance
    wire [addr_width+3:0] helper_addr_wire;
    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0)
            axi_awaddr <= 0;
        else if (nonce_arrived)
            axi_awaddr <= {{C_M_AXI_ADDR_WIDTH-addr_width-nonce_width-4{1'b0}}, nonce[nonce_width-1:0], {addr_width+4{1'b0}}};
        else if (M_AXI_AWREADY && axi_awvalid)
            axi_awaddr <= {{C_M_AXI_ADDR_WIDTH-addr_width-nonce_width-4{1'b0}}, nonce[nonce_width-1:0], helper_addr_wire};
        else
            axi_awaddr <= axi_awaddr;
    end
    assign helper_addr_wire = (axi_awaddr + burst_size_bytes) % max_addr;


    //--------------------
    //Write Data Channel
    //--------------------

    //The write data will continually try to push write data across the interface.

    //The amount of data accepted will depend on the AXI slave and the AXI
    //Interconnect settings, such as if there are FIFOs enabled in interconnect.

    //Note that there is no explicit timing relationship to the write address channel.
    //The write channel has its own throttling flag, separate from the AW channel.

    //Synchronization between the channels must be determined by the user.

    //The simpliest but lowest performance would be to only issue one address write
    //and write data burst at a time.

    //In this example they are kept in sync by using the same address increment
    //and burst sizes. Then the AW and W channels have their transactions measured
    //with threshold counters as part of the user logic, to make sure neither
    //channel gets too far ahead of each other.

    //Forward movement occurs when the write channel is valid and ready

    assign wnext = M_AXI_WREADY & axi_wvalid;

    // WVALID logic, similar to the axi_awvalid always block above
    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0)
            axi_wvalid <= 1'b0;
        // If previously not valid, start next transaction
        else if (~axi_wvalid && start_single_burst_write_reg)
            axi_wvalid <= 1'b1;
        /* If WREADY and too many writes, throttle WVALID
        Once asserted, VALIDs cannot be deasserted, so WVALID
        must wait until burst is complete with WLAST */
        else if (wnext && axi_wlast)
            axi_wvalid <= 1'b0;
        else
            axi_wvalid <= axi_wvalid;
    end

    //WLAST generation on the MSB of a counter underflow
    // WVALID logic, similar to the axi_awvalid always block above
    /* always @(posedge M_AXI_ACLK) */
    /* begin */
    /*     if (M_AXI_ARESETN == 0) */
    /*     begin */
    /*         axi_wlast <= 1'b0; */
    /*     end */
    /*     // axi_wlast is asserted when the write index */
    /*     // count reaches the penultimate count to synchronize */
    /*     // with the last write data when write_index is b1111 */
    /*     // else if (&(write_index[C_TRANSACTIONS_NUM-1:1])&& ~write_index[0] && wnext) */
    /*     else if (((write_index == C_M_AXI_BURST_LEN-2 && C_M_AXI_BURST_LEN >= 2) && wnext) || (C_M_AXI_BURST_LEN == 1 )) */
    /*     begin */
    /*         axi_wlast <= 1'b1; */
    /*     end */
    /*     // Deassrt axi_wlast when the last write data has been */
    /*     // accepted by the slave with a valid response */
    /*     else if (wnext) */
    /*         axi_wlast <= 1'b0; */
    /*     else if (axi_wlast && C_M_AXI_BURST_LEN == 1) */
    /*         axi_wlast <= 1'b0; */
    /*     else */
    /*         axi_wlast <= axi_wlast; */
    /* end */
    reg bvalid_arrived;
    assign axi_wlast = burst_tracker == 0 && axi_wvalid && ~bvalid_arrived;


    /* Burst length counter. Uses extra counter register bit to indicate terminal
    count to reduce decode logic */
    /* always @(posedge M_AXI_ACLK) */
    /* begin */
    /*     if (M_AXI_ARESETN == 0 || init_txn_pulse == 1'b1 || start_single_burst_write == 1'b1) */
    /*     begin */
    /*         write_index <= 0; */
    /*     end */
    /*     else if (wnext && (write_index != C_M_AXI_BURST_LEN-1)) */
    /*     begin */
    /*         write_index <= write_index + 1; */
    /*     end */
    /*     else */
    /*         write_index <= write_index; */
    /* end */


    /* Write Data Generator
    Data pattern is only a simple incrementing count from 0 for each burst  */
    /* always @(posedge M_AXI_ACLK) */
    /*     if (M_AXI_ARESETN == 0) */
    /*         axi_wdata <= 'b0; */
    /*     else */
    /*         axi_wdata <= data_buffer_out; */
    assign axi_wdata = data_buffer_out;


    //----------------------------
    //Write Response (B) Channel
    //----------------------------

    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0)
            axi_bready <= 1'b0;
       else
            axi_bready <= 1'b1;

    // Add user logic here

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
        .READ_DATA_WIDTH(128),     // DECIMAL
        .READ_MODE("std"),         // String
        .SIM_ASSERT_CHK(1),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES("0000"), // String
        .WAKEUP_TIME(0),           // DECIMAL
        .WRITE_DATA_WIDTH(128),    // DECIMAL
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


    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0)
            bvalid_arrived <= 1'b1;
        else if (axi_awvalid)
            bvalid_arrived <= 1'b0;
        else if (M_AXI_BVALID)
            bvalid_arrived <= 1'b1;
        else
            bvalid_arrived <= bvalid_arrived;

    assign start_single_burst_write = bvalid_arrived && burst_tracker == 0 && ((burst_counter > burst_counter_treshold1 && M_AXI_AWREADY) || (burst_counter > burst_counter_treshold2) || (burst_counter == max_burst_len >> 4)); // this is up for debate: the idea is that if the interface has multiple simultaneous requests more data can be buffered and then issued in a larger burst.

    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0)
            start_single_burst_write_pulse <= 0;
        else
            start_single_burst_write_pulse <= start_single_burst_write;

    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0) begin
            start_single_burst_write_reg <= 1'b0;
            start_single_burst_write_reg_late <= 1'b0;
        end
        else begin
            start_single_burst_write_reg <= ~start_single_burst_write_pulse && start_single_burst_write;
            start_single_burst_write_reg_late <= start_single_burst_write_reg;
        end

    assign data_buffer_pop = (start_single_burst_write_reg || wnext) && ~axi_wlast;
    assign data_buffer_push = i_data_valid;
    assign data_buffer_in = i_data;
    assign o_buffer_full = data_buffer_full;

    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0)
            burst_counter <= 0;
        else if (data_buffer_push && ~axi_awvalid)
            burst_counter <= (max_burst_len >> 4 > FIFO_contents + 1) ? FIFO_contents + 1 : max_burst_len >> 4;
        else if (~axi_awvalid)
            burst_counter <= (max_burst_len >> 4 > FIFO_contents + 1) ? FIFO_contents : max_burst_len >> 4;
        else
        /* else if (axi_awvalid) // if awvalid control info cannot be changed anymore */
            burst_counter <= burst_counter;

    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0)
            burst_tracker <= 0;
        else if (~axi_wlast) case ({axi_awvalid, axi_wvalid, M_AXI_WREADY})
            3'b100: burst_tracker <= burst_counter; // if awvalid then reset burst_tracker
            3'b101: burst_tracker <= burst_counter; // if awvalid then reset burst_tracker
            3'b110: burst_tracker <= burst_counter; // if awvalid then reset burst_tracker
            3'b011: burst_tracker <= burst_tracker - 1; // if a new write happens decrement
            3'b111: burst_tracker <= burst_counter - 1; // if the first write happens at the same time as the awvalid transaction then reset and decrement immediately
            default: burst_tracker <= burst_tracker;
        endcase

    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0)
            FIFO_contents <= 0;
        else if (axi_awvalid) // new transaction is accepted (don't wait for a response before loading FIFO)
            FIFO_contents <= i_data_valid; // this reset prevents "overlapping" write transactions
    /* else case({data_buffer_push, data_buffer_pop}) */
    /*     2'b10: FIFO_contents <= FIFO_contents + 1; */
    /*     2'b01: FIFO_contents <= FIFO_contents - 1; */
    /*     default: FIFO_contents <= FIFO_contents; */
        /* endcase */
        else if (data_buffer_push)
            FIFO_contents <= FIFO_contents + 1;
        else
            FIFO_contents <= FIFO_contents;

    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0)
            real_FIFO_contents <= 0;
        else case({data_buffer_push, data_buffer_pop})
            2'b10: real_FIFO_contents <= real_FIFO_contents + 1;
            2'b01: real_FIFO_contents <= real_FIFO_contents - 1;
            default: real_FIFO_contents <= real_FIFO_contents;
        endcase

    reg done_reg;
    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0)
            done_reg <= 0;
        else if (data_buffer_empty && M_AXI_BVALID)
            done_reg <= 1;
        else if (done_reg)
            done_reg <= 0;
    assign o_done = done_reg; // we're only really done once the buffer is empty and we get confirmation and explode signals it's done
    // User logic ends

endmodule
