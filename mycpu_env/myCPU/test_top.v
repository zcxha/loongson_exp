`include "define.v"
module mycpu_top1 #
    (
        parameter WIDTH = 500
    )
    (
        input  wire        clk,
        input  wire        resetn,
        // inst sram interface bus
        output reg		   inst_sram_req, // 请求信号 1表示有读写请求，0表示无读写请求
        output wire        inst_sram_wr, // 为1表示该次是写请求，0表示是读请求
        output wire	[1:0]  inst_sram_size, // 请求传输字节数 0:1字节 1:2字节 2:4字节
        output reg [31:0] inst_sram_addr, //
        output wire [3:0]  inst_sram_wstrb, // 该次字节写使能
        output wire [31:0] inst_sram_wdata, //
        input  wire		   inst_sram_addr_ok, // 该次请求地址传输OK 读：地址被接收 写：地址和数据被接收
        input  wire		   inst_sram_data_ok, // 该次请求的数据传输OK 读：数据返回 写：数据写入完成
        input  wire [31:0] inst_sram_rdata,
        // data sram interface bus
        output wire		   data_sram_req,
        output wire        data_sram_wr,
        output wire [1:0]  data_sram_size,
        output wire [31:0] data_sram_addr,
        output wire [3:0]  data_sram_wstrb,
        output wire [31:0] data_sram_wdata,
        input  wire        data_sram_addr_ok,
        input  wire        data_sram_data_ok,
        input  wire [31:0] data_sram_rdata,
        // trace debug interface
        output wire [31:0] debug_wb_pc,
        output wire [ 3:0] debug_wb_rf_we,
        output wire [ 4:0] debug_wb_rf_wnum,
        output wire [31:0] debug_wb_rf_wdata
    );
	reg [31:0] pc;
	assign inst_sram_size = 2;
	assign inst_sram_wr = 0;
	always @(posedge clk) begin
		if (~resetn) begin
			inst_sram_req <= 0;
			pc <= 32'h1c000000;
		end
		else if (inst_sram_req == 0) begin
			inst_sram_req = 1;
			inst_sram_addr <= pc;
			pc <= pc + 4;
		end
		else if (inst_sram_addr_ok) begin
			inst_sram_req = 0;
		end
	end
endmodule