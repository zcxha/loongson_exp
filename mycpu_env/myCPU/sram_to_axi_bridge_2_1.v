module sram_to_axi_bridge_2_1 (
        input wire clk,
        input wire resetn,

        /* 两个类SRAM从方 */
        input wire inst_sram_req,
        input wire inst_sram_wr,
        input wire [1:0] inst_sram_size,
        input wire [31:0] inst_sram_addr,
        input wire [3:0] inst_sram_wstrb,
        input wire [31:0] inst_sram_wdata,

        output reg inst_sram_addr_ok,
        output reg inst_sram_data_ok,
        output reg [31:0] inst_sram_rdata,

        input wire data_sram_req,
        input wire data_sram_wr,
        input wire [1:0] data_sram_size,
        input wire [31:0] data_sram_addr,
        input wire [3:0] data_sram_wstrb,
        input wire [31:0] data_sram_wdata,

        output reg data_sram_addr_ok,
        output reg data_sram_data_ok,
        output reg [31:0] data_sram_rdata,

        /* 一个AXI主方 */

        // ar
        output reg [4:0] arid, // 读请求ID
        output reg [31:0] araddr, // 读请求地址
        output wire [7:0] arlen, // 读请求传输长度
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
        output reg [2:0] awsize, // 写请求传输大小
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
        output wire wlast, // 是否为最后一拍数据
        output reg wvalid, // master->slave 写请求数据握手信号，写请求数据有效
        input wire wready, // slave->master 写请求数据握手信号，从方准备好接收数据传输

        // b
        input wire [3:0] bid, // 写请求ID号 同一请求bid wid awid 一致
        input wire [1:0] bresp, // 表示本请求是否成功完成
        input wire bvalid, // slave->master 写响应握手信号，写请求响应有效
        output wire bready // 写请求响应握手信号，主方准备好接收写响应
    );

    wire req_type = data_sram_req ? 1 : 0; // 数据访问为1 指令访问为0

    wire sram_req = req_type ? data_sram_req : inst_sram_req;
    wire sram_wr = req_type ? data_sram_wr : inst_sram_wr;
    wire [1:0] sram_size = req_type ? data_sram_size : inst_sram_size;
    wire [31:0] sram_addr = req_type ? data_sram_addr : inst_sram_addr;
    wire [3:0] sram_wstrb = req_type ? data_sram_wstrb : inst_sram_wstrb;
    wire [31:0] sram_wdata = req_type ? data_sram_wdata : inst_sram_wdata;


    parameter AR_IDLE = 2'b00;
    parameter AR_WAIT = 2'b01;

    reg [1:0] ar_state;
    parameter AW_W_IDLE = 2'b00;
    parameter AW_W_ADDR = 2'b01;
    parameter AW_W_DATA = 2'b10;
    parameter B_WAIT = 2'b11;
    reg [1:0] aw_w_state;

    reg b_has_resp;

    // ar
    assign arlen = 0;
    // arsize
    assign arburst = 2'b01; // sequential
    assign arlock = 0;
    assign arcache = 0;
    assign arprot = 0;

    // arvalid
    // arready
    always @(posedge clk) begin
        if (~resetn) begin
            ar_state <= AR_IDLE;

            arid <= 4'b0;
            araddr <= 32'b0;
            arsize <= 3'b0;
            arvalid <= 0;
        end
        else begin
            case (ar_state)
                AR_IDLE: begin
                    if (sram_req && !sram_wr && aw_w_state==AW_W_IDLE) begin
                        arid <= req_type;
                        araddr <= sram_addr;
                        arsize <= {1'b0, sram_size};
                        arvalid <= 1;

                        ar_state <= AR_WAIT;
                    end
                end
                AR_WAIT: begin
                    if (arvalid && arready) begin
                        arvalid <= 0;
                        ar_state <= AR_IDLE;
                    end
                end
                default:
                    ar_state <= AR_IDLE;
            endcase
        end
    end

    // r
    always @(posedge clk) begin
        if (~resetn) begin
            rready <= 1;
        end

        if (rvalid && rready) begin
            if (rid) begin
                data_sram_rdata <= rdata;
            end
            else begin
                inst_sram_rdata <= rdata;
            end
        end
    end
    // aw
    assign awid = 1;
    assign awlen = 0;
    assign awburst = 2'b01;
    assign awlock = 0;
    assign awcache = 0;
    assign awprot = 0;
    // w
    assign wid = 1;
    assign wlast = 1;


    // aw & w
    always @(posedge clk) begin
        if (~resetn) begin
            aw_w_state <= AW_W_IDLE;
            awsize <= 3'b0;
            awvalid <= 0;
            awaddr <= 32'b0;

			wvalid <= 0;
			wstrb <= 4'b0;
			wdata <= 32'b0;
        end
        case (aw_w_state)
            AW_W_IDLE: begin
                if (sram_req && sram_wr) begin
                    aw_w_state <= AW_W_ADDR;
                    awvalid <= 1;
                    awsize <= {1'b0,data_sram_size};
                    awaddr <= data_sram_addr;
                end
            end
            AW_W_ADDR: begin
                if (awvalid && awready) begin
                    aw_w_state <= AW_W_DATA;
                    awvalid <= 0;

                    wvalid <= 1;
                    wdata <= data_sram_wdata;
                    wstrb <= data_sram_wstrb;
                end
            end
            AW_W_DATA: begin
                if (wvalid && wready && wlast) begin
                    aw_w_state <= B_WAIT;
                    wvalid <= 0;
                end
            end
            B_WAIT: begin
                if (bvalid && bready) begin
                    aw_w_state <= AW_W_IDLE;
                end
            end
            default:
                aw_w_state <= AW_W_IDLE;
        endcase
    end

    assign bready = 1;
    // b
    // always @(posedge clk) begin
    //     if (~resetn) begin
    //         bready <= 1;
    // 		b_has_resp <= 0;
    //     end
    // 	if (bvalid && bready) begin
    // 	end
    // end

    // ok signal
    always @(posedge clk) begin
        if (~resetn) begin
            data_sram_addr_ok <= 0;
            inst_sram_addr_ok <= 0;
            data_sram_data_ok <= 0;
            inst_sram_data_ok <= 0;
        end
        else begin
            data_sram_addr_ok <= 0;
            inst_sram_addr_ok <= 0;
            data_sram_data_ok <= 0;
            inst_sram_data_ok <= 0;

            if (arvalid && arready) begin
                if (arid)
                    data_sram_addr_ok <= 1;
                else
                    inst_sram_addr_ok <= 1;
            end

            if (wvalid && wready) begin
                data_sram_addr_ok <= 1;
            end

            if (rvalid && rready) begin
                if (rid)
                    data_sram_data_ok <= 1;
                else
                    inst_sram_data_ok <= 1;
            end

            if (bvalid && bready) begin
                data_sram_data_ok <= 1;
            end
        end
    end

endmodule
