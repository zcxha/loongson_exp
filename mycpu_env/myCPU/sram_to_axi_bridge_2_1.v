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
        output reg [7:0] arlen, // 读请求传输长度
        output reg [2:0] arsize, // 读请求传输大小
        output wire [1:0] arburst, // burst类型
        output wire [1:0] arlock, // 锁类型
        output wire [3:0] arcache, // 缓存类型
        output wire [2:0] arprot, // 保护属性
        output reg arvalid, // master->slave 读请求地址握手信号，读请求地址有效
        input wire arready, // slave->master 读请求地址握手信号，从方准备好接受地址传输

        // r
        input wire [3:0] rid, // 读请求ID 相同事务应该跟arid一致
        input wire [31:0] rdata, // 读请求读回的数据
        input wire [1:0] rresp, // 本次读请求是否成功完成
        input wire rlast, // 是否为本次burst的最后一拍数据
        input wire rvalid, // slave -> master 读请求数据握手信号，读请求数据有效
        output reg rready, // master -> slave 读请求数据握手信号，主方准备好接收数据传输

        // aw
        output wire [3:0] awid, // 写请求ID
        output reg [31:0] awaddr, // 写请求地址
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

    // ar
    // REQ MUX


    assign arburst = 2'b01; // add
    assign arlock = 0;
    assign arcache = 0;
    assign arprot = 0;

    localparam AR_IDLE = 3'b000;
    localparam AR_WAIT = 3'b001;
    localparam AR_READ = 3'b010;
    reg [2:0] ar_state;
    reg [1:0] handshake_ok;
    reg req_type; // 0 inst 1 data

    always @(posedge clk) begin
        if (~resetn) begin
            arvalid <= 0;
            ar_state <= AR_IDLE;
            req_type <= 0;

            rready <= 0;

            handshake_ok <= 2'b0;
        end
        case (ar_state)
            AR_IDLE: begin
                handshake_ok <= 2'b0;

                if (aw_w_state==AW_W_IDLE) begin
                    if (dcache_rd_req) begin
                        req_type <= 1;
                        arvalid <= 1;
                        arlen <= dcache_rd_type==3'b010 ? 7'b000 :7'b011;
                        arsize <= 3'b010;

                        rready <= 0;

                        ar_state <= AR_WAIT;
                    end
                    else if (icache_rd_req) begin
                        req_type <= 0;
                        arvalid <= 1;
                        arlen <= icache_rd_type==3'b010 ? 7'b000 :7'b011;
                        arsize <= 3'b010;

                        rready <= 0;

                        ar_state <= AR_WAIT;
                    end
                end
            end
            AR_WAIT: begin
                if (arvalid && arready) begin
                    arvalid <= 0;

                    rready <= 1;

                    handshake_ok[req_type] <= 1;

                    ar_state <= AR_READ;
                end
            end
            AR_READ: begin
                if (rvalid && rlast) begin
                    ar_state <= AR_IDLE;
                end
            end
        endcase
    end
    assign arid = {3'b0,req_type};
    assign araddr = req_type ? dcache_rd_addr :
           /*icache_rd_req */ icache_rd_addr ;

    // r
    // 状态机组合逻辑


    assign icache_rd_rdy = handshake_ok[0];
    assign icache_ret_valid = rvalid && rid==4'b0 && handshake_ok[0];
    assign icache_ret_last = rlast && rid==4'b0 && handshake_ok[0];
    assign icache_ret_data = (handshake_ok[0] && rid==4'b0) ? rdata : 32'b0;

    assign dcache_rd_rdy = handshake_ok[1];
    assign dcache_ret_valid = rvalid && rid==4'd1 && handshake_ok[1];
    assign dcache_ret_last = rlast && rid==4'd1 && handshake_ok[1];
    assign dcache_ret_data = (handshake_ok[1] && rid==4'd1) ? rdata : 32'b0;

    // aw/w
    assign awid = {3'b0,1};
    assign awlen = dcache_wr_type==3'b010 ? 7'b000 : 7'b011;
    assign awsize = 3'b010;
    assign awburst = 2'b01;
    assign awlock = 0;
    assign awcache = 0;
    assign awprot = 0;

    assign wid = {3'b0,1};

    localparam AW_W_IDLE = 3'b000;
    localparam AW_W_WAIT = 3'b001;
    localparam AW_W_WCYCLE = 3'b010;
    localparam B_WAIT = 3'b011;

    reg [2:0] aw_w_state;
    reg [127:0] aw_w_wdata_buffer;
    reg [1:0] aw_w_cnt;

    always @(posedge clk) begin
        if (~resetn) begin
            aw_w_state <= AW_W_IDLE;
            aw_w_wdata_buffer <= 128'b0;
            aw_w_cnt <= 2'b0;

            awvalid <= 0;

            wvalid <= 0;
            wlast <= 0;
        end
        case (aw_w_state)
            AW_W_IDLE: begin
                if (dcache_wr_req) begin
                    awvalid <= 1;
                    awaddr <= dcache_wr_addr;

                    wstrb <= dcache_wr_wstrb;

                    aw_w_wdata_buffer <= dcache_wr_data;
                    aw_w_state <= AW_W_WAIT;
                end
            end
            AW_W_WAIT: begin
                if (awvalid && awready) begin
                    awvalid <= 0;

                    wvalid <= 1;
                    wdata <= aw_w_wdata_buffer[31:0];
                    aw_w_cnt <= 2'b0;
                    wlast <= dcache_wr_type==3'b010 ? 1 : 0;

                    aw_w_state <= AW_W_WCYCLE;
                end
            end
            AW_W_WCYCLE: begin
                if (wvalid&&wready) begin
                    if (dcache_wr_type==3'b100) begin // 一致可缓存访问
                        aw_w_cnt <= aw_w_cnt + 1;

                        if (aw_w_cnt == 2'b00) begin
                            wdata <= aw_w_wdata_buffer[63:32];
                        end
                        else if (aw_w_cnt == 2'b01) begin
                            wdata <= aw_w_wdata_buffer[95:64];
                        end
                        else if (aw_w_cnt == 2'b10) begin
                            wdata <= aw_w_wdata_buffer[127:96];
                            wlast <= 1;
                        end
                        else if (aw_w_cnt == 2'b11) begin
                            aw_w_state <= B_WAIT;
                            wvalid <= 0;
                            wlast <= 0;
                        end
                        else begin
                            wdata <= 32'hdeadbeef;
                        end
                    end
                    else if (dcache_wr_type==3'b010) begin // 强序非缓存访问
                        wvalid <= 0;
                        wlast <= 0;

                        aw_w_state <= B_WAIT;
                    end
                end
            end
            B_WAIT: begin

                if (bvalid&&bready) begin
                    aw_w_state <= AW_W_IDLE;
                end
            end
        endcase
    end

    assign bready = 1;

    assign dcache_wr_rdy = aw_w_state==AW_W_IDLE;





endmodule
