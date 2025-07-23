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
    wire [31:0] core_inst_sram_addr;
    wire [3:0] core_inst_sram_wstrb;
    wire [31:0] core_inst_sram_wdata;
    wire core_inst_sram_addr_ok;
    wire core_inst_sram_data_ok;
    wire [31:0] core_inst_sram_rdata;

    wire core_data_sram_req;
    wire core_data_sram_wr;
    wire [1:0] core_data_sram_size;
    wire [31:0] core_data_sram_addr;
    wire [3:0] core_data_sram_wstrb;
    wire [31:0] core_data_sram_wdata;
    wire core_data_sram_addr_ok;
    wire core_data_sram_data_ok;
    wire [31:0] core_data_sram_rdata;

    core u_core (
             .clk		(aclk),
             .resetn 	(aresetn),

             // SRAM master -> slave

             .inst_sram_req	(core_inst_sram_req),
             .inst_sram_wr	(core_inst_sram_wr),
             .inst_sram_size (core_inst_sram_size),
             .inst_sram_addr (core_inst_sram_addr),
             .inst_sram_wstrb (core_inst_sram_wstrb),
             .inst_sram_wdata (core_inst_sram_wdata),

             // SRAM slave -> master
             .inst_sram_addr_ok (core_inst_sram_addr_ok),
             .inst_sram_data_ok (core_inst_sram_data_ok),
             .inst_sram_rdata (core_inst_sram_rdata),

             // SRAM master -> slave

             .data_sram_req	(core_data_sram_req),
             .data_sram_wr	(core_data_sram_wr),
             .data_sram_size (core_data_sram_size),
             .data_sram_addr (core_data_sram_addr),
             .data_sram_wstrb (core_data_sram_wstrb),
             .data_sram_wdata (core_data_sram_wdata),

             // SRAM slave -> master
             .data_sram_addr_ok (core_data_sram_addr_ok),
             .data_sram_data_ok (core_data_sram_data_ok),
             .data_sram_rdata (core_data_sram_rdata),

             .debug_wb_pc	(debug_wb_pc),
             .debug_wb_rf_we (debug_wb_rf_we),
             .debug_wb_rf_wnum (debug_wb_rf_wnum),
             .debug_wb_rf_wdata (debug_wb_rf_wdata)
         );

    sram_to_axi_bridge_2_1 (
            .clk				(aclk),
            .resetn				(aresetn),
            
			// input 
            .inst_sram_req		(core_inst_sram_req),
            .inst_sram_wr		(core_inst_sram_wr),
            .inst_sram_size		(core_inst_sram_size),
            .inst_sram_addr		(core_inst_sram_addr),
            .inst_sram_wstrb	(core_inst_sram_wstrb),
            .inst_sram_wdata	(core_inst_sram_wdata),

			// output
            .inst_sram_addr_ok	(core_inst_sram_addr_ok),
            .inst_sram_data_ok	(core_inst_sram_data_ok),
            .inst_sram_rdata	(core_inst_sram_rdata),

			// input
            .data_sram_req		(core_data_sram_req),
            .data_sram_wr		(core_data_sram_wr),
            .data_sram_size		(core_data_sram_size),
            .data_sram_addr		(core_data_sram_addr),
            .data_sram_wstrb	(core_data_sram_wstrb),
            .data_sram_wdata	(core_data_sram_wdata),

			// output 
            .data_sram_addr_ok	(core_data_sram_addr_ok),
            .data_sram_data_ok	(core_data_sram_data_ok),
            .data_sram_rdata	(core_data_sram_rdata),
			
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
