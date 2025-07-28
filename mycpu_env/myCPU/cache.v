module cache(
        input wire clk,
        input wire resetn,

        /// cache - pipeline
        input wire valid,
        input wire op, // 1 write 0 read
        input wire [7:0] index, // vaddr[11:4]
        input wire [19:0] tag,
        input wire [3:0] offset, // vaddr[3:0]
        input wire [3:0] wstrb,
        input wire [31:0] wdata,
        output wire addr_ok, // 读：地址被接收 写：地址和数据被接收
        output wire data_ok, // 读：数据返回 写：数据写入完成
        output wire [31:0] rdata,

        /// cache - AXI bus
        output wire rd_req, // 读请求
        output wire [2:0] rd_type, // 3'b000-字节 3'b001-半字 3'b010-字 3'b100 cache行
        output wire [31:0] rd_addr, // 读请求起始地址
        input wire rd_rdy, // 读请求能否被接收的握手信号
        input wire ret_valid, // 返回数据有效信号
        input wire ret_last, // 最后一次返回数据
        input wire [31:0] ret_data, // 返回数据

        output wire wr_req, // 写请求
        output wire [2:0] wr_type,
        output wire [31:0] wr_addr,
        output wire [3:0] wr_wstrb,
        output wire [127:0] wr_data,
        input wire wr_rdy // 写请求能否被接收
    );

    reg [19:0] reg_tag;
    reg reg_op;
    reg [1:0] reg_bank;
    reg [7:0] reg_index;
    reg [3:0] reg_wstrb;
    reg [31:0] reg_wdata;
    always @(posedge clk) begin
        if (~resetn) begin
            reg_tag <= 20'b0;
            reg_op <= 0;
            reg_bank <= 2'b0;
            reg_index <= 8'b0;
            reg_wstrb <= 4'b0;
            reg_wdata <= 32'b0;
        end
        else begin
            if (m_state==IDLE&&valid || m_state==LOOKUP&&cache_hit&&valid) begin
                reg_tag <= tag;
                reg_op <= op;
                reg_index <= index;
                reg_bank <= offset[3:2];
                reg_wstrb <= wstrb;
                reg_wdata <= wdata;
            end
        end
    end

    reg valid_d;
    wire valid_pulse;
    always @(posedge clk) begin
        if (~resetn) begin
            valid_d <= 0;
        end
        else begin
            valid_d <= valid;
        end
    end
    assign valid_pulse = valid & ~valid_d;

    parameter IDLE = 3'b000;
    parameter LOOKUP = 3'b001;
    parameter MISS = 3'b010;
    parameter REPLACE = 3'b011;
    parameter REFILL = 3'b100;
    parameter WRITE = 3'b101;
    reg [2:0] m_state,w_state;
    reg written;
    reg refill_write_en;
    always @(posedge clk) begin
        if (~resetn) begin
            m_state <= IDLE;
            written <= 0;
        end
        else begin
            case (m_state)
                IDLE: begin
                    if (valid) begin
                        m_state <= LOOKUP;
                    end
                end
                LOOKUP: begin
                    if (cache_hit) begin
                        // 请求完成
                        if (valid) begin
                            m_state <= LOOKUP;
                        end
                        else begin
                            m_state <= IDLE;
                        end
                    end
                    // else if (cache_hit&&valid) begin
                    //     // 请求命中并接收到新请求
                    //     data_ok <= 1;
                    //     rdata <= load_res;
                    //     addr_ok <= 1;
                    // end
                    else if (!cache_hit) begin
                        m_state <= MISS;
                    end
                end
                MISS: begin
                    if (wr_rdy) begin
                        // 对cache发起读行请求
                        m_state <= REPLACE;
                        written <= 0;
                    end
                end
                REPLACE: begin
                    if (~written) begin
                        written <= 1;
                    end
                    if (rd_rdy) begin
                        m_state <= REFILL;
                        refill_write_en <= 0;
                    end
                end
                REFILL: begin
                    if (ret_valid==1&&n_ret_32==reg_bank) begin
                    end
                    if (ret_valid==1&&ret_last==1) begin
                        refill_write_en <= 1;
                    end
                    if (refill_write_en) begin
                        m_state <= IDLE;
                    end
                end
            endcase
        end
    end

	assign addr_ok = m_state==IDLE&&valid || m_state==LOOKUP&&cache_hit&&valid;
	assign data_ok = m_state==LOOKUP&&cache_hit || m_state==REFILL&&ret_valid&&n_ret_32==reg_bank;
	assign rdata = m_state==LOOKUP&&cache_hit ? load_res : m_state==REFILL&&ret_valid&&n_ret_32==reg_bank ? ret_data : 32'b0;
    assign rd_req = m_state==REPLACE&&rd_rdy;
    assign rd_type = 3'b100;
    assign rd_addr = {reg_tag,reg_index,4'b0};


    wire [19:0] replace_tag;
    wire replace_d;
    wire replace_v;
    wire [127:0] replace_line;
    assign replace_tag = replace_way ? way1_tag : way0_tag;
    assign replace_d = replace_way ? way1_d_rdata : way0_d_rdata;
    assign replace_v = replace_way ? way1_v : way0_v;
    assign replace_line = replace_way ? way1_data : way0_data;
    assign wr_req = (m_state==REPLACE&&!written)&&replace_d&&replace_v;
    assign wr_type = 3'b100;

    assign wr_addr = {replace_tag,reg_index,4'b0};
    assign wr_wstrb = replace_d ? 4'hf : 4'h0;
    assign wr_data = replace_line;


    // output declaration of module lfsr_random_8bit
    wire [7:0] random1;

    lfsr_random_8bit u_lfsr_random_8bit(
                         .clk    	(clk     ),
                         .resetn 	(resetn  ),
                         .enable 	(1  ),
                         .random1 	(random1  )
                     );

    /*------MISS Buffer------*/
    reg replace_way;
    reg [127:0] miss_buffer_wdata;
    wire [127:0] next_data = {miss_buffer_wdata[127:32],ret_data};
    reg [1:0] n_ret_32; // AXI总线返回了几个32位数据
    always @(posedge clk) begin
        if (~resetn) begin
            replace_way <= 0;
            n_ret_32 <= 0;
            miss_buffer_wdata <= 128'b0;
        end
        else begin
            if (m_state==MISS&&wr_rdy) begin
                replace_way <= random1[0];
            end
            if (m_state==REPLACE&&rd_rdy) begin
                n_ret_32 <= 0;
            end
            if (ret_valid) begin
                n_ret_32 <= n_ret_32 + 1;
                if(ret_last)
                    miss_buffer_wdata <= next_data;
                else
                    miss_buffer_wdata <= next_data << 32;
            end
        end
    end

    /*------Write Buffer------*/
    reg [7:0] w_index;
    reg [3:0] w_wstrb;
    reg w_way;
    reg [1:0] w_bank;
    reg [31:0] w_wdata;
    always @(posedge clk) begin
        if (~resetn) begin
            w_index <= 8'b0;
            w_wstrb <= 4'b0;
            w_way <= 0;
            w_bank <= 2'b0;
            w_wdata <= 32'b0;
        end
        else begin
            if (m_state==LOOKUP&&reg_op&&cache_hit) begin
                w_index <= reg_index;
                w_wstrb <= reg_wstrb;
                w_way <= way1_hit ? 1 : 0; // way1 hit ? way1 : 0
                w_bank <= reg_bank;
                w_wdata <= reg_wdata;
            end
            else begin
                w_index <= 8'b0;
                w_wstrb <= 4'b0;
                w_way <= 0;
                w_bank <= 2'b0;
                w_wdata <= 32'b0;
            end
        end
    end

    always @(posedge clk) begin
        if (~resetn) begin
            w_state <= 0;
        end
        else begin
            case (w_state)
                IDLE: begin
                    if (m_state==LOOKUP&&reg_op&&cache_hit) begin
                        w_state <= WRITE;
                    end
                end
                WRITE: begin
                    if(m_state==LOOKUP&&reg_op&&cache_hit) begin
                        // 此时接受到新的HIT WRITE 则继续写
                    end
                    else begin
                        w_state <= IDLE;
                    end
                end
            endcase
        end
    end

    /*------Block RAM------*/
    // TAGV RAM 2* 256x21
    wire [19:0] way0_tag,way1_tag;
    wire [7:0] tagv_index;
    wire [1:0] tagv_we;
    wire [20:0] tagv_wdata;
    wire way0_v,way1_v;
    assign tagv_index = m_state==IDLE?index:reg_index;
    assign tagv_we = m_state==REFILL ? (replace_way ? 2'b10 : 2'b01) : 2'b00;
    assign tagv_wdata = {reg_tag,1'b1};
    tagv_ram Way0_tagv_ram
             (
                 .clka  (clk             ),
                 .ena   (1        ),
                 .wea   (tagv_we[0]        ),   //0
                 .addra (tagv_index),   //7:0
                 .dina  (tagv_wdata     ),   //20:0
                 .douta ({way0_tag,way0_v}     )    //20:0
             );
    tagv_ram Way1_tagv_ram
             (
                 .clka  (clk             ),
                 .ena   (1        ),
                 .wea   (tagv_we[1]        ),   //0
                 .addra (tagv_index),   //7:0
                 .dina  (tagv_wdata     ), // 20:0
                 .douta ({way1_tag,way1_v}     ) // 20:0
             );

    wire way0_hit;
    wire way1_hit;
    wire cache_hit;
    assign way0_hit = way0_v && (way0_tag==reg_tag);
    assign way1_hit = way1_v && (way1_tag==reg_tag);
    assign cache_hit = way0_hit || way1_hit;


    wire [15:0] Way0_wstrb;
    wire [15:0] Way1_wstrb;
    wire [127:0] way0_data;
    wire [127:0] way1_data;
    wire [7:0] ram_index;
    wire [127:0] ram_wdata;
    wire [127:0] refill_reg_wdata;
    wire [127:0] aligned_w_wdata;
    assign refill_reg_wdata = reg_bank==2'b11 ? {
               reg_wstrb[3]?reg_wdata[31:24]:miss_buffer_wdata[127:120],
               reg_wstrb[2]?reg_wdata[23:16]:miss_buffer_wdata[119:112],
               reg_wstrb[1]?reg_wdata[15:8]:miss_buffer_wdata[111:104],
               reg_wstrb[0]?reg_wdata[7:0]:miss_buffer_wdata[103:96],
               miss_buffer_wdata[95:0]} :
           reg_bank==2'b10 ? {
               miss_buffer_wdata[127:96],
               reg_wstrb[3]?reg_wdata[31:24]:miss_buffer_wdata[95:88],
               reg_wstrb[2]?reg_wdata[23:16]:miss_buffer_wdata[87:80],
               reg_wstrb[1]?reg_wdata[15:8]:miss_buffer_wdata[79:72],
               reg_wstrb[0]?reg_wdata[7:0]:miss_buffer_wdata[71:64],
               miss_buffer_wdata[63:0]} :
           reg_bank==2'b01 ? {
               miss_buffer_wdata[127:64],
               reg_wstrb[3]?reg_wdata[31:24]:miss_buffer_wdata[63:56],
               reg_wstrb[2]?reg_wdata[23:16]:miss_buffer_wdata[55:48],
               reg_wstrb[1]?reg_wdata[15:8]:miss_buffer_wdata[47:40],
               reg_wstrb[0]?reg_wdata[7:0]:miss_buffer_wdata[39:32],
               miss_buffer_wdata[31:0]} :
           {
               miss_buffer_wdata[127:32],
               reg_wstrb[3]?reg_wdata[31:24]:miss_buffer_wdata[31:24],
               reg_wstrb[2]?reg_wdata[23:16]:miss_buffer_wdata[23:16],
               reg_wstrb[1]?reg_wdata[15:8]:miss_buffer_wdata[15:8],
               reg_wstrb[0]?reg_wdata[7:0]:miss_buffer_wdata[7:0]};
    assign aligned_w_wdata = w_bank==2'b11 ? {w_wdata,96'b0} :
           w_bank==2'b10 ? {32'b0,w_wdata,64'b0} :
           w_bank==2'b01 ? {64'b0,w_wdata,32'b0} :
           {96'b0,w_wdata};
    assign ram_index = m_state==IDLE ? index :
           w_state==WRITE ? w_index :
           reg_index;
    assign ram_wdata = (w_state==WRITE)?aligned_w_wdata:
           reg_op ? refill_reg_wdata : // 如果refill是store
           miss_buffer_wdata;
    assign Way1_wstrb = (w_way&&w_state==WRITE) ? (w_wstrb<<(w_bank*4)) :
           (m_state==REFILL&&refill_write_en&&replace_way) ? 16'hffff : 16'h0;
    assign Way0_wstrb = (~w_way&&w_state==WRITE) ? (w_wstrb<<(w_bank*4)) :
           (m_state==REFILL&&refill_write_en&&!replace_way) ? 16'hffff : 16'h0;
    // DATA Bank RAM 8* 256x32
    data_bank_ram Way0_Bank0_ram
                  (
                      .clka  (clk             ),
                      .ena   (1        ),
                      .wea   (Way0_wstrb[3:0]        ),   //3:0
                      .addra (ram_index),   //15:0
                      .dina  (ram_wdata[31:0]     ),   //31:0
                      .douta (  way0_data[31:0]   )    //31:0
                  );
    data_bank_ram Way0_Bank1_ram
                  (
                      .clka  (clk             ),
                      .ena   (1        ),
                      .wea   (Way0_wstrb[7:4]        ),   //3:0
                      .addra (ram_index),   //15:0
                      .dina  (ram_wdata[63:32]     ),   //31:0
                      .douta (  way0_data[63:32]   )    //31:0
                  );
    data_bank_ram Way0_Bank2_ram
                  (
                      .clka  (clk             ),
                      .ena   (1        ),
                      .wea   (Way0_wstrb[11:8]        ),   //3:0
                      .addra (ram_index),   //15:0
                      .dina  (ram_wdata[95:64]     ),   //31:0
                      .douta (way0_data[95:64]     )    //31:0
                  );
    data_bank_ram Way0_Bank3_ram
                  (
                      .clka  (clk             ),
                      .ena   (1        ),
                      .wea   (Way0_wstrb[15:12]        ),   //3:0
                      .addra (ram_index),   //15:0
                      .dina  (ram_wdata[127:96]     ),   //31:0
                      .douta (way0_data[127:96]     )    //31:0
                  );
    data_bank_ram Way1_Bank0_ram
                  (
                      .clka  (clk             ),
                      .ena   (1        ),
                      .wea   (Way1_wstrb[3:0]        ),   //3:0
                      .addra (ram_index),   //15:0
                      .dina  (ram_wdata[31:0]     ),   //31:0
                      .douta (way1_data[31:0]     )    //31:0
                  );
    data_bank_ram Way1_Bank1_ram
                  (
                      .clka  (clk             ),
                      .ena   (1        ),
                      .wea   (Way1_wstrb[7:4]        ),   //3:0
                      .addra (ram_index),   //15:0
                      .dina  (ram_wdata[63:32]     ),   //31:0
                      .douta (way1_data[63:32]     )    //31:0
                  );
    data_bank_ram Way1_Bank2_ram
                  (
                      .clka  (clk             ),
                      .ena   (1        ),
                      .wea   (Way1_wstrb[11:8]        ),   //3:0
                      .addra (ram_index),   //15:0
                      .dina  (ram_wdata[95:64]     ),   //31:0
                      .douta (way1_data[95:64]     )    //31:0
                  );
    data_bank_ram Way1_Bank3_ram
                  (
                      .clka  (clk             ),
                      .ena   (1        ),
                      .wea   (Way1_wstrb[15:12]        ),   //3:0
                      .addra (ram_index),   //15:0
                      .dina  (ram_wdata[127:96]     ),   //31:0
                      .douta (way1_data[127:96]     )    //31:0
                  );

    wire [31:0] way0_load_word;
    wire [31:0] way1_load_word;
    wire [31:0] load_res;

    assign way0_load_word = way0_data[reg_bank*32 +: 32];
    assign way1_load_word = way1_data[reg_bank*32 +: 32];
    assign load_res = {32{way0_hit}} & way0_load_word
           | {32{way1_hit}} & way1_load_word;

    // D regfile 2* 256x1
    reg [255:0] Way0_D;
    reg [255:0] Way1_D;
    wire way0_we;
    wire way1_we;
    wire [7:0] d_index;
    assign d_index = m_state==IDLE?index:
           w_state==WRITE?w_index:reg_index;
    assign way1_we = (w_state==WRITE&&w_way || (m_state==REFILL&&replace_way)) ? 1 : 0;
    assign way0_we = (w_state==WRITE&&!w_way || m_state==REFILL&&!replace_way) ? 1 : 0;

    always @(posedge clk) begin
        if (~resetn) begin
            Way0_D <= 256'b0;
            Way1_D <= 256'b0;
        end
        else begin
            if (way0_we) begin
                if (w_state==WRITE) begin
                    Way0_D[d_index] <= 1;
                end
                else if (m_state==REFILL) begin
                    if (reg_op) begin
                        Way0_D[d_index] <= 1;
                    end
                    else begin
                        Way0_D[d_index] <= 0;
                    end
                end
            end

            if (way1_we) begin
                if (w_state==WRITE) begin
                    Way1_D[d_index] <= 1;
                end
                else if (m_state==REFILL) begin
                    if (reg_op) begin
                        Way1_D[d_index] <= 1;
                    end
                    else begin
                        Way1_D[d_index] <= 0;
                    end
                end
            end
        end
    end
    wire way0_d_rdata;
    wire way1_d_rdata;
    assign way0_d_rdata = Way0_D[d_index];
    assign way1_d_rdata = Way1_D[d_index];

endmodule
