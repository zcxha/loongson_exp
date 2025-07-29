module sram_to_axi_bridge_2_1 (
        input wire clk,
        input wire resetn,

        /* 两个类SRAM从方 */
        // Icache
        input wire icache_rd_req, // icache 发起读请求
        input wire [2:0] icache_rd_type, // 3'b000 byte 3'b001 half word 3'b010 word 3'b100 cache line (128b)
        input wire [31:0] icache_rd_addr, // icache读地址

        output wire icache_rd_rdy, // 准备接收读请求
        output wire icache_ret_valid, // 读返回数据有效
        output wire icache_ret_last, // 返回burst最后一个数据
        output wire [31:0] icache_ret_data, // 读返回数据

        // Dcache read
        input wire dcache_rd_req,
        input wire [2:0] dcache_rd_type, // 3'b000 byte 3'b001 half word 3'b010 word 3'b100 cache block
        input wire [31:0] dcache_rd_addr,

        output wire dcache_rd_rdy,
        output wire dcache_ret_valid,
        output wire dcache_ret_last,
        output wire [31:0] dcache_ret_data,

        // Dcache write
        input wire dcache_wr_req, // 写请求
        input wire [2:0] dcache_wr_type, // 3'b000 byte 3'b001 half word 3'b010 word 3'b100 cache block (128b)
        input wire [31:0] dcache_wr_addr, // 写地址
        input wire [3:0] dcache_wr_wstrb, // 写字节掩码
        input wire [127:0] dcache_wr_data, // 写数据
        output wire dcache_wr_rdy, // 准备接收写请求

        /* 一个AXI主方 */

        // ar
        output wire [3:0] arid, // 读请求ID
        output wire [31:0] araddr, // 读请求地址
        output wire [7:0] arlen, // 读请求传输长度
        output wire [2:0] arsize, // 读请求传输大小
        output wire [1:0] arburst, // burst类型
        output wire [1:0] arlock, // 锁类型
        output wire [3:0] arcache, // 缓存类型
        output wire [2:0] arprot, // 保护属性
        output wire arvalid, // master->slave 读请求地址握手信号，读请求地址有效
        input wire arready, // slave->master 读请求地址握手信号，从方准备好接受地址传输

        // r
        input wire [3:0] rid, // 读请求ID 相同事务应该跟arid一致
        input wire [31:0] rdata, // 读请求读回的数据
        input wire [1:0] rresp, // 本次读请求是否成功完成
        input wire rlast, // 是否为本次burst的最后一拍数据
        input wire rvalid, // slave -> master 读请求数据握手信号，读请求数据有效
        output wire rready, // master -> slave 读请求数据握手信号，主方准备好接收数据传输

        // aw
        output wire [3:0] awid, // 写请求ID
        output wire [31:0] awaddr, // 写请求地址
        output wire [7:0] awlen, // 写请求传输长度
        output wire [2:0] awsize, // 写请求传输大小
        output wire [1:0] awburst, // burst类型
        output wire [1:0] awlock, // 锁
        output wire [3:0] awcache, // 缓存
        output wire [2:0] awprot, // 保护属性
        output reg awvalid, // master->slave 写请求地址握手信号，写请求地址有效
        input wire awready, // slave->master 写请求地址握手信号，从方准备好接收地址传输

        // w
        output wire [3:0] wid, // 写请求ID
        output reg [31:0] wdata, // 写数据
        output reg [3:0] wstrb, // 写选通
        output reg wlast, // 是否为最后一拍数据
        output reg wvalid, // master->slave 写请求数据握手信号，写请求数据有效
        input wire wready, // slave->master 写请求数据握手信号，从方准备好接收数据传输

        // b
        input wire [3:0] bid, // 写请求ID号 同一请求bid wid awid 一致
        input wire [1:0] bresp, // 表示本请求是否成功完成
        input wire bvalid, // slave->master 写响应握手信号，写请求响应有效
        output wire bready // 写请求响应握手信号，主方准备好接收写响应
    );

    localparam IDLE = 3'b000;
    localparam IC_RD = 3'b001;
    localparam DC_RD = 3'b010;

    reg state;
    always @(posedge clk) begin
        if (~resetn) begin
            state <= IDLE;
        end
        else begin
            case (state)
                IDLE: begin
                    if (dcache_rd_req) begin
                        state <= DC_RD;
                    end
                    else if (icache_rd_req) begin
                        state <= IC_RD;
                    end
                end
                IC_RD: begin
                    if (rvalid&&rlast) begin
                        if (dcache_rd_req) begin
                            state <= DC_RD;
                        end
                        else begin
                            state <= IDLE;
                        end
                    end
                end
                DC_RD: begin
                    if (rvalid&&rlast) begin
                        if (icache_rd_req) begin
                            state <= IC_RD;
                        end
                        else begin
                            state <= IDLE;
                        end
                    end
                end
            endcase
        end
    end

    // REQ MUX
    // r
    assign arvalid = icache_rd_req | dcache_rd_req;
    assign arid = dcache_rd_req ? 1 :
           0;
    assign araddr = dcache_rd_req ? dcache_rd_addr :
           /*icache_rd_req */ icache_rd_addr ;

    assign arlen = 7'b011; // len = 3 + 1 = 4
    assign arsize = 3'b010 ; // size = 2 ^ 2 = 4 byte
    assign arburst = 2'b01; // add
    assign arlock = 0;
    assign arcache = 0;
    assign arprot = 0;
    assign rready = 1;


    // 状态机组合逻辑
    assign icache_rd_rdy = arready & icache_rd_req;
    assign icache_ret_valid = rvalid & state==IC_RD;
    assign icache_ret_last = rlast & state==IC_RD;
    assign icache_ret_data = state==IC_RD ? rdata : 32'b0;

    assign dcache_rd_rdy = arready & dcache_rd_req;
    assign dcache_ret_valid = rvalid & state==DC_RD;
    assign dcache_ret_last = rlast & state==DC_RD;
    assign dcache_ret_data = state==DC_RD ? rdata : 32'b0;

    localparam DC_WR_WAIT = 3'b011;
    localparam DC_WR = 3'b100;
    localparam DC_WR1 = 3'b101;
    localparam DC_WR2 = 3'b110;

    // aw/w
    assign awid = 1;
    assign awaddr = dcache_wr_addr;
    assign awlen = 7'b011;
    assign awsize = 3'b010;
    assign awburst = 2'b01;
    assign awlock = 0;
    assign awcache = 0;
    assign awprot = 0;

    assign wid = 1;


    reg [127:0] wr_buffer;
    reg [2:0] w_state;
    always @(posedge clk) begin
        if (~resetn) begin
            wr_buffer <= 128'b0;
            w_state <= IDLE;
        end
        case (w_state)
            IDLE: begin
                if (wready) begin
                    wvalid <= 0;
                    wlast <= 0;
                end
                if (dcache_wr_req) begin
                    wr_buffer <= dcache_wr_data;
                    wstrb <= dcache_wr_wstrb;
					awvalid <= 1;

                    w_state <= DC_WR_WAIT;
                end
            end
            DC_WR_WAIT: begin
                if (awready) begin
                    w_state <= DC_WR;

					awvalid <= 0;
                    wdata <= wr_buffer[31:0];
                    wvalid <= 1;
                end
            end
            DC_WR: begin
                if (wready) begin
                    w_state <= DC_WR1;

                    wdata <= wr_buffer[63:32];
                end
            end
            DC_WR1: begin
                if (wready) begin
                    w_state <= DC_WR2;

                    wdata <= wr_buffer[95:64];
                end
            end
            DC_WR2: begin
                if (wready) begin
                    w_state <= IDLE;

                    wdata <= wr_buffer[127:96];
                    wlast <= 1;
                end
            end
        endcase
    end

    assign dcache_wr_rdy = w_state==IDLE;


endmodule
