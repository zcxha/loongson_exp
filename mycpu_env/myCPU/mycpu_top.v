`include "define.v"
module mycpu_top (
        input  wire        aclk,
        input  wire        aresetn,

        // ar
        output wire [4:0] arid,
        output wire [31:0] araddr,
        output wire [7:0] arlen,
        output wire [2:0] arsize,
        output wire [1:0] arburst,
        output wire [1:0] arlock,
        output wire [3:0] arcache,
        output wire [2:0] arprot,
        output wire arvalid,
        input wire arready,

        // r
        input wire [3:0] rid,
        input wire [31:0] rdata,
        input wire [1:0] rresp,
        input wire rlast,
        input wire rvalid,
        output wire rready,

        // aw
        output wire [3:0] awid,
        output wire [31:0] awaddr,
        output wire [7:0] awlen,
        output wire [2:0] awsize,
        output wire [1:0] awburst,
        output wire [1:0] awlock,
        output wire [3:0] awcache,
        output wire [2:0] awprot,
        output wire awvalid,
        input wire awready,

        // w
        output wire [3:0] wid,
        output wire [31:0] wdata,
        output wire [3:0] wstrb,
        output wire wlast,
        output wire wvalid,
        input wire wready,

        // b
        input wire [3:0] bid,
        input wire [1:0] bresp,
        input wire bvalid,
        output wire bready,

        output wire [31:0] debug_wb_pc,
        output wire [ 3:0] debug_wb_rf_we,
        output wire [ 4:0] debug_wb_rf_wnum,
        output wire [31:0] debug_wb_rf_wdata
    );

    wire core_inst_sram_req;
    wire core_inst_sram_wr;
    wire [1:0] core_inst_sram_size;
    wire [7:0] core_inst_sram_index;
    wire [19:0] core_inst_sram_tag;
    wire [3:0] core_inst_sram_offset;
    wire [3:0] core_inst_sram_wstrb;
    wire [31:0] core_inst_sram_wdata;
	wire [1:0] core_inst_sram_mat;
	wire core_inst_sram_cacop_op;
	wire [2:0] core_inst_sram_cacop_code;
    wire core_inst_sram_addr_ok;
    wire core_inst_sram_data_ok;
    wire [31:0] core_inst_sram_rdata;

    wire core_data_sram_req;
    wire core_data_sram_wr;
	wire [7:0] core_data_sram_index;
	wire [19:0] core_data_sram_tag;
	wire [3:0] core_data_sram_offset;
    wire [3:0] core_data_sram_wstrb;
    wire [31:0] core_data_sram_wdata;
	wire [1:0] core_data_sram_mat;
	wire core_data_sram_cacop_op;
	wire [2:0] core_data_sram_cacop_code;
    wire core_data_sram_addr_ok;
    wire core_data_sram_data_ok;
    wire [31:0] core_data_sram_rdata;


    core u_core (
             .clk		(aclk),
             .resetn 	(aresetn),

             // pipeline -> icache

             .inst_sram_req	(core_inst_sram_req),
             .inst_sram_wr	(core_inst_sram_wr),
             .inst_sram_index (core_inst_sram_index),
             .inst_sram_tag (core_inst_sram_tag),
             .inst_sram_offset (core_inst_sram_offset),
             .inst_sram_wstrb (core_inst_sram_wstrb),
             .inst_sram_wdata (core_inst_sram_wdata),
			 .inst_sram_mat (core_inst_sram_mat),
			 .inst_sram_cacop_op (core_inst_sram_cacop_op),
			 .inst_sram_cacop_code (core_inst_sram_cacop_code),

             // 
             .inst_sram_addr_ok (core_inst_sram_addr_ok),
             .inst_sram_data_ok (core_inst_sram_data_ok),
             .inst_sram_rdata (core_inst_sram_rdata),

             // pipeline -> dcache

             .data_sram_req	(core_data_sram_req),
             .data_sram_wr	(core_data_sram_wr),
			 .data_sram_index (core_data_sram_index),
			 .data_sram_tag (core_data_sram_tag),
			 .data_sram_offset (core_data_sram_offset),
             .data_sram_wstrb (core_data_sram_wstrb),
             .data_sram_wdata (core_data_sram_wdata),
			 .data_sram_mat (core_data_sram_mat),
			 .data_sram_cacop_op (core_data_sram_cacop_op),
			 .data_sram_cacop_code (core_data_sram_cacop_code),
             // 
             .data_sram_addr_ok (core_data_sram_addr_ok),
             .data_sram_data_ok (core_data_sram_data_ok),
             .data_sram_rdata (core_data_sram_rdata),

             .debug_wb_pc	(debug_wb_pc),
             .debug_wb_rf_we (debug_wb_rf_we),
             .debug_wb_rf_wnum (debug_wb_rf_wnum),
             .debug_wb_rf_wdata (debug_wb_rf_wdata)
         );
	// output declaration of module cache
	wire rd_req;
	wire [2:0] rd_type;
	wire [31:0] rd_addr;
	wire wr_req;
	wire [2:0] wr_type;
	wire [31:0] wr_addr;
	wire [3:0] wr_wstrb;
	wire [127:0] wr_data;

	// input
	wire rd_rdy;
	wire ret_valid;
	wire ret_last;
	wire [31:0] ret_data;
	
	cache i_cache(
		.clk       	(aclk        ),
		.resetn    	(aresetn     ),
		.valid     	(core_inst_sram_req      ),
		.op        	(core_inst_sram_wr         ),
		.index     	(core_inst_sram_index      ),
		.tag       	(core_inst_sram_tag        ),
		.offset    	(core_inst_sram_offset     ),
		.wstrb     	(core_inst_sram_wstrb      ),
		.wdata     	(core_inst_sram_wdata      ),
		.mat		(core_inst_sram_mat		   ),
		.cacop_op   (core_inst_sram_cacop_op   ),
		.cacop_code (core_inst_sram_cacop_code ), 

		.addr_ok   	(core_inst_sram_addr_ok    ),
		.data_ok   	(core_inst_sram_data_ok    ),
		.rdata     	(core_inst_sram_rdata      ),

		.rd_req    	(rd_req     ),
		.rd_type   	(rd_type    ),
		.rd_addr   	(rd_addr    ),
		.rd_rdy    	(rd_rdy     ),
		.ret_valid 	(ret_valid  ),
		.ret_last  	(ret_last   ),
		.ret_data  	(ret_data   ),
		.wr_req    	(wr_req     ),
		.wr_type   	(wr_type    ),
		.wr_addr   	(wr_addr    ),
		.wr_wstrb  	(wr_wstrb   ),
		.wr_data   	(wr_data    ),
		.wr_rdy    	(1     )
	);


	wire dcrd_req;
	wire [2:0] dcrd_type;
	wire [31:0] dcrd_addr;
	wire dcrd_rdy;
	wire dcret_valid;
	wire dcret_last;
	wire [31:0] dcret_data;
	wire dcwr_req;
	wire [2:0] dcwr_type;
	wire [31:0] dcwr_addr;
	wire [3:0] dcwr_wstrb;
	wire [127:0] dcwr_data;

	wire dcwr_rdy;
	cache d_cache(
		.clk       	(aclk        ),
		.resetn    	(aresetn     ),
		.valid     	(core_data_sram_req      ),
		.op        	(core_data_sram_wr         ),
		.index     	(core_data_sram_index      ),
		.tag       	(core_data_sram_tag        ),
		.offset    	(core_data_sram_offset     ),
		.wstrb     	(core_data_sram_wstrb      ),
		.wdata     	(core_data_sram_wdata      ),
		.mat		(core_data_sram_mat		   ),
		.cacop_op   (core_data_sram_cacop_op   ),
		.cacop_code (core_data_sram_cacop_code ),
		.addr_ok   	(core_data_sram_addr_ok    ),
		.data_ok   	(core_data_sram_data_ok    ),
		.rdata     	(core_data_sram_rdata      ),
		.rd_req    	(dcrd_req     ),
		.rd_type   	(dcrd_type    ),
		.rd_addr   	(dcrd_addr    ),
		.rd_rdy    	(dcrd_rdy     ),
		.ret_valid 	(dcret_valid  ),
		.ret_last  	(dcret_last   ),
		.ret_data  	(dcret_data   ),
		.wr_req    	(dcwr_req     ),
		.wr_type   	(dcwr_type    ),
		.wr_addr   	(dcwr_addr    ),
		.wr_wstrb  	(dcwr_wstrb   ),
		.wr_data   	(dcwr_data    ),
		.wr_rdy    	(dcwr_rdy     )
	);

	// type = 000 字节 001 半字 010 字 100 cache line
	// 对应burst size 000 001 010 
	// 100单独每个burst4字节 即 size=010 len=4

    sram_to_axi_bridge_2_1 u_sram_to_axi_bridge_2_1(
            .clk				(aclk),
            .resetn				(aresetn),

    		// input
            .icache_rd_req		(rd_req),
            .icache_rd_type		(rd_type),
            .icache_rd_addr		(rd_addr),
			// output
            .icache_rd_rdy		(rd_rdy),
            .icache_ret_valid	(ret_valid),
            .icache_ret_last	(ret_last),
			.icache_ret_data    (ret_data),

    		// input
            .dcache_rd_req		(dcrd_req),
            .dcache_rd_type		(dcrd_type),
            .dcache_rd_addr		(dcrd_addr),
			// output
            .dcache_rd_rdy		(dcrd_rdy),
            .dcache_ret_valid	(dcret_valid),
            .dcache_ret_last	(dcret_last),
			.dcache_ret_data    (dcret_data),

			.dcache_wr_req	(dcwr_req),
			.dcache_wr_addr (dcwr_addr),
			.dcache_wr_type (dcwr_type),
			.dcache_wr_wstrb (dcwr_wstrb),
			.dcache_wr_data (dcwr_data),
			.dcache_wr_rdy (dcwr_rdy),
    		// ar
    		.arid		(arid),
    		.araddr		(araddr),
    		.arlen		(arlen),
    		.arsize		(arsize),
    		.arburst	(arburst),
    		.arlock		(arlock),
    		.arcache	(arcache),
    		.arprot		(arprot),
    		.arvalid	(arvalid),
    		.arready	(arready),

    		// r
    		.rid		(rid),
    		.rdata		(rdata),
    		.rresp		(rresp),
    		.rlast		(rlast),
    		.rvalid		(rvalid),
    		.rready		(rready),

    		// aw
    		.awid		(awid),
    		.awaddr		(awaddr),
    		.awlen		(awlen),
    		.awsize		(awsize),
    		.awburst	(awburst),
    		.awlock		(awlock),
    		.awcache	(awcache),
    		.awprot		(awprot),
    		.awvalid	(awvalid),
    		.awready	(awready),

    		// w
    		.wid		(wid),
    		.wdata		(wdata),
    		.wstrb		(wstrb),
    		.wlast		(wlast),
    		.wvalid		(wvalid),
    		.wready		(wready),

    		// b
    		.bid		(bid),
    		.bresp		(bresp),
    		.bvalid		(bvalid),
    		.bready		(bready)
        );
endmodule
