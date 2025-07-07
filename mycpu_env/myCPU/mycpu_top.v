module mycpu_top #
    (
        parameter WIDTH = 200
    )
    (
        input  wire        clk,
        input  wire        resetn,
        // inst sram interface
        output wire		   inst_sram_en,
        output wire [3:0]  inst_sram_we,
        output wire [31:0] inst_sram_addr,
        output wire [31:0] inst_sram_wdata,
        input  wire [31:0] inst_sram_rdata,
        // data sram interface
        output wire		   data_sram_en,
        output wire [3:0]  data_sram_we,
        output wire [31:0] data_sram_addr,
        output wire [31:0] data_sram_wdata,
        input  wire [31:0] data_sram_rdata,
        // trace debug interface
        output wire [31:0] debug_wb_pc,
        output wire [ 3:0] debug_wb_rf_we,
        output wire [ 4:0] debug_wb_rf_wnum,
        output wire [31:0] debug_wb_rf_wdata
    );
    assign data_sram_en = 1;
    assign inst_sram_en = 1;

    reg         reset;
    always @(posedge clk) reset <= ~resetn;

    reg         valid;
    always @(posedge clk) begin
        if (reset) begin
            valid <= 1'b0;
        end
        else begin
            valid <= 1'b1;
        end
    end



    wire [31:0] seq_pc;
    wire [31:0] nextpc;
    wire        br_taken;
    wire [31:0] br_target;
    wire [31:0] inst;
    reg  [31:0] pc;

    wire [11:0] alu_op;
    wire        load_op;
    wire        src1_is_pc;
    wire        src2_is_imm;
    wire        res_from_mem;
    wire        dst_is_r1;
    wire        gr_we;
    wire        mem_we;
    wire        src_reg_is_rd;
    wire [4: 0] dest;
    wire [31:0] rj_value;
    wire [31:0] rkd_value;
    wire [31:0] imm;
    wire [31:0] br_offs;
    wire [31:0] jirl_offs;

    wire [ 5:0] op_31_26;
    wire [ 3:0] op_25_22;
    wire [ 1:0] op_21_20;
    wire [ 4:0] op_19_15;
    wire [ 4:0] rd;
    wire [ 4:0] rj;
    wire [ 4:0] rk;
    wire [11:0] i12;
    wire [19:0] i20;
    wire [15:0] i16;
    wire [25:0] i26;

    wire [63:0] op_31_26_d;
    wire [15:0] op_25_22_d;
    wire [ 3:0] op_21_20_d;
    wire [31:0] op_19_15_d;

    wire        inst_add_w;
    wire        inst_sub_w;
    wire        inst_slt;
    wire        inst_sltu;
    wire        inst_nor;
    wire        inst_and;
    wire        inst_or;
    wire        inst_xor;
    wire        inst_slli_w;
    wire        inst_srli_w;
    wire        inst_srai_w;
    wire        inst_addi_w;
    wire        inst_ld_w;
    wire        inst_st_w;
    wire        inst_jirl;
    wire        inst_b;
    wire        inst_bl;
    wire        inst_beq;
    wire        inst_bne;
    wire        inst_lu12i_w;

    wire        need_ui5;
    wire        need_si12;
    wire        need_si16;
    wire        need_si20;
    wire        need_si26;
    wire        src2_is_4;

    wire [ 4:0] rf_raddr1;
    wire [31:0] rf_rdata1;
    wire [ 4:0] rf_raddr2;
    wire [31:0] rf_rdata2;
    wire        rf_we   ;
    wire [ 4:0] rf_waddr;
    wire [31:0] rf_wdata;

    wire [31:0] alu_src1   ;
    wire [31:0] alu_src2   ;
    wire [31:0] alu_result ;

    wire [31:0] mem_result;

    wire [31:0] final_result;

    assign seq_pc       = is_data_related ? pc : pc + 32'h4;
    assign nextpc       = (br_taken & id_valid) ? (is_data_related ? pc: br_target) : seq_pc;


    always @(posedge clk) begin
        if (reset) begin
            pc <= 32'h1bfffffc;     //trick: to make nextpc be 0x1c000000 during reset
        end
        else begin
            pc <= nextpc;
        end
    end

    assign inst_sram_we    = 4'b0;
    assign inst_sram_addr  = nextpc;
    assign inst_sram_wdata = 32'b0;
    assign inst            = id_inst;
    // ID 段是把所有标志都生成

    assign op_31_26  = inst[31:26];
    assign op_25_22  = inst[25:22];
    assign op_21_20  = inst[21:20];
    assign op_19_15  = inst[19:15];

    assign rd   = inst[ 4: 0];
    assign rj   = inst[ 9: 5];
    assign rk   = inst[14:10];

    assign i12  = inst[21:10];
    assign i20  = inst[24: 5];
    assign i16  = inst[25:10];
    assign i26  = {inst[ 9: 0], inst[25:10]};

    decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
    decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
    decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
    decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

    assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
    assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
    assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
    assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
    assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
    assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
    assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
    assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
    assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
    assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
    assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
    assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
    assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
    assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
    assign inst_jirl   = op_31_26_d[6'h13];
    assign inst_b      = op_31_26_d[6'h14];
    assign inst_bl     = op_31_26_d[6'h15];
    assign inst_beq    = op_31_26_d[6'h16];
    assign inst_bne    = op_31_26_d[6'h17];
    assign inst_lu12i_w= op_31_26_d[6'h05] & ~inst[25];

    assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
           | inst_jirl | inst_bl;
    assign alu_op[ 1] = inst_sub_w;
    assign alu_op[ 2] = inst_slt;
    assign alu_op[ 3] = inst_sltu;
    assign alu_op[ 4] = inst_and;
    assign alu_op[ 5] = inst_nor;
    assign alu_op[ 6] = inst_or;
    assign alu_op[ 7] = inst_xor;
    assign alu_op[ 8] = inst_slli_w;
    assign alu_op[ 9] = inst_srli_w;
    assign alu_op[10] = inst_srai_w;
    assign alu_op[11] = inst_lu12i_w;

    assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
    assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w;
    assign need_si16  =  inst_jirl | inst_beq | inst_bne;
    assign need_si20  =  inst_lu12i_w;
    assign need_si26  =  inst_b | inst_bl;
    assign src2_is_4  =  inst_jirl | inst_bl;

    assign imm = src2_is_4 ? 32'h4                      :
           need_si20 ? {i20[19:0], 12'b0}         :
           need_si12 ? {{20{i12[11]}}, i12[11:0]}  :
           /*need_ui5*/ {27'b0,i12[4:0]};

    assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
           {{14{i16[15]}}, i16[15:0], 2'b0} ;

    assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

    assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w;

    assign src1_is_pc    = inst_jirl | inst_bl;

    assign src2_is_imm   = inst_slli_w |
           inst_srli_w |
           inst_srai_w |
           inst_addi_w |
           inst_ld_w   |
           inst_st_w   |
           inst_lu12i_w|
           inst_jirl   |
           inst_bl     ;

    assign res_from_mem  = inst_ld_w;
    assign dst_is_r1     = inst_bl;
    assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b;
    assign mem_we        = inst_st_w;
    assign dest          = dst_is_r1 ? 5'd1 : rd;

    assign rf_raddr1 = rj;
    assign rf_raddr2 = src_reg_is_rd ? rd :rk;
    regfile u_regfile(
                .clk    (clk      ),
                .raddr1 (rf_raddr1),
                .rdata1 (rf_rdata1),
                .raddr2 (rf_raddr2),
                .rdata2 (rf_rdata2),
                .we     (rf_we    ),
                .waddr  (rf_waddr ),
                .wdata  (rf_wdata )
            );

    assign rj_value  = rf_rdata1;
    assign rkd_value = rf_rdata2;

    assign rj_eq_rd = (rj_value == rkd_value);
    assign br_taken = (   inst_beq  &&  rj_eq_rd
                          || inst_bne  && !rj_eq_rd
                          || inst_jirl
                          || inst_bl
                          || inst_b
                      ) && valid;
    assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (id_pc + br_offs) :
           /*inst_jirl*/ (rj_value + jirl_offs);

    assign alu_src1 = src1_is_pc  ? id_pc[31:0] : rj_value;
    assign alu_src2 = src2_is_imm ? imm : rkd_value;

    alu u_alu(
            .alu_op     (ex_alu_op    ),
            .alu_src1   (ex_alu_src1  ),
            .alu_src2   (ex_alu_src2  ),
            .alu_result (alu_result)
        );

    assign data_sram_we    = {4{mem_mem_we && valid}};
    assign data_sram_addr  = mem_alu_result;
    assign data_sram_wdata = mem_rkd_value;

    assign mem_result   = data_sram_rdata;
    assign final_result = wb_res_from_mem ? data_sram_rdata : wb_alu_result;

    assign rf_we    = wb_gr_we && valid;
    assign rf_waddr = wb_dest;
    assign rf_wdata = final_result;

    // debug info generate
    assign debug_wb_pc       = wb_pc;
    assign debug_wb_rf_we   = {4{(wb_pc == 32'h1bfffffc) ? 0 : rf_we}};
    assign debug_wb_rf_wnum  = wb_dest;
    assign debug_wb_rf_wdata = final_result;

    wire wb_allowin;

    reg if_valid;
    reg [WIDTH-1:0] if_reg;

    reg id_valid;
    reg [WIDTH-1:0] id_reg;
    reg ex_valid;
    reg [WIDTH-1:0] ex_reg;
    reg mem_valid;
    reg [WIDTH-1:0] mem_reg;
    reg wb_valid;
    reg [WIDTH-1:0] wb_reg;


    wire br_taken_cancel = br_taken & id_valid & ~is_data_related; // todo

    wire [31:0] data_in;
    wire validin;
    assign data_in = inst_sram_rdata;
    assign validin = 1;

    // if stage
    wire if_allowin;
    wire if_ready_go;
    wire if_to_id_valid;
    assign if_ready_go = 1; // todo
    assign if_allowin = !if_valid || if_ready_go && id_allowin;
    assign if_to_id_valid = if_valid && if_ready_go;
    always @(posedge clk) begin
        if (reset) begin
            if_valid <= 1'b0;
            if_reg <= 200'b0;
        end
        else if (br_taken_cancel) begin
            if_valid <= 1'b0;
        end
        else if (if_allowin) begin
            if_valid <= validin;
        end

        if (validin && if_allowin) begin
            if_reg[31:0] <= pc;
            if_reg[63:32] <= data_in;
        end
    end

    wire [31:0] if_pc;
    wire [31:0] if_data_in;

    assign if_pc = if_reg[31:0];
    assign if_data_in = if_reg[63:32];

    // id stage

    // --- 数据相关的阻塞 ---
    // 1.rj | rk = dest:
    // add,sub,slt,sltu,NOR,and,or,xor
    // 2.rj == dest?:
    // slli,srli,srai,addi,ld,jirl
    // 3.rj | rd = dest？
    // st,beq,bne

    wire rjk_dest_inst = inst_add_w | inst_sub_w | inst_slt | inst_sltu | inst_nor | inst_and | inst_or | inst_xor;
    wire rj_dest_inst = inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w | inst_ld_w | inst_jirl;
    wire rjd_dest_inst = inst_st_w | inst_beq | inst_bne;
    wire is_data_related = (rjk_dest_inst & (
                                ( ex_valid == 1 && (rj == ex_dest || rk == ex_dest) ) ||
                                ( mem_valid == 1 && (rj == mem_dest || rk == mem_dest) ) ||
                                ( wb_valid == 1 && (rj == wb_dest || rk == wb_dest) )
                            )) ||
         (rj_dest_inst & (
              (ex_valid == 1 && rj == ex_dest) ||
              (mem_valid == 1 && rj == mem_dest) ||
              (wb_valid == 1 && rj == wb_dest)
          )) ||
         (rjd_dest_inst & (
              (ex_valid == 1 && (rj == ex_dest || dest == ex_dest)) ||
              (mem_valid == 1 && (rj == mem_dest || dest == mem_dest)) ||
              (wb_valid == 1 && (rj == wb_dest || dest == wb_dest))
          ))
         ;


    wire id_allowin;
    wire id_ready_go;
    wire id_to_ex_valid;

    assign id_ready_go = ~is_data_related; // todo
    assign id_allowin = !id_valid || id_ready_go && ex_allowin;
    assign id_to_ex_valid = id_valid && id_ready_go;
    always @(posedge clk) begin
        if (reset) begin
            id_valid <= 1'b0;
            id_reg <= 200'b0;
        end
        else if (br_taken_cancel) begin
            id_valid <= 1'b0; // 控制相关
        end
        else if (id_allowin) begin
            id_valid <= if_to_id_valid;
        end

        if (if_to_id_valid && id_allowin) begin
            id_reg[31:0] <= if_pc;
            id_reg[63:32] <= if_data_in; // data in = inst_sram_rdata
        end
    end

    wire [31:0] id_pc;
    wire [31:0] id_inst;

    assign id_pc = id_reg[31:0];
    assign id_inst = id_reg[63:32];


    wire ex_allowin;
    wire ex_ready_go;
    wire ex_to_mem_valid;

    // ex stage
    assign ex_ready_go = 1; // todo
    assign ex_allowin = !ex_valid || ex_ready_go && mem_allowin;
    assign ex_to_mem_valid = ex_valid && ex_ready_go;
    always @(posedge clk) begin
        if (reset) begin
            ex_valid <= 1'b0;
        end
        else if (ex_allowin) begin
            ex_valid <= id_to_ex_valid;
        end

        if (id_to_ex_valid && ex_allowin) begin
            ex_reg[31:0] <= id_pc;
            ex_reg[63:32] <= id_inst;
            ex_reg[95:64] <= alu_src1;
            ex_reg[127:96] <= alu_src2;
            ex_reg[139:128] <= alu_op;
            ex_reg[140] <= mem_we;
            ex_reg[141] <= gr_we;
            ex_reg[146:142] <= dest;
            ex_reg[147] <= res_from_mem;
            ex_reg[179:148] <= rkd_value;
        end
    end

    wire [31:0] ex_pc;
    wire [31:0] ex_inst;
    wire [31:0] ex_alu_src1;
    wire [31:0] ex_alu_src2;
    wire [11:0] ex_alu_op;

    wire ex_mem_we;
    wire ex_gr_we;
    wire [4:0] ex_dest;
    wire ex_res_from_mem;
    wire [31:0] ex_rkd_value;

    assign ex_pc = ex_reg[31:0];
    assign ex_inst = ex_reg[63:32];
    assign ex_alu_src1 = ex_reg[95:64];
    assign ex_alu_src2 = ex_reg[127:96];
    assign ex_alu_op = ex_reg[139:128];

    assign ex_mem_we = ex_reg[140];
    assign ex_gr_we = ex_reg[141];
    assign ex_dest = ex_reg[146:142];
    assign ex_res_from_mem = ex_reg[147];
    assign ex_rkd_value = ex_reg[179:148];

    // mem stage
    wire mem_allowin;
    wire mem_ready_go;
    wire mem_to_wb_valid;

    assign mem_ready_go = 1; // todo
    assign mem_allowin = !mem_valid || mem_ready_go && wb_allowin;
    assign mem_to_wb_valid = mem_valid && mem_ready_go;
    always @(posedge clk) begin
        if (reset) begin
            mem_valid <= 1'b0;
        end
        else if (mem_allowin) begin
            mem_valid <= ex_to_mem_valid;
        end

        if (ex_to_mem_valid && mem_allowin) begin
            mem_reg[31:0] <= ex_pc;
            mem_reg[63:32] <= ex_inst;
            mem_reg[64] <= ex_mem_we;
            mem_reg[65] <= ex_gr_we;
            mem_reg[70:66] <= ex_dest;
            mem_reg[71] <= ex_res_from_mem;
            mem_reg[103:72] <= ex_rkd_value;
            mem_reg[135:104] <= alu_result; // alu result
        end
    end

    wire [31:0] mem_pc;
    wire [31:0] mem_inst;
    wire mem_mem_we;
    wire mem_gr_we;
    wire [4:0] mem_dest;
    wire mem_res_from_mem;
    wire [31:0] mem_rkd_value;
    wire [31:0] mem_alu_result;


    assign mem_pc = mem_reg[31:0];
    assign mem_inst = mem_reg[63:32];
    assign mem_mem_we = mem_reg[64] & mem_valid;
    assign mem_gr_we = mem_reg[65];
    assign mem_dest = mem_reg[70:66];
    assign mem_res_from_mem = mem_reg[71];
    assign mem_rkd_value = mem_reg[103:72];
    assign mem_alu_result = mem_reg[135:104];

    // wb stage
    wire out_allow = 1;


    wire wb_ready_go;
    assign wb_ready_go = 1; // todo
    assign wb_allowin = !wb_valid || wb_ready_go && out_allow; // out allow = ?
    always @(posedge clk) begin
        if (reset) begin
            wb_valid <= 1'b0;
            wb_reg[199:0] <= 200'b0;
        end
        else if (wb_allowin) begin
            wb_valid = mem_to_wb_valid;
        end

        if (mem_to_wb_valid && wb_allowin) begin
            wb_reg[31:0] <= mem_pc;
            wb_reg[63:32] <= mem_inst;
            wb_reg[64] <= (wb_pc==mem_pc) ? 0 : mem_gr_we;
            wb_reg[69:65] <= mem_dest;
            wb_reg[70] <= mem_res_from_mem;
            wb_reg[102:71] <= mem_alu_result;
            wb_reg[103] <= (wb_pc == mem_pc) ? wb_reg[103] + 1 : 0;
        end
    end
    assign validout = wb_valid && wb_ready_go; // not defined
    assign dataout = wb_reg; // not defined

    wire [31:0] wb_pc;
    wire [31:0] wb_inst;
    wire wb_gr_we;
    wire [4:0] wb_dest;
    wire [31:0] wb_alu_result;
    wire wb_res_from_mem;

    assign wb_pc = wb_reg[31:0];
    assign wb_inst = wb_reg[63:32];
    assign wb_gr_we = wb_reg[64] & wb_valid;
    assign wb_dest = wb_reg[69:65];
    assign wb_res_from_mem = wb_reg[70];
    assign wb_alu_result = wb_reg[102:71];

endmodule
