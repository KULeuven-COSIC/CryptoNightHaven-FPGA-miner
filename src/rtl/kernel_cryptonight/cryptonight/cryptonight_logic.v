`timescale 1ns / 1ps

module cryptonight_logic #(
    parameter scratch_rounds = 'h40000, // amount of rounds to generate scratchpad
    parameter shuffle_rounds = 'h40000, // amount of rounds performed by shuffle
    parameter CN_XHV = 0, // CN XHV (1) or CN Heavy (0)
    parameter nonce_width = 7,
    parameter buffer_depth = 128,
    //parameters below should not be modified
    parameter state_width = 1600,
    parameter block_width = 1024,
    parameter key_width = 256,
    // end of non-modifiable parameters
    parameter integer INT_ADDR_WIDTH =  32,
    parameter integer AXI_ADDR_WIDTH =  64,
    parameter integer AXI_DATA_WIDTH = 128
    )
    (
        input wire m00_axi_aclk,
        input wire m01_axi_aclk,
        input wire m02_axi_aclk,
        input wire clk_ap,
        input wire clk_slow,
        input wire clk_fast,
        input wire rstn_slow,
        input wire rstn_fast,

        // 
        input  wire [nonce_width-1:0] i_nonce,
        input  wire [state_width-1:0] i_state,
        input  wire                   i_valid, // state and nonce both valid
        output wire                   o_ready, // ready to accept state and nonce
        output wire                   o_done,
        output wire [state_width-1:0] o_data,
        output wire [nonce_width-1:0] o_nonce,
        
        // 
        input wire [AXI_ADDR_WIDTH-1 : 0] axi_base_addr,

        // explode axi interface
        output wire [AXI_ADDR_WIDTH-1 : 0] m00_axi_awaddr,
        output wire [7 : 0] m00_axi_awlen,
        output wire [2 : 0] m00_axi_awsize,
        output wire [1 : 0] m00_axi_awburst,
        output wire  m00_axi_awvalid,
        input wire  m00_axi_awready,
        output wire [AXI_DATA_WIDTH-1 : 0] m00_axi_wdata,
        output wire [AXI_DATA_WIDTH/8-1 : 0] m00_axi_wstrb,
        output wire  m00_axi_wlast,
        output wire  m00_axi_wvalid,
        input wire  m00_axi_wready,
        input wire [1 : 0] m00_axi_bresp,
        input wire  m00_axi_bvalid,
        output wire  m00_axi_bready,

        // shuffle axi interface
        output wire [AXI_ADDR_WIDTH-1 : 0] m01_axi_awaddr,
        output wire [7 : 0] m01_axi_awlen,
        output wire [2 : 0] m01_axi_awsize,
        output wire [1 : 0] m01_axi_awburst,
        output wire  m01_axi_awvalid,
        input wire  m01_axi_awready,
        output wire [AXI_DATA_WIDTH-1 : 0] m01_axi_wdata,
        output wire [AXI_DATA_WIDTH/8-1 : 0] m01_axi_wstrb,
        output wire  m01_axi_wlast,
        output wire  m01_axi_wvalid,
        input wire  m01_axi_wready,
        input wire [1 : 0] m01_axi_bresp,
        input wire  m01_axi_bvalid,
        output wire  m01_axi_bready,
        output wire [AXI_ADDR_WIDTH-1 : 0] m01_axi_araddr,
        output wire [7 : 0] m01_axi_arlen,
        output wire [2 : 0] m01_axi_arsize,
        output wire [1 : 0] m01_axi_arburst,
        output wire  m01_axi_arvalid,
        input wire  m01_axi_arready,
        input wire [AXI_DATA_WIDTH-1 : 0] m01_axi_rdata,
        input wire [1 : 0] m01_axi_rresp,
        input wire  m01_axi_rlast,
        input wire  m01_axi_rvalid,
        output wire  m01_axi_rready,

        output wire [AXI_ADDR_WIDTH-1 : 0] m02_axi_araddr,
        output wire [7 : 0] m02_axi_arlen,
        output wire [2 : 0] m02_axi_arsize,
        output wire [1 : 0] m02_axi_arburst,
        output wire  m02_axi_arvalid,
        input wire  m02_axi_arready,
        input wire [AXI_DATA_WIDTH-1 : 0] m02_axi_rdata,
        input wire [1 : 0] m02_axi_rresp,
        input wire  m02_axi_rlast,
        input wire  m02_axi_rvalid,
        output wire  m02_axi_rready
    );

    localparam URAM = 0;
    localparam state_buffer_addr_width = nonce_width;
    localparam state_buffer_wakeup_time = URAM == 1 ? 2 : 0;
    localparam state_buffer_base_delay = 3;
    localparam state_buffer_delay = state_buffer_base_delay + state_buffer_wakeup_time;

    wire [AXI_ADDR_WIDTH-1:0] axi_base_addr_slow; wire cdc_fifo_slow_empty, cdc_fifo_slow_full;
    wire [AXI_ADDR_WIDTH-1:0] axi_base_addr_fast; wire cdc_fifo_fast_empty, cdc_fifo_fast_full;
    cdc_fifo inst_cdc_fifo_slow (clk_ap, clk_slow, axi_base_addr, ~cdc_fifo_slow_full, ~cdc_fifo_slow_empty, axi_base_addr_slow, cdc_fifo_slow_full, cdc_fifo_slow_empty);
    cdc_fifo inst_cdc_fifo_fast (clk_ap, clk_fast, axi_base_addr, ~cdc_fifo_fast_full, ~cdc_fifo_fast_empty, axi_base_addr_fast, cdc_fifo_fast_full, cdc_fifo_fast_empty);
  
  // helper functions
    function automatic integer clogb2 (input integer bit_depth);
        begin
            for(clogb2=0; bit_depth>0; clogb2=clogb2+1)
                bit_depth = bit_depth >> 1;
        end
    endfunction

    // explode instantiation
    generate
        localparam explode_minimum_write_burst_len = 8;
        localparam explode_maximum_write_burst_len = 64;
        // convention: exp_ -> wires to loader or AXI
        //             explode -> wires to rest of cryptonight or outside
        wire explode_rstn, exp_start, exp_write_req, exp_done, explode_nonce_valid, exp_nonce_valid, exp_state_buffer_wr_en;
        wire [nonce_width-1:0] exp_nonce, explode_nonce_input;
        wire [state_width-1:0] exp_state_buffer_data, explode_state_input;
        wire [state_buffer_addr_width-1:0] exp_state_buffer_addr;
        wire [31:0] exp_mem_address;
        wire [127:0] exp_write_data;
        wire [255:0] exp_key_bytes;
        wire [1023:0] exp_block_bytes, rev_exp_block_bytes;
        localparam explode_width = 512;
        wire [explode_width+nonce_width-1:0] explode_send_data;

        rev_bytes #(.SIZE(1024)) rev_explode_blocks (.in(rev_exp_block_bytes), .out(exp_block_bytes));
        explode_compact #(
            .AXI(1),
            .NUM_ROUNDS(scratch_rounds)
        )
        explode (
            .clk(clk_slow),
            .rstn(explode_rstn),
            .start(exp_start),
            .i_buffer_full(exp_buffer_full),
            .key_bytes(exp_key_bytes),
            .block_bytes(exp_block_bytes),
            .max_mem_address('hffffffff),
            .mem_address(exp_mem_address),
            .scratch_write(exp_write_data),
            .request_write(exp_write_req),
            .done(exp_done)
        );

        explode_axi #(
            .NUM_ROUNDS(scratch_rounds),
            .nonce_width(nonce_width),
            .burst_counter_treshold1(explode_minimum_write_burst_len),
            .burst_counter_treshold2(explode_maximum_write_burst_len),
            .C_M_AXI_BURST_LEN(explode_maximum_write_burst_len),
            .C_M_AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
            .C_M_AXI_DATA_WIDTH(AXI_DATA_WIDTH)
        )
        inst_explode_axi(
            .i_data(exp_write_data),
            .i_data_valid(exp_write_req),
            .o_buffer_full(exp_buffer_full),
            .i_nonce_valid(exp_nonce_valid),
            .i_nonce(exp_nonce),
            .o_done(exp_AXI_done),
            .axi_base_addr(axi_base_addr_slow),
            .M_AXI_ACLK(clk_slow),
            .M_AXI_ARESETN(rstn_slow),
            .M_AXI_AWADDR(m00_axi_awaddr),
            .M_AXI_AWLEN(m00_axi_awlen),
            .M_AXI_AWSIZE(m00_axi_awsize),
            .M_AXI_AWBURST(m00_axi_awburst),
            .M_AXI_AWVALID(m00_axi_awvalid),
            .M_AXI_AWREADY(m00_axi_awready),
            .M_AXI_WDATA(m00_axi_wdata),
            .M_AXI_WSTRB(m00_axi_wstrb),
            .M_AXI_WLAST(m00_axi_wlast),
            .M_AXI_WVALID(m00_axi_wvalid),
            .M_AXI_WREADY(m00_axi_wready),
            .M_AXI_BVALID(m00_axi_bvalid),
            .M_AXI_BREADY(m00_axi_bready)
        );

        explode_loader #(
            .state_width(state_width),
            .block_width(block_width),
            .key_width(key_width),
            .nonce_width(nonce_width),
            .BRAM_addr_width(state_buffer_addr_width)
        )
        exp_loader(
            .clk(clk_slow),
            .rstn(rstn_slow),
            .i_v_state(explode_state_input),
            .i_v_nonce(explode_nonce_input),
            .i_valid(explode_input_valid),
            .i_ex_done(exp_done),
            .i_AXI_done(exp_AXI_done),
            .o_ready(explode_input_ready),
            .o_v_block(rev_exp_block_bytes),
            .o_v_key(exp_key_bytes),
            .o_start(exp_start),
            .o_nonce_valid(exp_nonce_valid),
            .o_v_nonce(exp_nonce),
            .o_v_state(exp_state_buffer_data),
            .o_v_addr(exp_state_buffer_addr),
            .o_wr_en(exp_state_buffer_wr_en),
            .o_rstn_explode(explode_rstn)
        );

        explode_unloader #(
            .nonce_width(nonce_width),
            .explode_width(explode_width)
        )
        exp_unloader(
            .clk(clk_slow),
            .rstn(rstn_slow),
            .i_compact_start(exp_state_buffer_wr_en),
            .i_compact_done(exp_done),
            .i_AXI_done(exp_AXI_done),
            .i_state_bytes(exp_state_buffer_data[key_width*2-1:0]),
            .i_nonce(exp_state_buffer_addr[nonce_width-1:0]),
            .o_handshake(explode_send_handshake),
            .o_data(explode_send_data),
            .i_handshake_recv(explode_recv_handshake)
        );

        assign explode_state_input = i_state;
        assign explode_nonce_input = i_nonce;
        assign explode_input_valid = i_valid;
        assign o_ready = explode_input_ready;
    endgenerate

    // shuffle instantiation
    generate
        localparam FIFO_READ_LATENCY = 2;
        localparam AES_latency = 1 + (FIFO_READ_LATENCY-1);
        localparam multadd_latency = 24 + (FIFO_READ_LATENCY-1);
        localparam multadd_multiplier_latency = 18;
        localparam div_latency = 68;
        localparam addr_width = clogb2(scratch_rounds*8)-1;

        wire [INT_ADDR_WIDTH-1:0] sh_r1_addr, sh_r2_addr, sh_r3_addr,
        sh_w1_addr, sh_w2_addr, sh_w3_addr;
        wire [AXI_DATA_WIDTH-1:0] sh_r1_data, sh_r2_data, sh_r3_data,
        sh_w1_data, sh_w2_data, sh_w3_data, rev_sh_r1_data, rev_sh_r2_data,
        rev_sh_r3_data, rev_sh_w1_data, rev_sh_w2_data, rev_sh_w3_data;
        wire [127:0] sh_state;
        wire [nonce_width-1:0] sh_nonce, shuffle_i_nonce, shuffle_o_nonce, sh_imp_nonce;
        wire [explode_width-1:0] shuffle_i_data;

        shuffle_piped_controller #(
            .FIFO_READ_LATENCY(FIFO_READ_LATENCY),
            .AES_latency(AES_latency),
            .multadd_latency(multadd_latency),
            .multadd_multiplier_latency(multadd_multiplier_latency),
            .div_latency(div_latency),
            .shuffle_rounds(shuffle_rounds),
            .buffer_depth(buffer_depth)
        )
        control(
            .clk(clk_fast), // clock
            .rst(~rstn_fast), // active high reset

            // accept new input state
            .i_state_valid(sh_state_valid), // axi-like valid-ready structure
            .o_state_ready(sh_state_ready),
            .o_load_state_reg(sh_load_state_reg),
            .o_r1_addr_mux_select(sh_r1_addr_mux_select),
            .o_a_mux_select(sh_a_mux_select),
            .o_b_mux_select(sh_b_mux_select),
            .o_dividend_valid(sh_dividend_valid),
            .o_divisor_valid(sh_divisor_valid),

            // memory requests
            .o_r1_request(sh_r1_request),
            .o_first_read(sh_first_read),
            .i_r1_valid(sh_r1_valid),
            .o_w1_valid(sh_w1_valid),
            .o_r2_request(sh_r2_request),
            .i_r2_valid(sh_r2_valid),
            .o_w2_valid(sh_w2_valid),
            .o_r3_request(sh_r3_request),
            .i_r3_valid(sh_r3_valid),
            .o_w3_valid(sh_w3_valid),

            // datapath buffers
            .o_a2_buffer_pop(sh_a2_buffer_pop),
            .o_a2_buffer_push(sh_a2_buffer_push),
            .o_a3_buffer_pop(sh_a3_buffer_pop),
            .o_a3_buffer_push(sh_a3_buffer_push),
            .o_a4_buffer_pop(sh_a4_buffer_pop),
            .o_a4_buffer_push(sh_a4_buffer_push),
            .o_c1_buffer_pop(sh_c1_buffer_pop),
            .o_c1_buffer_push(sh_c1_buffer_push),
            .o_c2_buffer_pop(sh_c2_buffer_pop),
            .o_c2_buffer_push(sh_c2_buffer_push),
            .o_r1_addr_buffer_pop(sh_r1_addr_buffer_pop),
            .o_r1_addr_buffer_push(sh_r1_addr_buffer_push),
            .o_r1_nonce_buffer_pop(sh_r1_nonce_buffer_pop),
            .o_r1_nonce_buffer_push(sh_r1_nonce_buffer_push),
            .o_r2_nonce_buffer_pop(sh_r2_nonce_buffer_pop),
            .o_r2_nonce_buffer_push(sh_r2_nonce_buffer_push),
            .o_r3_nonce_buffer_pop(sh_r3_nonce_buffer_pop),
            .o_r3_nonce_buffer_push(sh_r3_nonce_buffer_push),

            // end execution (datapath releases nonce at the same time)
            .o_done(shuffle_o_done),
            .o_nonce_pop(sh_nonce_pop) // indicate release of nonce to datapath
        );

        shuffle_piped_datapath #(
            .FIFO_READ_LATENCY(FIFO_READ_LATENCY),
            .CN_XHV(CN_XHV),
            .nonce_width(nonce_width),
            .addr_width(addr_width),
            .AES_latency(AES_latency),
            .multadd_latency(multadd_latency),
            .div_latency(div_latency),
            .buffer_depth(buffer_depth)
        )
        datapath(
            .clk(clk_fast), // clock
            .rst(~rstn_fast), // active high reset
            .i_state(sh_state), // state input for starting iteration
            .i_state_nonce(sh_nonce), // nonce corresponding to input state

            // controller signals
            .i_load_state_reg(sh_load_state_reg), // load input registers
            .i_r1_addr_mux_select(sh_r1_addr_mux_select), // mux for determining r1_addr
            .i_a_mux_select(sh_a_mux_select), // mux for determining a in AES
            .i_b_mux_select(sh_b_mux_select), // mux for determining b in XOR with c
            .i_dividend_valid(sh_dividend_valid), // inputs for div core
            .i_divisor_valid(sh_divisor_valid), // inputs for div core

            // FIFO signals
            .i_a2_buffer_pop(sh_a2_buffer_pop),
            .i_a2_buffer_push(sh_a2_buffer_push),
            .i_a3_buffer_pop(sh_a3_buffer_pop),
            .i_a3_buffer_push(sh_a3_buffer_push),
            .i_a4_buffer_pop(sh_a4_buffer_pop),
            .i_a4_buffer_push(sh_a4_buffer_push),
            .i_c1_buffer_pop(sh_c1_buffer_pop),
            .i_c1_buffer_push(sh_c1_buffer_push),
            .i_c2_buffer_pop(sh_c2_buffer_pop),
            .i_c2_buffer_push(sh_c2_buffer_push),
            .i_r1_addr_buffer_pop(sh_r1_addr_buffer_pop),
            .i_r1_addr_buffer_push(sh_r1_addr_buffer_push),
            .i_r1_nonce_buffer_pop(sh_r1_nonce_buffer_pop),
            .i_r1_nonce_buffer_push(sh_r1_nonce_buffer_push),
            .i_r2_nonce_buffer_pop(sh_r2_nonce_buffer_pop),
            .i_r2_nonce_buffer_push(sh_r2_nonce_buffer_push),
            .i_r3_nonce_buffer_pop(sh_r3_nonce_buffer_pop),
            .i_r3_nonce_buffer_push(sh_r3_nonce_buffer_push),

            // memory interfacing
            .o_r1_addr(sh_r1_addr),
            .i_r1_data(rev_sh_r1_data),
            .o_w1_addr(sh_w1_addr),
            .o_w1_data(sh_w1_data),

            .o_r2_addr(sh_r2_addr),
            .i_r2_data(rev_sh_r2_data),
            .o_w2_addr(sh_w2_addr),
            .o_w2_data(sh_w2_data),

            .o_r3_addr(sh_r3_addr),
            .i_r3_data(rev_sh_r3_data),
            .o_w3_addr(sh_w3_addr),
            .o_w3_data(sh_w3_data),

            // release nonce after execution
            .i_nonce_pop(sh_nonce_pop),
            .o_nonce(shuffle_o_nonce)
        );

        shuffle_axi #(
            .INT_ADDR_WIDTH(INT_ADDR_WIDTH),
            .C_M_AXI_BURST_LEN(1),
            .C_M_AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
            .C_M_AXI_DATA_WIDTH(AXI_DATA_WIDTH)
        )
        inst_shuffle_axi(
            .i_first_read(sh_first_read),
            .i_r1_addr(sh_r1_addr),
            .o_r1_data(sh_r1_data),
            .i_r1_request(sh_r1_request),
            .o_r1_valid(sh_r1_valid),
            .i_r2_addr(sh_r2_addr),
            .o_r2_data(sh_r2_data),
            .i_r2_request(sh_r2_request),
            .o_r2_valid(sh_r2_valid),
            .i_r3_addr(sh_r3_addr),
            .o_r3_data(sh_r3_data),
            .i_r3_request(sh_r3_request),
            .o_r3_valid(sh_r3_valid),

            .i_w1_addr(sh_w1_addr),
            .i_w1_data(rev_sh_w1_data),
            .i_w1_request(sh_w1_request),
            .i_w2_addr(sh_w2_addr),
            .i_w2_data(rev_sh_w2_data),
            .i_w2_request(sh_w2_request),
            .i_w3_addr(sh_w3_addr),
            .i_w3_data(rev_sh_w3_data),
            .i_w3_request(sh_w3_request),
            // User ports ends
            // Do not modify the ports beyond this line


            // Ports of Axi Master Bus Interface M01_AXI
            .axi_base_addr(axi_base_addr_fast),
            .M_AXI_ACLK(clk_fast),
            .M_AXI_ARESETN(rstn_fast),
            .M_AXI_AWADDR(m01_axi_awaddr),
            .M_AXI_AWLEN(m01_axi_awlen),
            .M_AXI_AWSIZE(m01_axi_awsize),
            .M_AXI_AWBURST(m01_axi_awburst),
            .M_AXI_AWVALID(m01_axi_awvalid),
            .M_AXI_AWREADY(m01_axi_awready),
            .M_AXI_WDATA(m01_axi_wdata),
            .M_AXI_WSTRB(m01_axi_wstrb),
            .M_AXI_WLAST(m01_axi_wlast),
            .M_AXI_WVALID(m01_axi_wvalid),
            .M_AXI_WREADY(m01_axi_wready),
            .M_AXI_BRESP(m01_axi_bresp),
            .M_AXI_BVALID(m01_axi_bvalid),
            .M_AXI_BREADY(m01_axi_bready),
            .M_AXI_ARADDR(m01_axi_araddr),
            .M_AXI_ARLEN(m01_axi_arlen),
            .M_AXI_ARSIZE(m01_axi_arsize),
            .M_AXI_ARBURST(m01_axi_arburst),
            .M_AXI_ARVALID(m01_axi_arvalid),
            .M_AXI_ARREADY(m01_axi_arready),
            .M_AXI_RDATA(m01_axi_rdata),
            .M_AXI_RRESP(m01_axi_rresp),
            .M_AXI_RLAST(m01_axi_rlast),
            .M_AXI_RVALID(m01_axi_rvalid),
            .M_AXI_RREADY(m01_axi_rready)
        );

        shuffle_loader #(
            .nonce_width(nonce_width),
            .explode_width(explode_width)
        )
        sh_loader(
            .clk(clk_fast),
            .rst(~rstn_fast),
            .i_ex_valid(shuffle_data_valid),
            .o_ex_handshake(shuffle_o_handshake),
            .i_ex_data(shuffle_i_data),
            .i_nonce(shuffle_i_nonce),
            .o_sh_valid(sh_state_valid),
            .i_sh_ready(sh_state_ready),
            .o_sh_data(sh_state),
            .o_nonce(sh_nonce)
        );

        shuffle_FIFO_unloader #(
            .nonce_width(nonce_width),
            .buffer_depth(buffer_depth)
        )
        sh_unloader (
            .clk(clk_fast),
            .rst(~rstn_fast),
            .i_shuffle_done(shuffle_o_done),
            .i_data(shuffle_o_nonce),
            .o_data(sh_imp_nonce),
            .o_handshake(sh_imp_handshake),
            .i_handshake_recv(sh_imp_handshake_recv)
        );
        assign sh_w1_request = sh_w1_valid;
        assign sh_w2_request = sh_w2_valid;
        assign sh_w3_request = sh_w3_valid;
        rev_bytes #(.SIZE(AXI_DATA_WIDTH)) rev_r1_data (.in(sh_r1_data), .out(rev_sh_r1_data));
        rev_bytes #(.SIZE(AXI_DATA_WIDTH)) rev_r2_data (.in(sh_r2_data), .out(rev_sh_r2_data));
        rev_bytes #(.SIZE(AXI_DATA_WIDTH)) rev_r3_data (.in(sh_r3_data), .out(rev_sh_r3_data));
        rev_bytes #(.SIZE(AXI_DATA_WIDTH)) rev_w1_data (.in(sh_w1_data), .out(rev_sh_w1_data));
        rev_bytes #(.SIZE(AXI_DATA_WIDTH)) rev_w2_data (.in(sh_w2_data), .out(rev_sh_w2_data));
        rev_bytes #(.SIZE(AXI_DATA_WIDTH)) rev_w3_data (.in(sh_w3_data), .out(rev_sh_w3_data));
        /* assign sh_r1_request = sh_r1_valid; */
        /* assign sh_r2_request = sh_r2_valid; */
        /* assign sh_r3_request = sh_r3_valid; */
    endgenerate

    // implode instantiation
    generate
        localparam implode_minimum_read_burst_len = 8;
        localparam implode_maximum_read_burst_len = 64;
        wire [255:0] imp_key;
        wire [1023:0] rev_imp_block, imp_block;
        wire [AXI_DATA_WIDTH-1:0] imp_read_data;
        wire [1023:0] implode_result;
        wire [nonce_width-1:0] imp_nonce, implode_nonce_data;
        wire [state_buffer_addr_width-1:0] implode_state_buffer_addr;
        wire [state_width-1:0] implode_state_data, imp_unloader_state;

        rev_bytes #(.SIZE(1024)) rev_implode_block (.in(rev_imp_block), .out(imp_block));
        implode_compact #(
            .NUM_ROUNDS(scratch_rounds)
        )
        implode(
            .clk(clk_slow),
            .rstn(rstn_slow),
            .start(imp_start),
            .key_bytes(imp_key),
            .block_bytes(imp_block),
            .scratch_read(imp_read_data),
            .newstate(implode_result),
            .done(implode_done),
            .data_valid(imp_read_valid),
            .request_read(imp_req_read)
        );

        implode_axi #(
            .NUM_ROUNDS(scratch_rounds),
            .nonce_width(nonce_width),
            .buffer_treshold1(implode_minimum_read_burst_len),
            .buffer_treshold2(implode_maximum_read_burst_len),
            .C_M_AXI_BURST_LEN(implode_maximum_read_burst_len),
            .C_M_AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
            .C_M_AXI_DATA_WIDTH(AXI_DATA_WIDTH)
        )
        inst_implode_axi(
            .i_request_read(imp_req_read),
            .o_data(imp_read_data),
            .o_data_valid(imp_read_valid),
            .i_nonce(imp_nonce),
            .i_nonce_valid(imp_nonce_valid),

            // User ports ends
            // Do not modify the ports beyond this line


            // Ports of Axi Master Bus Interface M00_AXI
            .axi_base_addr(axi_base_addr_slow),
            .M_AXI_ACLK(clk_slow),
            .M_AXI_ARESETN(rstn_slow),
            .M_AXI_ARADDR(m02_axi_araddr),
            .M_AXI_ARLEN(m02_axi_arlen),
            .M_AXI_ARSIZE(m02_axi_arsize),
            .M_AXI_ARBURST(m02_axi_arburst),
            .M_AXI_ARVALID(m02_axi_arvalid),
            .M_AXI_ARREADY(m02_axi_arready),
            .M_AXI_RDATA(m02_axi_rdata),
            .M_AXI_RLAST(m02_axi_rlast),
            .M_AXI_RVALID(m02_axi_rvalid),
            .M_AXI_RREADY(m02_axi_rready)
        );

        implode_loader #(
            .state_width(state_width),
            .block_width(block_width),
            .key_width(key_width),
            .nonce_width(nonce_width),
            .BRAM_addr_width(state_buffer_addr_width),
            .BRAM_delay(state_buffer_delay)
        )
        imp_loader(
            .clk(clk_slow),
            .rstn(rstn_slow),
            .i_state(implode_state_data),
            .i_nonce(implode_nonce_data),
            .i_nonce_valid(implode_nonce_valid),
            .key_bytes(imp_key),
            .block_bytes(rev_imp_block),
            .o_nonce(imp_nonce),
            .rd_en(implode_rd_en),
            .o_ready(implode_ready),
            .o_valid(imp_nonce_valid),
            .o_BRAM_addr(implode_state_buffer_addr),
            .o_rstn_implode(implode_rstn),
            .i_implode_done(implode_done),
            .o_state(imp_unloader_state)
        );

        wire [state_width+nonce_width-1:0] imp_conservator_data, imp_unloader_data;
        protocol_converter #(
            .IN_PROTOCOL(1),
            .OUT_PROTOCOL(2),
            .data_width(state_width+nonce_width),
            .busy_reg(0)
        )
        implode_conservator (
            .clk(clk_slow),
            .rstn(rstn_slow),
            .src_in(imp_nonce_valid),
            .src_out(imp_conservator_ready),
            .src_data({imp_nonce, imp_unloader_state}),
            .dst_in(imp_unloader_ready && implode_done),
            .dst_out(imp_conservator_valid),
            .dst_data(imp_conservator_data)
        );

        protocol_converter #(
            .IN_PROTOCOL(1),
            .OUT_PROTOCOL(1),
            .data_width(nonce_width+state_width),
            .busy_reg(0)
        )
        implode_unloader (
            .clk(clk_slow),
            .rstn(rstn_slow),
            .src_in(implode_done),
            .src_out(imp_unloader_ready),
            .src_data(imp_unloader_data),
            .dst_in(1'b1),
            .dst_out(o_done),
            .dst_data({o_nonce, o_data})
        );
        wire [block_width-1:0] implode_rev_result;
        rev_bytes #(.SIZE(block_width)) imp_data_rev (.in(implode_result), .out(implode_rev_result));

        assign imp_unloader_data = {imp_conservator_data[state_width+nonce_width-1:key_width*2+block_width], implode_rev_result, imp_conservator_data[key_width*2-1:0]};

        assign imp_start = imp_nonce_valid;
    endgenerate

    // cdc instantiations
    // explode to shuffle
    generate
        xpm_cdc_handshake #(
            .DEST_EXT_HSK(1),
            .DEST_SYNC_FF(4),
            .INIT_SYNC_FF(0),
            .SIM_ASSERT_CHK(0),
            .SRC_SYNC_FF(4),
            .WIDTH(explode_width+nonce_width)
        )
        explode_shuffle_handshake (
            .dest_out({shuffle_i_nonce, shuffle_i_data}),
            .dest_req(shuffle_data_valid),
            .src_rcv(explode_recv_handshake),
            .dest_ack(shuffle_o_handshake),
            .dest_clk(clk_fast),
            .src_clk(clk_slow),
            .src_in(explode_send_data),
            .src_send(explode_send_handshake)
        );

    endgenerate
    generate
        xpm_cdc_handshake #(
            .DEST_EXT_HSK(1),
            .DEST_SYNC_FF(4),
            .INIT_SYNC_FF(0),
            .SIM_ASSERT_CHK(0),
            .SRC_SYNC_FF(4),
            .WIDTH(nonce_width)
        )
        shuffle_implode_handshake (
            .dest_out(implode_nonce_data),
            .dest_req(implode_nonce_valid),
            .src_rcv(sh_imp_handshake_recv),
            .dest_ack(implode_ready),
            .dest_clk(clk_slow),
            .src_clk(clk_fast),
            .src_in(sh_imp_nonce),
            .src_send(sh_imp_handshake)
        );
    endgenerate

    // state buffer instantiation
    generate
        xpm_memory_sdpram #(
            .ADDR_WIDTH_A(state_buffer_addr_width),               // DECIMAL
            .ADDR_WIDTH_B(state_buffer_addr_width),               // DECIMAL
            .AUTO_SLEEP_TIME(URAM ? 3 : 0),            // DECIMAL
            .BYTE_WRITE_WIDTH_A(state_width),        // DECIMAL
            .CASCADE_HEIGHT(0),             // DECIMAL
            .CLOCKING_MODE("common_clock"), // String
            .ECC_MODE("no_ecc"),            // String
            .MEMORY_INIT_FILE("none"),      // String
            .MEMORY_INIT_PARAM("0"),        // String
            .MEMORY_OPTIMIZATION("true"),   // String
            .MEMORY_PRIMITIVE(URAM ? "ultra" : "auto"),      // String
            .MEMORY_SIZE(state_width * (2 ** nonce_width)),             // DECIMAL
            .MESSAGE_CONTROL(0),            // DECIMAL
            .READ_DATA_WIDTH_B(state_width),         // DECIMAL
            .READ_LATENCY_B(state_buffer_base_delay),             // DECIMAL
            .READ_RESET_VALUE_B("0"),       // String
            .RST_MODE_A("SYNC"),            // String
            .RST_MODE_B("SYNC"),            // String
            .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
            .USE_MEM_INIT(0),               // DECIMAL
            .USE_MEM_INIT_MMI(0),           // DECIMAL
            .WAKEUP_TIME(URAM ? "use_sleep_pin" : "disable_sleep"),  // This results in a wake up time of two clock periods
            .WRITE_DATA_WIDTH_A(state_width),        // DECIMAL
            .WRITE_MODE_B("no_change"),     // String
            .WRITE_PROTECT(1)               // DECIMAL
        )
        state_buffer (
            .doutb(implode_state_data),                   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
            .addra(exp_state_buffer_addr),                   // ADDR_WIDTH_A-bit input: Address for port A write operations.
            .addrb(implode_state_buffer_addr),                   // ADDR_WIDTH_B-bit input: Address for port B read operations.
            .clka(clk_slow),                     // 1-bit input: Clock signal for port A. Also clocks port B when
            // parameter CLOCKING_MODE is "common_clock".

            .clkb(clk_slow),                     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
            // "independent_clock". Unused when parameter CLOCKING_MODE is
            // "common_clock".

            .dina(exp_state_buffer_data),                     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
            .ena(exp_state_buffer_wr_en),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
            // cycles when write operations are initiated. Pipelined internally.

            .enb(implode_rd_en),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
            // cycles when read operations are initiated. Pipelined internally.

            .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
            // ECC enabled (Error injection capability is not available in
            // "decode_only" mode).

            .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
            // ECC enabled (Error injection capability is not available in
            // "decode_only" mode).

            .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
            // data path.

            .rstb(~rstn_slow),                     // 1-bit input: Reset signal for the final port B output register stage.
            // Synchronously resets output port doutb to the value specified by
            // parameter READ_RESET_VALUE_B.

            .sleep(URAM ? ~(exp_state_buffer_wr_en || implode_rd_en) : 1'b0),                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
            .wea(exp_state_buffer_wr_en)                        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
            // for port A input data port dina. 1 bit wide when word-wide writes are
            // used. In byte-wide write configurations, each bit controls the
            // writing one byte of dina to address addra. For example, to
            // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
            // is 32, wea would be 4'b0010.

        );
    endgenerate
endmodule
