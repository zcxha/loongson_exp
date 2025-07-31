module dcache(
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
        /*特权与cache维护相关*/
        input wire [1:0] mat, // 2'b00 强序非缓存 2'b01 一致可缓存
        input wire cacop_op,  // 为1表示是cacop指令
        input wire [2:0] cacop_code,
        // cacop code : one hot vector
        // 2'b001 直接索引，指定cache行tag置0 2'b010 直接索引，进行invalid and writeback 2'b100 查询索引 进行invalid and writeback

        input wire [31:0] cacop_vaddr, // cacop地址直接索引方式的虚拟地址

        output wire addr_ok, // 读：地址被接收 写：地址和数据被接收
        output wire data_ok, // 读：数据返回 写：数据写入完成
        output wire [31:0] rdata,

        /// cache - AXI bus
        output wire rd_req, // 读请求
        output wire [2:0] rd_type, // 3'b000-字节 3'b001-半字 3'b010-字 3'b100 cache行  // 先尝试强序非缓存都是按字读写
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
    reg [1:0] reg_mat;
    reg [3:0] reg_offset;
    reg [1:0] reg_bank;
    reg [7:0] reg_index;
    reg [3:0] reg_wstrb;
    reg [31:0] reg_wdata;
    reg reg_cacop_op;
    reg [2:0] reg_cacop_code;
    reg [31:0] reg_vaddr;
    always @(posedge clk) begin
        if (~resetn) begin
            reg_tag <= 20'b0;
            reg_op <= 0;
            reg_bank <= 2'b0;
            reg_index <= 8'b0;
            reg_wstrb <= 4'b0;
            reg_wdata <= 32'b0;
            reg_mat <= 2'b00;
            reg_cacop_op <= 0;
            reg_cacop_code <= 3'b0;
            reg_vaddr <= 32'b0;
        end
        else begin
            if (m_state==IDLE&&valid || !cacop_op&&m_state==LOOKUP&&cache_hit&&valid&&mat==2'b01) begin
                reg_tag <= tag;
                reg_op <= op;
                reg_index <= (cacop_op&&(cacop_code[0]||cacop_code[1])) ? cacop_vaddr[11:4] :index;
                reg_bank <= offset[3:2];
                reg_wstrb <= wstrb;
                reg_wdata <= wdata;
                reg_mat <= mat;
                reg_offset <= offset;
                reg_cacop_op <= cacop_op;
                reg_cacop_code <= cacop_code;
                reg_vaddr <= cacop_vaddr;
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

    localparam IDLE = 3'b000;
    localparam LOOKUP = 3'b001;
    localparam MISS = 3'b010;
    localparam REPLACE = 3'b011;
    localparam REFILL = 3'b100;
    localparam WRITE = 3'b101;
    reg [2:0] m_state,w_state;
    reg [31:0] rdata_buf;
    reg written;
    reg refill_write_en;
    always @(posedge clk) begin
        if (~resetn) begin
            m_state <= IDLE;
            written <= 0;
            rdata_buf <= 32'b0;
        end
        else begin
            case (m_state)
                IDLE: begin
                    if (valid) begin
                        m_state <= LOOKUP;
                    end
                end
                LOOKUP: begin
                    if (reg_cacop_op) begin
                        if (reg_cacop_code[0]) begin
                            // cache初始化
                            m_state <= IDLE;
                        end
                        else if (reg_cacop_code[1]) begin
                            m_state <= MISS;
                        end
                        else if (reg_cacop_code[2]) begin
                            if (!cache_hit) begin
                                m_state <= IDLE;
                            end
                            else begin
                                m_state <= MISS;
                            end
                        end
                    end// 对icache来说 这里进行了一次取指与cacop的仲裁
                    else begin
                        if (cache_hit&&reg_mat==2'b01) begin
                            // 请求完成
                            if (valid&&!cacop_op) begin
                                m_state <= LOOKUP;
                            end
                            else begin
                                m_state <= IDLE;
                            end
                            rdata_buf <= load_res;
                        end


                        else if (!cache_hit || reg_mat==2'b00) begin
                            m_state <= MISS;
                        end
                    end
                end
                MISS: begin // 读cache
                    if (wr_rdy) begin
                        // 对cache发起读行请求
                        m_state <= REPLACE;
                        written <= 0;
                    end
                end
                REPLACE: begin // 读内存以及写回
                    if (~written) begin
                        written <= 1;
                    end
                    if (reg_cacop_op) begin
                        m_state <= REFILL;
                        refill_write_en <= 0;
                    end
                    else begin
                        if (reg_mat==2'b01) begin
                            if (rd_rdy) begin
                                m_state <= REFILL;
                                refill_write_en <= 0;
                            end
                        end
                        else if (reg_mat==2'b00) begin
                            if(reg_op==0&&rd_rdy) begin
                                m_state <= REFILL;
                                refill_write_en <= 0;
                            end
                            else if (reg_op==1) begin
                                m_state <= REFILL;
                                refill_write_en <= 0;
                            end
                        end
                    end
                end
                REFILL: begin // 填入cache
                    if (reg_cacop_op) begin
                        if (wr_rdy) begin
                            refill_write_en <= 1;
                        end
                        if (refill_write_en) begin
                            m_state <= IDLE;
                        end
                    end
                    else begin
                        if (ret_valid==1&&n_ret_32==reg_bank&&reg_mat==2'b01) begin
                            rdata_buf <= ret_data;
                        end
                        if (ret_valid==1&&ret_last==1) begin
                            refill_write_en <= 1;
                        end
                        else if (reg_mat==2'b00&&reg_op&&wr_rdy) begin
                            refill_write_en <= 1;
                        end
                        if (refill_write_en) begin
                            m_state <= IDLE;
                        end
                    end
                end
            endcase
        end
    end

    wire wr_rd_relate;
    assign wr_rd_relate = !op && reg_op && tag==reg_tag && index==reg_index;
    wire addr_overlap = w_state==WRITE && !op && tag==reg_tag && index==w_index && offset[3:2]==w_bank;
    assign addr_ok = (m_state==IDLE&&valid || (!cacop_op&&reg_mat==2'b01&&m_state==LOOKUP&&cache_hit&&valid&&!wr_rd_relate))&&!addr_overlap;
    assign data_ok = (reg_cacop_op&&reg_cacop_code[0]) ? m_state==LOOKUP :
           (reg_cacop_op&&(reg_cacop_code[1])) ? (m_state==REFILL&&refill_write_en) :
           (reg_cacop_op&&reg_cacop_code[2]) ? (m_state==REFILL&&refill_write_en || m_state==LOOKUP&&!cache_hit) :
           (m_state==LOOKUP&&cache_hit
            || m_state==REFILL&&ret_valid&&n_ret_32==reg_bank)&&reg_mat==2'b01
           || (reg_mat==2'b00&&m_state==REFILL&&ret_valid&&ret_last || reg_mat==2'b00&&m_state==REFILL&&reg_op&&wr_rdy);
    assign rd_req = (reg_cacop_op) ? 0 : ((reg_mat==2'b01) ? m_state==REPLACE : reg_op==0&&m_state==REPLACE);
    assign rd_type = (reg_mat==2'b00) ? 3'b010 :
           3'b100;
    assign rd_addr = {reg_tag,reg_index,sel_offset};
    assign rdata =(reg_mat==2'b01) ? (m_state==LOOKUP&&cache_hit ? load_res :
                                      m_state==REFILL&&ret_valid&&n_ret_32==reg_bank ? ret_data : rdata_buf) :
           (ret_valid&&ret_last) ? ret_data : ret_data_buf;

    reg [31:0] ret_data_buf;
    always @(posedge clk) begin
        if (~resetn ) begin
            ret_data_buf <= 32'b0;
        end
        else if (ret_valid&&ret_last&&reg_mat==2'b00) begin
            ret_data_buf <= ret_data;
        end
    end

    wire [19:0] replace_tag;
    wire replace_d;
    wire replace_v;
    wire [127:0] replace_line;
    assign replace_tag = replace_way ? way1_tag : way0_tag;
    assign replace_d = replace_way ? way1_d_rdata : way0_d_rdata;
    assign replace_v = replace_way ? way1_v : way0_v;
    assign replace_line = replace_way ? way1_data : way0_data;
    assign wr_req = (reg_cacop_op&&(reg_cacop_code[1]||reg_cacop_code[2])&&m_state==REPLACE&&!written) ? 1 :
           ((m_state==REPLACE&&!written)&&replace_d&&replace_v&&reg_mat==2'b01
            || (m_state==REPLACE&&!written)&&(reg_mat==2'b00)&&reg_op);
    assign wr_type =(reg_cacop_op) ? 3'b100 : ((reg_mat==2'b00) ? 3'b010 : 3'b100);
    // TODO: 强序非缓存访问的读写地址是否还是这样生成呢？

    wire [19:0] sel_tag;
    wire [3:0] sel_offset;
    assign sel_tag = (reg_mat==2'b01||reg_cacop_op)?replace_tag:reg_tag;
    assign sel_offset = (reg_mat==2'b01||reg_cacop_op)?4'b0:reg_offset;
    assign wr_addr = {sel_tag,reg_index,sel_offset};
    assign wr_wstrb = (reg_mat==2'b01||reg_cacop_op) ? (replace_d ? 4'hf : 4'h0) : (reg_op ? reg_wstrb : 4'h0);
    assign wr_data = (reg_mat==2'b01||reg_cacop_op) ? replace_line : {96'b0,reg_wdata};


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
                replace_way <= (reg_cacop_op&&reg_cacop_code[2]&&cache_hit) ? (way1_hit ? 1 : /*way0_hit*/ 0) :
                            ((reg_cacop_op&&reg_cacop_code[1]) ? reg_vaddr[0] : random1[0]);
            end
            if (m_state==REPLACE&&rd_rdy) begin
                n_ret_32 <= 0;
            end
            if (ret_valid) begin
                if (reg_mat==2'b01) begin
                    n_ret_32 <= n_ret_32 + 1'b1;
                    if(ret_last)
                        miss_buffer_wdata <= next_data;
                    else
                        miss_buffer_wdata <= next_data << 32;
                end
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
            if (!reg_cacop_op&&reg_mat==2'b01&&m_state==LOOKUP&&reg_op&&cache_hit) begin
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
                    if (!reg_cacop_op&&reg_mat==2'b01&&m_state==LOOKUP&&reg_op&&cache_hit) begin
                        w_state <= WRITE;
                    end
                end
                WRITE: begin
                    if(!reg_cacop_op&&reg_mat==2'b01&&m_state==LOOKUP&&reg_op&&cache_hit) begin
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
    assign tagv_index = (m_state==IDLE)?index:reg_index;
    assign tagv_we =
           (reg_cacop_op && reg_cacop_code[0]&&m_state==LOOKUP)         ? (reg_vaddr[0]   ? 2'b10 : 2'b01) :
           ((reg_cacop_op&&(reg_cacop_code[1]||reg_cacop_code[2]) || !reg_cacop_op&&reg_mat == 2'b01) && m_state == REFILL)     ? (replace_way    ? 2'b10 : 2'b01) :
           2'b00;

    reg [19:0] rtag;
    always @(posedge clk) begin
        if (~resetn) begin
            rtag <= 20'b0;
        end
        else begin
            if (reg_cacop_op) begin
                rtag <= reg_vaddr[0] ? way1_tag : way0_tag;
            end
        end
    end

    assign tagv_wdata = (reg_cacop_op&&reg_cacop_code[0]&&m_state==LOOKUP) ? 21'b0 :
           (reg_cacop_op&&(reg_cacop_code[1]||reg_cacop_code[2])&&m_state==REFILL) ? {rtag,1'b0} :
           {reg_tag,1'b1};
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
    assign way0_hit =  way0_v && (way0_tag==reg_tag);
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
    assign aligned_w_wdata = (w_bank==2'b11) ? {w_wdata,96'b0} :
           (w_bank==2'b10) ? {32'b0,w_wdata,64'b0} :
           (w_bank==2'b01) ? {64'b0,w_wdata,32'b0} :
           {96'b0,w_wdata};
    assign ram_index = (cacop_op&&cacop_code[1]&&m_state==IDLE) ? cacop_vaddr[11:4] :
           (reg_cacop_op&&reg_cacop_code[1]) ? reg_index :
           (w_state==WRITE) ? w_index :
           (m_state==IDLE) ? index :
           reg_index;
    assign ram_wdata = (w_state==WRITE)?aligned_w_wdata:
           reg_op ? refill_reg_wdata : // 如果refill是store
           miss_buffer_wdata;
    assign Way1_wstrb =
           (!reg_cacop_op&&w_way&&w_state==WRITE) ? (w_wstrb<<(w_bank*4)) :
           (!reg_cacop_op&&reg_mat==2'b01&&m_state==REFILL&&refill_write_en&&replace_way) ? 16'hffff : 16'h0;
    assign Way0_wstrb =
           (!reg_cacop_op&&~w_way&&w_state==WRITE) ? (w_wstrb<<(w_bank*4)) :
           (!reg_cacop_op&&reg_mat==2'b01&&m_state==REFILL&&refill_write_en&&!replace_way) ? 16'hffff : 16'h0;
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
    assign d_index = (cacop_op&&cacop_code[1]&&m_state==IDLE) ? cacop_vaddr[11:4] :
           (reg_cacop_op&&reg_cacop_code[1]) ? reg_vaddr[11:4] :
           (m_state==IDLE)?index:
           (w_state==WRITE)?w_index:reg_index;
    assign way1_we = (w_state==WRITE&&w_way || (!reg_cacop_op&&reg_mat==2'b01&&m_state==REFILL&&replace_way)) ? 1 : 0;
    assign way0_we = (w_state==WRITE&&!w_way || !reg_cacop_op&&reg_mat==2'b01&&m_state==REFILL&&!replace_way) ? 1 : 0;

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
