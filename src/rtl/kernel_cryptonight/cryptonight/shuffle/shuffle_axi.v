
`timescale 1 ns / 1 ps

module shuffle_axi #
    (
        parameter integer INT_ADDR_WIDTH     =  32,

        // Burst Length. Supports 1, 2, 4, 8, 16, 32, 64, 128, 256 burst lengths
        parameter integer C_M_AXI_BURST_LEN	 =   1,
        // Width of Address Bus
        parameter integer C_M_AXI_ADDR_WIDTH =  64,
        // Width of Data Bus
        parameter integer C_M_AXI_DATA_WIDTH = 128
    )
    (
        // Users to add ports here
        input wire i_first_read,
        input wire [INT_ADDR_WIDTH-1:0] i_r1_addr,
        output wire [C_M_AXI_DATA_WIDTH-1:0] o_r1_data,
        input wire i_r1_request,
        output wire o_r1_valid,
        input wire [INT_ADDR_WIDTH-1:0] i_r2_addr,
        output wire [C_M_AXI_DATA_WIDTH-1:0] o_r2_data,
        input wire i_r2_request,
        output wire o_r2_valid,
        input wire [INT_ADDR_WIDTH-1:0] i_r3_addr,
        output wire [C_M_AXI_DATA_WIDTH-1:0] o_r3_data,
        input wire i_r3_request,
        output wire o_r3_valid,

        input wire [INT_ADDR_WIDTH-1:0] i_w1_addr,
        input wire [C_M_AXI_DATA_WIDTH-1:0] i_w1_data,
        input wire i_w1_request,
        input wire [INT_ADDR_WIDTH-1:0] i_w2_addr,
        input wire [C_M_AXI_DATA_WIDTH-1:0] i_w2_data,
        input wire i_w2_request,
        input wire [INT_ADDR_WIDTH-1:0] i_w3_addr,
        input wire [C_M_AXI_DATA_WIDTH-1:0] i_w3_data,
        input wire i_w3_request,

        input wire [INT_ADDR_WIDTH-1 : 0] axi_base_addr,
        // User ports ends

        // Do not modify the ports beyond this line

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
        // Write response. This signal indicates the status of the write transaction.
        input wire [1 : 0] M_AXI_BRESP,
        // Write response valid. This signal indicates that the
        // channel is signaling a valid write response.
        input wire  M_AXI_BVALID,
        // Response ready. This signal indicates that the master
        // can accept a write response.
        output wire  M_AXI_BREADY,
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
        // Read response. This signal indicates the status of the read transfer
        input wire [1 : 0] M_AXI_RRESP,
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
    function integer clogb2 (input integer bit_depth);
        begin
            for(clogb2=0; bit_depth>0; clogb2=clogb2+1)
                bit_depth = bit_depth >> 1;
        end
    endfunction

    // C_TRANSACTIONS_NUM is the width of the index counter for
    // number of write or read transaction.
    localparam integer C_TRANSACTIONS_NUM = clogb2(C_M_AXI_BURST_LEN-1);

    // Burst length for transactions, in C_M_AXI_DATA_WIDTHs.
    // Non-2^n lengths will eventually cause bursts across 4K address boundaries.
    localparam integer C_MASTER_LENGTH	= 12; // what is this?
    // total number of burst transfers is master length divided by burst length and burst size
    // localparam integer C_NO_BURSTS_REQ = C_MASTER_LENGTH-clogb2((C_M_AXI_BURST_LEN*C_M_AXI_DATA_WIDTH/8)-1);
    localparam integer C_NO_BURSTS_REQ = 0;
    // Example State machine to initialize counter, initialize write transactions,
    // initialize read transactions and comparison of read data with the
    // written data words.

    // User data
    reg [2:0] rselect, wselect;
    wire wnext, rnext;
    wire [C_M_AXI_DATA_WIDTH-1:0] wdata; 
    reg [C_M_AXI_DATA_WIDTH-1:0] rdata;
    wire [31:0] waddr, raddr;
 
    // AXI4LITE signals
    //AXI4 internal temp signals
    reg [INT_ADDR_WIDTH-1 : 0] 	axi_awaddr;
    reg  	axi_awvalid;
    reg [C_M_AXI_DATA_WIDTH-1 : 0] 	axi_wdata;
    reg  	axi_wlast;
    reg  	axi_wvalid;
    reg  	axi_bready;
    reg [INT_ADDR_WIDTH-1 : 0] 	axi_araddr;
    reg  	axi_arvalid;
    reg  	axi_rready;
    //Interface response error flags
    wire  	write_resp_error;
    wire  	read_resp_error;

    // User variables
    reg w_buffer_available, r_buffer_available;
    reg [2:0] w_buffer_available_bus, r_buffer_available_bus;

    //I/O Connections. Write Address (AW)
    //The AXI address is a concatenation of the target base address + active offset range
    assign M_AXI_AWADDR	= axi_base_addr_r + {{C_M_AXI_ADDR_WIDTH-INT_ADDR_WIDTH{1'b0}},axi_awaddr};
    //Burst LENgth is number of transaction beats, minus 1
    assign M_AXI_AWLEN	= C_M_AXI_BURST_LEN - 1;
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
    //Read Address (AR)
    assign M_AXI_ARADDR	= axi_base_addr_r + {{C_M_AXI_ADDR_WIDTH-INT_ADDR_WIDTH{1'b0}},axi_araddr};
    //Burst LENgth is number of transaction beats, minus 1
    assign M_AXI_ARLEN	= C_M_AXI_BURST_LEN - 1;
    //Size should be C_M_AXI_DATA_WIDTH, in 2^n bytes, otherwise narrow bursts are used
    assign M_AXI_ARSIZE	= clogb2((C_M_AXI_DATA_WIDTH/8)-1);
    //INCR burst type is usually used, except for keyhole bursts
    assign M_AXI_ARBURST	= 2'b01;
    assign M_AXI_ARQOS	= 4'h0;
    assign M_AXI_ARVALID = axi_arvalid;
    //Read and Read Response (R)
    assign M_AXI_RREADY	= axi_rready;

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
            axi_awvalid <= 1'b0;
        // if new address is available assert valid signal and the corresponding buffer is not empty
        else if (wnext && w_buffer_available)
            axi_awvalid <= 1'b1;
        /* Once asserted, VALIDs cannot be deasserted, so axi_awvalid
        must wait until transaction is accepted */
        else if (M_AXI_AWREADY && axi_awvalid)
            axi_awvalid <= 1'b0;
        else
            axi_awvalid <= axi_awvalid;
    end


    // Next address after AWREADY indicates previous address acceptance
    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0)
        begin
            axi_awaddr <= 'b0;
        end
        else if (~axi_awvalid && wnext && w_buffer_available)
        begin
            axi_awaddr <= waddr;
        end
        else
            axi_awaddr <= axi_awaddr;
    end


    //--------------------
    //Write Data Channel
    //--------------------
    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0)
            axi_wvalid <= 1'b0;
        // If previously not valid, start next transaction
        else if (wnext && w_buffer_available)
            axi_wvalid <= 1'b1;
        else if (M_AXI_WREADY && axi_wvalid  && axi_wlast)
            axi_wvalid <= 1'b0;
        else
            axi_wvalid <= axi_wvalid;
    end


    // WLAST generation on the MSB of a counter underflow
    // WVALID logic, similar to the axi_awvalid always block above
    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0)
            axi_wlast <= 1'b0;
        else if (wnext && w_buffer_available) // Burst length = 1
            axi_wlast <= 1'b1;
        else if (M_AXI_WREADY && axi_wvalid)
            axi_wlast <= 1'b0;
        else
            axi_wlast <= axi_wlast;
    end

    /* Write Data Generator */
    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0)
            axi_wdata <= 'b0;
        else if (wnext && w_buffer_available)
            axi_wdata <= wdata;
        else
            axi_wdata <= axi_wdata;
    end


    //----------------------------
    //Write Response (B) Channel
    //----------------------------

    //The write response channel provides feedback that the write has committed
    //to memory. BREADY will occur when all of the data and the write address
    //has arrived and been accepted by the slave.

    //The write issuance (number of outstanding write addresses) is started by
    //the Address Write transfer, and is completed by a BREADY/BRESP.

    //While negating BREADY will eventually throttle the AWREADY signal,
    //it is best not to throttle the whole data channel this way.

    //The BRESP bit [1] is used indicate any errors from the interconnect or
    //slave for the entire write burst. This example will capture the error
    //into the ERROR output.

    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0)
            axi_bready <= 1'b0;
        else
            axi_bready <= 1'b1;
    end
    //Flag any write response errors
    assign write_resp_error = axi_bready & M_AXI_BVALID & M_AXI_BRESP[1];


    //----------------------------
    //Read Address Channel
    //----------------------------

    //The Read Address Channel (AW) provides a similar function to the
    //Write Address channel- to provide the tranfer qualifiers for the burst.

    //In this example, the read address increments in the same
    //manner as the write address channel.

    always @(posedge M_AXI_ACLK)
    begin

        if (M_AXI_ARESETN == 0)
            axi_arvalid <= 1'b0;
        else if (rnext && r_buffer_available)
            axi_arvalid <= 1'b1;
        else if (M_AXI_ARREADY && axi_arvalid)
            axi_arvalid <= 1'b0;
        else
            axi_arvalid <= axi_arvalid;
    end


    // Next address after ARREADY indicates previous address acceptance
    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0)
            axi_araddr <= 'b0;
        else if (rnext && r_buffer_available)
            axi_araddr <= raddr;
        else
            axi_araddr <= axi_araddr;
    end

    //--------------------------------
    //Read Data (and Response) Channel
    //--------------------------------

    /*
    The Read Data channel returns the results of the read request

    In this example the data checker is always able to accept
    more data, so no need to throttle the RREADY signal
    */
    always @(posedge M_AXI_ACLK)
    begin
        if (M_AXI_ARESETN == 0)
            axi_rready <= 1'b0;
        else
            axi_rready <= 1'b1;
    end

    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0)
            rdata <= 'b0;
        else
            rdata <= M_AXI_RDATA;

    //Flag any read response errors
    assign read_resp_error = axi_rready & M_AXI_RVALID & M_AXI_RRESP[1];

    // Add user logic here

    // This logic serves to keep correct read and write ordering: if the same
    // address is used in a sequential write and read they will happen in the
    // correct order
    // TODO use the write response channel instead of the pop signals
    reg [31:0] r1_counter, r2_counter, r3_counter;
    wire r1_inc, r1_dec, r2_inc, r2_dec, r3_inc, r3_dec;
    reg write_tracker_pop_late;
    wire [2:0] write_tracker_out, write_tracker_in;
    assign r1_inc = (write_tracker_pop_late && write_tracker_out[2]) || i_first_read;
    assign r2_inc = write_tracker_pop_late && write_tracker_out[0];
    assign r3_inc = write_tracker_pop_late && write_tracker_out[1];
    wire r1_addr_buffer_empty, r1_addr_buffer_full, r1_addr_buffer_pop, r1_addr_buffer_push;
    wire r2_addr_buffer_empty, r2_addr_buffer_full, r2_addr_buffer_pop, r2_addr_buffer_push;
    wire r3_addr_buffer_empty, r3_addr_buffer_full, r3_addr_buffer_pop, r3_addr_buffer_push;
    assign r1_dec = r1_addr_buffer_pop;
    assign r2_dec = r2_addr_buffer_pop;
    assign r3_dec = r3_addr_buffer_pop;

    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0) 
            r1_counter <= 0;
        else case ({r1_inc,r1_dec})
            2'b10: r1_counter <= r1_counter + 1;
            2'b01: r1_counter <= r1_counter - 1;
            default: r1_counter <= r1_counter;
        endcase

    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0) 
            r2_counter <= 0;
        else case ({r2_inc,r2_dec})
            2'b10: r2_counter <= r2_counter + 1;
            2'b01: r2_counter <= r2_counter - 1;
            default: r2_counter <= r2_counter;
        endcase

    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0) 
            r3_counter <= 0;
        else case ({r3_inc,r3_dec})
            2'b10: r3_counter <= r3_counter + 1;
            2'b01: r3_counter <= r3_counter - 1;
            default: r3_counter <= r3_counter;
        endcase

    // Master can perform new write if and only if: (~awvalid || (awvalid && awready)) && (~wvalid || (wvalid && wready))
    // Master can perform new read if and only if: ~arvalid || (arvalid && arready)
    // No need to wait for the response
    wire axi_awready, axi_wready, axi_arready;
    assign axi_awready = M_AXI_AWREADY;
    assign axi_wready = M_AXI_WREADY;
    assign axi_arready = M_AXI_ARREADY;

    assign wnext = (~axi_awvalid || (axi_awvalid && axi_awready)) && (~axi_wvalid || (axi_wvalid && axi_wready)); // vivado should optimise this expression during synthesis
    assign rnext = ~axi_arvalid || (axi_arvalid && axi_arready);

    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0)
            rselect <= 3'b001;
        else
            rselect <= {rselect[1:0], rselect[2]};

    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0)
            wselect <= 3'b001;
        else
            wselect <= {wselect[1:0], wselect[2]};

    // Generate statements below are purely for easy code folding
    // Data FIFO's
    generate
        wire w1_data_buffer_empty, w1_data_buffer_full, w1_data_buffer_pop, w1_data_buffer_push;
        wire [127:0] w1_data_buffer_out, w1_data_buffer_in;
        xpm_fifo_sync #(
            .CASCADE_HEIGHT(0),        // DECIMAL
            .DOUT_RESET_VALUE("0"),    // String
            .ECC_MODE("no_ecc"),       // String
            .FIFO_MEMORY_TYPE("auto"), // String
            .FIFO_READ_LATENCY(1),     // DECIMAL
            .FIFO_WRITE_DEPTH(32),     // DECIMAL
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
        w1_data_buffer (
            .dout(w1_data_buffer_out),    // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
            // when reading the FIFO.

            .empty(w1_data_buffer_empty), // 1-bit output: Empty Flag: When asserted, this signal indicates that the
            // FIFO is empty. Read requests are ignored when the FIFO is empty,
            // initiating a read while empty is not destructive to the FIFO.

            .full(w1_data_buffer_full),   // 1-bit output: Full Flag: When asserted, this signal indicates that the
            // FIFO is full. Write requests are ignored when the FIFO is full,
            // initiating a write when the FIFO is full is not destructive to the
            // contents of the FIFO.

            .din(w1_data_buffer_in),      // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
            // writing the FIFO.

            .rd_en(w1_data_buffer_pop),   // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
            // signal causes data (on dout) to be read from the FIFO. Must be held
            // active-low when rd_rst_busy is active high.

            .rst(~M_AXI_ARESETN),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
            // unstable at the time of applying reset, but reset must be released only
            // after the clock(s) is/are stable.
            .wr_clk(M_AXI_ACLK),                  // 1-bit input: Write clock: Used for write operation. wr_clk must be a
            // free running clock.

            .wr_en(w1_data_buffer_push)   // 1-bit input: Write Enable: If the FIFO is not full, asserting this
            // signal causes data (on din) to be written to the FIFO Must be held
            // active-low when rst or wr_rst_busy or rd_rst_busy is active high
        );

        wire w2_data_buffer_empty, w2_data_buffer_full, w2_data_buffer_pop, w2_data_buffer_push;
        wire [127:0] w2_data_buffer_out, w2_data_buffer_in;
        xpm_fifo_sync #(
            .CASCADE_HEIGHT(0),        // DECIMAL
            .DOUT_RESET_VALUE("0"),    // String
            .ECC_MODE("no_ecc"),       // String
            .FIFO_MEMORY_TYPE("auto"), // String
            .FIFO_READ_LATENCY(1),     // DECIMAL
            .FIFO_WRITE_DEPTH(32),     // DECIMAL
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
        w2_data_buffer (
            .dout(w2_data_buffer_out),    // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
            // when reading the FIFO.

            .empty(w2_data_buffer_empty), // 1-bit output: Empty Flag: When asserted, this signal indicates that the
            // FIFO is empty. Read requests are ignored when the FIFO is empty,
            // initiating a read while empty is not destructive to the FIFO.

            .full(w2_data_buffer_full),   // 1-bit output: Full Flag: When asserted, this signal indicates that the
            // FIFO is full. Write requests are ignored when the FIFO is full,
            // initiating a write when the FIFO is full is not destructive to the
            // contents of the FIFO.

            .din(w2_data_buffer_in),      // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
            // writing the FIFO.

            .rd_en(w2_data_buffer_pop),   // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
            // signal causes data (on dout) to be read from the FIFO. Must be held
            // active-low when rd_rst_busy is active high.

            .rst(~M_AXI_ARESETN),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
            // unstable at the time of applying reset, but reset must be released only
            // after the clock(s) is/are stable.
            .wr_clk(M_AXI_ACLK),                  // 1-bit input: Write clock: Used for write operation. wr_clk must be a
            // free running clock.

            .wr_en(w2_data_buffer_push)   // 1-bit input: Write Enable: If the FIFO is not full, asserting this
            // signal causes data (on din) to be written to the FIFO Must be held
            // active-low when rst or wr_rst_busy or rd_rst_busy is active high
        );

        wire w3_data_buffer_empty, w3_data_buffer_full, w3_data_buffer_pop, w3_data_buffer_push;
        wire [127:0] w3_data_buffer_out, w3_data_buffer_in;
        xpm_fifo_sync #(
            .CASCADE_HEIGHT(0),        // DECIMAL
            .DOUT_RESET_VALUE("0"),    // String
            .ECC_MODE("no_ecc"),       // String
            .FIFO_MEMORY_TYPE("auto"), // String
            .FIFO_READ_LATENCY(1),     // DECIMAL
            .FIFO_WRITE_DEPTH(32),     // DECIMAL
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
        w3_data_buffer (
            .dout(w3_data_buffer_out),    // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
            // when reading the FIFO.

            .empty(w3_data_buffer_empty), // 1-bit output: Empty Flag: When asserted, this signal indicates that the
            // FIFO is empty. Read requests are ignored when the FIFO is empty,
            // initiating a read while empty is not destructive to the FIFO.

            .full(w3_data_buffer_full),   // 1-bit output: Full Flag: When asserted, this signal indicates that the
            // FIFO is full. Write requests are ignored when the FIFO is full,
            // initiating a write when the FIFO is full is not destructive to the
            // contents of the FIFO.

            .din(w3_data_buffer_in),      // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
            // writing the FIFO.

            .rd_en(w3_data_buffer_pop),   // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
            // signal causes data (on dout) to be read from the FIFO. Must be held
            // active-low when rd_rst_busy is active high.

            .rst(~M_AXI_ARESETN),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
            // unstable at the time of applying reset, but reset must be released only
            // after the clock(s) is/are stable.
            .wr_clk(M_AXI_ACLK),                  // 1-bit input: Write clock: Used for write operation. wr_clk must be a
            // free running clock.

            .wr_en(w3_data_buffer_push)   // 1-bit input: Write Enable: If the FIFO is not full, asserting this
            // signal causes data (on din) to be written to the FIFO Must be held
            // active-low when rst or wr_rst_busy or rd_rst_busy is active high
        );
    endgenerate

    // Address FIFO's
    generate
        wire [31:0] r1_addr_buffer_out, r1_addr_buffer_in;
        xpm_fifo_sync #(
            .CASCADE_HEIGHT(0),        // DECIMAL
            .DOUT_RESET_VALUE("0"),    // String
            .ECC_MODE("no_ecc"),       // String
            .FIFO_MEMORY_TYPE("auto"), // String
            .FIFO_READ_LATENCY(1),     // DECIMAL
            .FIFO_WRITE_DEPTH(32),     // DECIMAL
            .FULL_RESET_VALUE(0),      // DECIMAL
            .PROG_EMPTY_THRESH(10),    // DECIMAL
            .PROG_FULL_THRESH(10),     // DECIMAL
            .RD_DATA_COUNT_WIDTH(5),   // DECIMAL
            .READ_DATA_WIDTH(32),     // DECIMAL
            .READ_MODE("std"),         // String
            .SIM_ASSERT_CHK(1),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            .USE_ADV_FEATURES("0000"), // String
            .WAKEUP_TIME(0),           // DECIMAL
            .WRITE_DATA_WIDTH(32),    // DECIMAL
            .WR_DATA_COUNT_WIDTH(5)    // DECIMAL
        )
        r1_addr_buffer (
            .dout(r1_addr_buffer_out),    // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
            // when reading the FIFO.

            .empty(r1_addr_buffer_empty), // 1-bit output: Empty Flag: When asserted, this signal indicates that the
            // FIFO is empty. Read requests are ignored when the FIFO is empty,
            // initiating a read while empty is not destructive to the FIFO.

            .full(r1_addr_buffer_full),   // 1-bit output: Full Flag: When asserted, this signal indicates that the
            // FIFO is full. Write requests are ignored when the FIFO is full,
            // initiating a write when the FIFO is full is not destructive to the
            // contents of the FIFO.

            .din(r1_addr_buffer_in),      // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
            // writing the FIFO.

            .rd_en(r1_addr_buffer_pop),   // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
            // signal causes data (on dout) to be read from the FIFO. Must be held
            // active-low when rd_rst_busy is active high.

            .rst(~M_AXI_ARESETN),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
            // unstable at the time of applying reset, but reset must be released only
            // after the clock(s) is/are stable.
            .wr_clk(M_AXI_ACLK),                  // 1-bit input: Write clock: Used for write operation. wr_clk must be a
            // free running clock.

            .wr_en(r1_addr_buffer_push)   // 1-bit input: Write Enable: If the FIFO is not full, asserting this
            // signal causes data (on din) to be written to the FIFO Must be held
            // active-low when rst or wr_rst_busy or rd_rst_busy is active high
        );

        wire [31:0] r2_addr_buffer_out, r2_addr_buffer_in;
        xpm_fifo_sync #(
            .CASCADE_HEIGHT(0),        // DECIMAL
            .DOUT_RESET_VALUE("0"),    // String
            .ECC_MODE("no_ecc"),       // String
            .FIFO_MEMORY_TYPE("auto"), // String
            .FIFO_READ_LATENCY(1),     // DECIMAL
            .FIFO_WRITE_DEPTH(32),     // DECIMAL
            .FULL_RESET_VALUE(0),      // DECIMAL
            .PROG_EMPTY_THRESH(10),    // DECIMAL
            .PROG_FULL_THRESH(10),     // DECIMAL
            .RD_DATA_COUNT_WIDTH(5),   // DECIMAL
            .READ_DATA_WIDTH(32),     // DECIMAL
            .READ_MODE("std"),         // String
            .SIM_ASSERT_CHK(1),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            .USE_ADV_FEATURES("0000"), // String
            .WAKEUP_TIME(0),           // DECIMAL
            .WRITE_DATA_WIDTH(32),    // DECIMAL
            .WR_DATA_COUNT_WIDTH(5)    // DECIMAL
        )
        r2_addr_buffer (
            .dout(r2_addr_buffer_out),    // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
            // when reading the FIFO.

            .empty(r2_addr_buffer_empty), // 1-bit output: Empty Flag: When asserted, this signal indicates that the
            // FIFO is empty. Read requests are ignored when the FIFO is empty,
            // initiating a read while empty is not destructive to the FIFO.

            .full(r2_addr_buffer_full),   // 1-bit output: Full Flag: When asserted, this signal indicates that the
            // FIFO is full. Write requests are ignored when the FIFO is full,
            // initiating a write when the FIFO is full is not destructive to the
            // contents of the FIFO.

            .din(r2_addr_buffer_in),      // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
            // writing the FIFO.

            .rd_en(r2_addr_buffer_pop),   // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
            // signal causes data (on dout) to be read from the FIFO. Must be held
            // active-low when rd_rst_busy is active high.

            .rst(~M_AXI_ARESETN),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
            // unstable at the time of applying reset, but reset must be released only
            // after the clock(s) is/are stable.
            .wr_clk(M_AXI_ACLK),                  // 1-bit input: Write clock: Used for write operation. wr_clk must be a
            // free running clock.

            .wr_en(r2_addr_buffer_push)   // 1-bit input: Write Enable: If the FIFO is not full, asserting this
            // signal causes data (on din) to be written to the FIFO Must be held
            // active-low when rst or wr_rst_busy or rd_rst_busy is active high
        );
        wire [31:0] r3_addr_buffer_out, r3_addr_buffer_in;
        xpm_fifo_sync #(
            .CASCADE_HEIGHT(0),        // DECIMAL
            .DOUT_RESET_VALUE("0"),    // String
            .ECC_MODE("no_ecc"),       // String
            .FIFO_MEMORY_TYPE("auto"), // String
            .FIFO_READ_LATENCY(1),     // DECIMAL
            .FIFO_WRITE_DEPTH(32),     // DECIMAL
            .FULL_RESET_VALUE(0),      // DECIMAL
            .PROG_EMPTY_THRESH(10),    // DECIMAL
            .PROG_FULL_THRESH(10),     // DECIMAL
            .RD_DATA_COUNT_WIDTH(5),   // DECIMAL
            .READ_DATA_WIDTH(32),     // DECIMAL
            .READ_MODE("std"),         // String
            .SIM_ASSERT_CHK(1),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            .USE_ADV_FEATURES("0000"), // String
            .WAKEUP_TIME(0),           // DECIMAL
            .WRITE_DATA_WIDTH(32),    // DECIMAL
            .WR_DATA_COUNT_WIDTH(5)    // DECIMAL
        )
        r3_addr_buffer (
            .dout(r3_addr_buffer_out),    // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
            // when reading the FIFO.

            .empty(r3_addr_buffer_empty), // 1-bit output: Empty Flag: When asserted, this signal indicates that the
            // FIFO is empty. Read requests are ignored when the FIFO is empty,
            // initiating a read while empty is not destructive to the FIFO.

            .full(r3_addr_buffer_full),   // 1-bit output: Full Flag: When asserted, this signal indicates that the
            // FIFO is full. Write requests are ignored when the FIFO is full,
            // initiating a write when the FIFO is full is not destructive to the
            // contents of the FIFO.

            .din(r3_addr_buffer_in),      // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
            // writing the FIFO.

            .rd_en(r3_addr_buffer_pop),   // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
            // signal causes data (on dout) to be read from the FIFO. Must be held
            // active-low when rd_rst_busy is active high.

            .rst(~M_AXI_ARESETN),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
            // unstable at the time of applying reset, but reset must be released only
            // after the clock(s) is/are stable.
            .wr_clk(M_AXI_ACLK),                  // 1-bit input: Write clock: Used for write operation. wr_clk must be a
            // free running clock.

            .wr_en(r3_addr_buffer_push)   // 1-bit input: Write Enable: If the FIFO is not full, asserting this
            // signal causes data (on din) to be written to the FIFO Must be held
            // active-low when rst or wr_rst_busy or rd_rst_busy is active high
        );
        wire w1_addr_buffer_empty, w1_addr_buffer_full, w1_addr_buffer_pop, w1_addr_buffer_push;
        wire [31:0] w1_addr_buffer_out, w1_addr_buffer_in;
        xpm_fifo_sync #(
            .CASCADE_HEIGHT(0),        // DECIMAL
            .DOUT_RESET_VALUE("0"),    // String
            .ECC_MODE("no_ecc"),       // String
            .FIFO_MEMORY_TYPE("auto"), // String
            .FIFO_READ_LATENCY(1),     // DECIMAL
            .FIFO_WRITE_DEPTH(32),     // DECIMAL
            .FULL_RESET_VALUE(0),      // DECIMAL
            .PROG_EMPTY_THRESH(10),    // DECIMAL
            .PROG_FULL_THRESH(10),     // DECIMAL
            .RD_DATA_COUNT_WIDTH(5),   // DECIMAL
            .READ_DATA_WIDTH(32),     // DECIMAL
            .READ_MODE("std"),         // String
            .SIM_ASSERT_CHK(1),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            .USE_ADV_FEATURES("0000"), // String
            .WAKEUP_TIME(0),           // DECIMAL
            .WRITE_DATA_WIDTH(32),    // DECIMAL
            .WR_DATA_COUNT_WIDTH(5)    // DECIMAL
        )
        w1_addr_buffer (
            .dout(w1_addr_buffer_out),    // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
            // when reading the FIFO.

            .empty(w1_addr_buffer_empty), // 1-bit output: Empty Flag: When asserted, this signal indicates that the
            // FIFO is empty. Read requests are ignored when the FIFO is empty,
            // initiating a read while empty is not destructive to the FIFO.

            .full(w1_addr_buffer_full),   // 1-bit output: Full Flag: When asserted, this signal indicates that the
            // FIFO is full. Write requests are ignored when the FIFO is full,
            // initiating a write when the FIFO is full is not destructive to the
            // contents of the FIFO.

            .din(w1_addr_buffer_in),      // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
            // writing the FIFO.

            .rd_en(w1_addr_buffer_pop),   // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
            // signal causes data (on dout) to be read from the FIFO. Must be held
            // active-low when rd_rst_busy is active high.

            .rst(~M_AXI_ARESETN),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
            // unstable at the time of applying reset, but reset must be released only
            // after the clock(s) is/are stable.
            .wr_clk(M_AXI_ACLK),                  // 1-bit input: Write clock: Used for write operation. wr_clk must be a
            // free running clock.

            .wr_en(w1_addr_buffer_push)   // 1-bit input: Write Enable: If the FIFO is not full, asserting this
            // signal causes data (on din) to be written to the FIFO Must be held
            // active-low when rst or wr_rst_busy or rd_rst_busy is active high
        ); 
        wire w2_addr_buffer_empty, w2_addr_buffer_full, w2_addr_buffer_pop, w2_addr_buffer_push;
        wire [31:0] w2_addr_buffer_out, w2_addr_buffer_in;
        xpm_fifo_sync #(
            .CASCADE_HEIGHT(0),        // DECIMAL
            .DOUT_RESET_VALUE("0"),    // String
            .ECC_MODE("no_ecc"),       // String
            .FIFO_MEMORY_TYPE("auto"), // String
            .FIFO_READ_LATENCY(1),     // DECIMAL
            .FIFO_WRITE_DEPTH(32),     // DECIMAL
            .FULL_RESET_VALUE(0),      // DECIMAL
            .PROG_EMPTY_THRESH(10),    // DECIMAL
            .PROG_FULL_THRESH(10),     // DECIMAL
            .RD_DATA_COUNT_WIDTH(5),   // DECIMAL
            .READ_DATA_WIDTH(32),     // DECIMAL
            .READ_MODE("std"),         // String
            .SIM_ASSERT_CHK(1),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            .USE_ADV_FEATURES("0000"), // String
            .WAKEUP_TIME(0),           // DECIMAL
            .WRITE_DATA_WIDTH(32),    // DECIMAL
            .WR_DATA_COUNT_WIDTH(5)    // DECIMAL
        )
        w2_addr_buffer (
            .dout(w2_addr_buffer_out),    // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
            // when reading the FIFO.

            .empty(w2_addr_buffer_empty), // 1-bit output: Empty Flag: When asserted, this signal indicates that the
            // FIFO is empty. Read requests are ignored when the FIFO is empty,
            // initiating a read while empty is not destructive to the FIFO.

            .full(w2_addr_buffer_full),   // 1-bit output: Full Flag: When asserted, this signal indicates that the
            // FIFO is full. Write requests are ignored when the FIFO is full,
            // initiating a write when the FIFO is full is not destructive to the
            // contents of the FIFO.

            .din(w2_addr_buffer_in),      // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
            // writing the FIFO.

            .rd_en(w2_addr_buffer_pop),   // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
            // signal causes data (on dout) to be read from the FIFO. Must be held
            // active-low when rd_rst_busy is active high.

            .rst(~M_AXI_ARESETN),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
            // unstable at the time of applying reset, but reset must be released only
            // after the clock(s) is/are stable.
            .wr_clk(M_AXI_ACLK),                  // 1-bit input: Write clock: Used for write operation. wr_clk must be a
            // free running clock.

            .wr_en(w2_addr_buffer_push)   // 1-bit input: Write Enable: If the FIFO is not full, asserting this
            // signal causes data (on din) to be written to the FIFO Must be held
            // active-low when rst or wr_rst_busy or rd_rst_busy is active high
        );
        wire w3_addr_buffer_empty, w3_addr_buffer_full, w3_addr_buffer_pop, w3_addr_buffer_push;
        wire [31:0] w3_addr_buffer_out, w3_addr_buffer_in;
        xpm_fifo_sync #(
            .CASCADE_HEIGHT(0),        // DECIMAL
            .DOUT_RESET_VALUE("0"),    // String
            .ECC_MODE("no_ecc"),       // String
            .FIFO_MEMORY_TYPE("auto"), // String
            .FIFO_READ_LATENCY(1),     // DECIMAL
            .FIFO_WRITE_DEPTH(32),     // DECIMAL
            .FULL_RESET_VALUE(0),      // DECIMAL
            .PROG_EMPTY_THRESH(10),    // DECIMAL
            .PROG_FULL_THRESH(10),     // DECIMAL
            .RD_DATA_COUNT_WIDTH(5),   // DECIMAL
            .READ_DATA_WIDTH(32),     // DECIMAL
            .READ_MODE("std"),         // String
            .SIM_ASSERT_CHK(1),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            .USE_ADV_FEATURES("0000"), // String
            .WAKEUP_TIME(0),           // DECIMAL
            .WRITE_DATA_WIDTH(32),    // DECIMAL
            .WR_DATA_COUNT_WIDTH(5)    // DECIMAL
        )
        w3_addr_buffer (
            .dout(w3_addr_buffer_out),    // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
            // when reading the FIFO.

            .empty(w3_addr_buffer_empty), // 1-bit output: Empty Flag: When asserted, this signal indicates that the
            // FIFO is empty. Read requests are ignored when the FIFO is empty,
            // initiating a read while empty is not destructive to the FIFO.

            .full(w3_addr_buffer_full),   // 1-bit output: Full Flag: When asserted, this signal indicates that the
            // FIFO is full. Write requests are ignored when the FIFO is full,
            // initiating a write when the FIFO is full is not destructive to the
            // contents of the FIFO.

            .din(w3_addr_buffer_in),      // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
            // writing the FIFO.

            .rd_en(w3_addr_buffer_pop),   // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
            // signal causes data (on dout) to be read from the FIFO. Must be held
            // active-low when rd_rst_busy is active high.

            .rst(~M_AXI_ARESETN),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
            // unstable at the time of applying reset, but reset must be released only
            // after the clock(s) is/are stable.
            .wr_clk(M_AXI_ACLK),                  // 1-bit input: Write clock: Used for write operation. wr_clk must be a
            // free running clock.

            .wr_en(w3_addr_buffer_push)   // 1-bit input: Write Enable: If the FIFO is not full, asserting this
            // signal causes data (on din) to be written to the FIFO Must be held
            // active-low when rst or wr_rst_busy or rd_rst_busy is active high
        );

    endgenerate

    // read/write tracker FIFO's
    generate
        wire read_tracker_empty, read_tracker_full, read_tracker_pop, read_tracker_push;
        wire [2:0] read_tracker_out, read_tracker_in;
        xpm_fifo_sync #(
            .CASCADE_HEIGHT(0),        // DECIMAL
            .DOUT_RESET_VALUE("0"),    // String
            .ECC_MODE("no_ecc"),       // String
            .FIFO_MEMORY_TYPE("auto"), // String
            .FIFO_READ_LATENCY(1),     // DECIMAL
            .FIFO_WRITE_DEPTH(16),     // DECIMAL
            .FULL_RESET_VALUE(0),      // DECIMAL
            .PROG_EMPTY_THRESH(10),    // DECIMAL
            .PROG_FULL_THRESH(10),     // DECIMAL
            .RD_DATA_COUNT_WIDTH(5),   // DECIMAL
            .READ_DATA_WIDTH(3),     // DECIMAL
            .READ_MODE("std"),         // String
            .SIM_ASSERT_CHK(1),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            .USE_ADV_FEATURES("0000"), // String
            .WAKEUP_TIME(0),           // DECIMAL
            .WRITE_DATA_WIDTH(3),    // DECIMAL
            .WR_DATA_COUNT_WIDTH(5)    // DECIMAL
        )
        read_tracker (
            .dout(read_tracker_out),    // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
            // when reading the FIFO.

            .empty(read_tracker_empty), // 1-bit output: Empty Flag: When asserted, this signal indicates that the
            // FIFO is empty. Read requests are ignored when the FIFO is empty,
            // initiating a read while empty is not destructive to the FIFO.

            .full(read_tracker_full),   // 1-bit output: Full Flag: When asserted, this signal indicates that the
            // FIFO is full. Write requests are ignored when the FIFO is full,
            // initiating a write when the FIFO is full is not destructive to the
            // contents of the FIFO.

            .din(read_tracker_in),      // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
            // writing the FIFO.

            .rd_en(read_tracker_pop),   // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
            // signal causes data (on dout) to be read from the FIFO. Must be held
            // active-low when rd_rst_busy is active high.

            .rst(~M_AXI_ARESETN),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
            // unstable at the time of applying reset, but reset must be released only
            // after the clock(s) is/are stable.
            .wr_clk(M_AXI_ACLK),                  // 1-bit input: Write clock: Used for write operation. wr_clk must be a
            // free running clock.

            .wr_en(read_tracker_push)   // 1-bit input: Write Enable: If the FIFO is not full, asserting this
            // signal causes data (on din) to be written to the FIFO Must be held
            // active-low when rst or wr_rst_busy or rd_rst_busy is active high
        );
        wire write_tracker_empty, write_tracker_full, write_tracker_pop, write_tracker_push;
        xpm_fifo_sync #(
            .CASCADE_HEIGHT(0),        // DECIMAL
            .DOUT_RESET_VALUE("0"),    // String
            .ECC_MODE("no_ecc"),       // String
            .FIFO_MEMORY_TYPE("auto"), // String
            .FIFO_READ_LATENCY(1),     // DECIMAL
            .FIFO_WRITE_DEPTH(16),     // DECIMAL
            .FULL_RESET_VALUE(0),      // DECIMAL
            .PROG_EMPTY_THRESH(10),    // DECIMAL
            .PROG_FULL_THRESH(10),     // DECIMAL
            .RD_DATA_COUNT_WIDTH(5),   // DECIMAL
            .READ_DATA_WIDTH(3),     // DECIMAL
            .READ_MODE("std"),         // String
            .SIM_ASSERT_CHK(1),        // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            .USE_ADV_FEATURES("0000"), // String
            .WAKEUP_TIME(0),           // DECIMAL
            .WRITE_DATA_WIDTH(3),    // DECIMAL
            .WR_DATA_COUNT_WIDTH(5)    // DECIMAL
        )
        write_tracker (
            .dout(write_tracker_out),    // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
            // when reading the FIFO.

            .empty(write_tracker_empty), // 1-bit output: Empty Flag: When asserted, this signal indicates that the
            // FIFO is empty. Read requests are ignored when the FIFO is empty,
            // initiating a read while empty is not destructive to the FIFO.

            .full(write_tracker_full),   // 1-bit output: Full Flag: When asserted, this signal indicates that the
            // FIFO is full. Write requests are ignored when the FIFO is full,
            // initiating a write when the FIFO is full is not destructive to the
            // contents of the FIFO.

            .din(write_tracker_in),      // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
            // writing the FIFO.

            .rd_en(write_tracker_pop),   // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
            // signal causes data (on dout) to be read from the FIFO. Must be held
            // active-low when rd_rst_busy is active high.

            .rst(~M_AXI_ARESETN),                     // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
            // unstable at the time of applying reset, but reset must be released only
            // after the clock(s) is/are stable.
            .wr_clk(M_AXI_ACLK),                  // 1-bit input: Write clock: Used for write operation. wr_clk must be a
            // free running clock.

            .wr_en(write_tracker_push)   // 1-bit input: Write Enable: If the FIFO is not full, asserting this
            // signal causes data (on din) to be written to the FIFO Must be held
            // active-low when rst or wr_rst_busy or rd_rst_busy is active high
        );

    endgenerate

    assign {w3_data_buffer_pop, w2_data_buffer_pop, w1_data_buffer_pop} = w_buffer_available_bus & {3{wnext}};
    assign {r3_addr_buffer_pop, r2_addr_buffer_pop, r1_addr_buffer_pop} = r_buffer_available_bus & {3{rnext}};
    assign {w3_addr_buffer_pop, w2_addr_buffer_pop, w1_addr_buffer_pop} = w_buffer_available_bus & {3{wnext}};
    
    function automatic [31:0] select2buffer32(input reg [2:0] select, input
        [31:0] option1, input [31:0] option2, input [31:0]
        option3);
        case (select)
            3'b001: select2buffer32 = option1;
            3'b010: select2buffer32 = option2;
            3'b100: select2buffer32 = option3;
            default: select2buffer32 = 0;
        endcase
    endfunction
    function automatic [127:0] select2buffer128(input reg [2:0] select, input 
        [127:0] option1, input  [127:0] option2, input  [127:0]
        option3);
        case (select)
            3'b001: select2buffer128 = option1;
            3'b010: select2buffer128 = option2;
            3'b100: select2buffer128 = option3;
            default: select2buffer128 = 0;
        endcase
    endfunction

    assign wdata = select2buffer128(wselect, w2_data_buffer_out, w3_data_buffer_out, w1_data_buffer_out);
    assign waddr = select2buffer32(wselect, w2_addr_buffer_out, w3_addr_buffer_out, w1_addr_buffer_out);
    assign raddr = select2buffer32(rselect, r2_addr_buffer_out, r3_addr_buffer_out, r1_addr_buffer_out);
 
    assign read_tracker_in = {rselect[0], rselect[2:1]};
    assign read_tracker_push = |{r3_addr_buffer_pop, r2_addr_buffer_pop, r1_addr_buffer_pop};
    assign read_tracker_pop = M_AXI_RVALID && axi_rready;

    assign write_tracker_in = {wselect[0], wselect[2:1]};
    assign write_tracker_push = |{w3_addr_buffer_pop, w2_addr_buffer_pop, w1_addr_buffer_pop};
    assign write_tracker_pop = M_AXI_BVALID && axi_bready;
    always @(posedge M_AXI_ACLK) 
        if (M_AXI_ARESETN == 0)
            write_tracker_pop_late <= 0;
        else
            write_tracker_pop_late <= write_tracker_pop;

    always @(posedge M_AXI_ACLK) 
        if (M_AXI_ARESETN == 0) begin
            w_buffer_available <= 0;
            r_buffer_available <= 0;
            w_buffer_available_bus <= 0;
            r_buffer_available_bus <= 0;
        end
        else begin
            w_buffer_available_bus <= ~{w3_addr_buffer_empty, w2_addr_buffer_empty, w1_addr_buffer_empty} & wselect;
            r_buffer_available_bus <= ~({r3_addr_buffer_empty, r2_addr_buffer_empty, r1_addr_buffer_empty} | {r3_counter == 0, r2_counter == 0, r1_counter == 0}) & rselect;
            r_buffer_available <= |(r_buffer_available_bus);
            w_buffer_available <= |(w_buffer_available_bus);
        end
    
    // I/O assignments
    assign r1_addr_buffer_push = i_r1_request;
    assign r2_addr_buffer_push = i_r2_request;
    assign r3_addr_buffer_push = i_r3_request;
    assign w1_addr_buffer_push = i_w1_request;
    assign w2_addr_buffer_push = i_w2_request;
    assign w3_addr_buffer_push = i_w3_request;
    assign w1_data_buffer_push = i_w1_request;
    assign w2_data_buffer_push = i_w2_request;
    assign w3_data_buffer_push = i_w3_request;

    assign r1_addr_buffer_in = i_r1_addr;
    assign r2_addr_buffer_in = i_r2_addr;
    assign r3_addr_buffer_in = i_r3_addr;
    assign w1_addr_buffer_in = i_w1_addr;
    assign w2_addr_buffer_in = i_w2_addr;
    assign w3_addr_buffer_in = i_w3_addr;
    assign w1_data_buffer_in = i_w1_data;
    assign w2_data_buffer_in = i_w2_data;
    assign w3_data_buffer_in = i_w3_data;

    assign o_r1_data = rdata;
    assign o_r2_data = rdata;
    assign o_r3_data = rdata;

    reg rdata_valid;
    always @(posedge M_AXI_ACLK)
        if (M_AXI_ARESETN == 0) 
            rdata_valid <= 0;
        else
            rdata_valid <= M_AXI_RVALID && axi_rready;

    assign o_r1_valid = rdata_valid && read_tracker_out[0];
    assign o_r2_valid = rdata_valid && read_tracker_out[1];
    assign o_r3_valid = rdata_valid && read_tracker_out[2];
    // User logic ends

endmodule
