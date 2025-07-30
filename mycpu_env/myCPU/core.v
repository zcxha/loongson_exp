`include "define.v"
module core #
    (
        parameter WIDTH = 500
    )
    (
        input  wire        clk,
        input  wire        resetn,
        // inst sram interface bus
        output reg		   inst_sram_req, // 请求信号 1表示有读写请求，0表示无读写请求
        output wire        inst_sram_wr, // 为1表示该次是写请求，0表示是读请求
        output wire [7:0]  inst_sram_index, // cache index =  vaddr[11:4]
        output wire [19:0] inst_sram_tag, // tag = paddr[31:12]
        output wire [3:0]  inst_sram_offset, // offset = vaddr[3:0]
        output wire [3:0]  inst_sram_wstrb, // 该次字节写使能
        output wire [31:0] inst_sram_wdata, //
        input  wire		   inst_sram_addr_ok, // 该次请求地址传输OK 读：地址被接收 写：地址和数据被接收
        input  wire		   inst_sram_data_ok, // 该次请求的数据传输OK 读：数据返回 写：数据写入完成
        input  wire [31:0] inst_sram_rdata,
        // data sram interface bus
        output reg		   data_sram_req,
        output wire        data_sram_wr,
        // output wire [1:0]  data_sram_size,
        output wire [7:0]  data_sram_index, // cache index =  vaddr[11:4]
        output wire [19:0] data_sram_tag, // tag = paddr[31:12]
        output wire [3:0]  data_sram_offset, // offset = vaddr[3:0]
        output wire [3:0]  data_sram_wstrb,
        output wire [31:0] data_sram_wdata,
        output wire [1:0]  data_sram_mat,
        input  wire        data_sram_addr_ok,
        input  wire        data_sram_data_ok,
        input  wire [31:0] data_sram_rdata,
        // trace debug interface
        output wire [31:0] debug_wb_pc,
        output wire [ 3:0] debug_wb_rf_we,
        output wire [ 4:0] debug_wb_rf_wnum,
        output wire [31:0] debug_wb_rf_wdata
    );

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
    wire		pref_adef;

    wire [11:0] alu_op;
    wire		tlbsrch_op;
    wire		tlbrd_op;
    wire		tlbwr_op;
    wire		tlbfill_op;
    wire		invtlb_valid;
    wire [4:0]	invtlb_op;
    wire        src1_is_pc;
    wire        src2_is_imm;
    wire        res_from_mem;
    wire		mul_signed;
    wire		mul_hres;
    wire		mul_enable;

    wire		div_enable;
    wire		div_signed;
    wire		div_res_remainder;
    wire        dst_is_r1;
    wire        gr_we;
    wire        src_reg_is_rd;
    wire [4: 0] dest;
    wire [31:0] rj_value;
    wire [31:0] rkd_value;
    wire [31:0] imm;
    wire [31:0] br_offs;
    wire [31:0] jirl_offs;

    wire op_st_b;
    wire op_st_h;
    wire op_st_w;

    wire [ 5:0] op_31_26;
    wire [ 3:0] op_25_22;
    wire [ 1:0] op_21_20;
    wire [ 4:0] op_19_15;
    wire [ 4:0] op_14_10;
    wire [ 4:0] op_09_05;
    wire [ 4:0] op_04_00;
    wire [ 4:0] rd;
    wire [ 4:0] rj;
    wire [ 4:0] rk;
    wire [13:0] csr;
    wire [31:0] csr_mask;
    wire 		csr_we;
    wire [31:0] csr_wvalue;
    wire		inst_csr;
    wire		res_from_timer;
    wire [11:0] i12;
    wire [19:0] i20;
    wire [15:0] i16;
    wire [25:0] i26;

    wire [63:0] op_31_26_d;
    wire [15:0] op_25_22_d;
    wire [ 3:0] op_21_20_d;
    wire [31:0] op_19_15_d;
    wire [31:0] op_14_10_d;
    wire [31:0] op_09_05_d;
    wire [31:0] op_04_00_d;

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
    wire		inst_ld_b;
    wire		inst_ld_h;
    wire        inst_ld_w;
    wire		inst_st_b;
    wire		inst_st_h;
    wire        inst_st_w;
    wire		inst_ld_bu;
    wire		inst_ld_hu;
    wire        inst_jirl;
    wire        inst_b;
    wire        inst_bl;
    wire        inst_beq;
    wire        inst_bne;
    wire		inst_blt;
    wire		inst_bge;
    wire		inst_bltu;
    wire		inst_bgeu;
    wire        inst_lu12i_w;

    wire		inst_slti;
    wire		inst_sltui;

    wire		inst_andi;
    wire		inst_ori;
    wire		inst_xori;

    wire		inst_sll_w;
    wire		inst_srl_w;
    wire		inst_sra_w;

    wire		inst_pcaddu12i;

    wire		inst_mul_w;
    wire		inst_mulh_w;
    wire		inst_mulh_wu;

    wire		inst_div_w;
    wire		inst_div_wu;
    wire		inst_mod_w;
    wire		inst_mod_wu;

    wire		inst_syscall;
    wire		inst_break;
    wire		inst_ertn;

    wire		inst_csrrd;
    wire		inst_csrwr;
    wire		inst_csrxchg;

    wire		inst_rdcntvl_w;
    wire		inst_rdcntvh_w;
    wire		inst_rdcntid;

    wire		inst_tlbsrch;
    wire		inst_tlbrd;
    wire		inst_tlbwr;
    wire		inst_tlbfill;
    wire		inst_invtlb;

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

    wire ex_forward;
    wire mem_forward;
    wire wb_forward;

    wire [31:0] alu_src1   ;
    wire [31:0] alu_src2   ;

    wire 		mem_word;
    wire		mem_half;
    wire		mem_byte;
    wire		mem_uext;
    wire		mem_iext;

    wire id_ine;
    wire id_syscall;
    wire id_break;
    wire id_has_int; // 中断标记到ID段
    wire id_ertn_flush;

    /***EX***/

    wire [31:0] alu_result ;
    wire [31:0] EX_result  ;

    /***MEM***/

    wire [31:0] mem_result;

    /***WB***/

    wire [31:0] final_result;

    /*------pre-IF------*/
    // assign inst_sram_req = (op_br_compare && ex_valid ? br_valid : 1) && if_allowin && resetn;

    assign seq_pc       = ~if_allowin ? pc : pc + 32'h4;
    assign nextpc = (wb_valid && (wb_has_exception || wb_id_ertn_flush || wb_pref_refetch)) ? ( {32{wb_has_exception}} & wb_ex_entry | {32{wb_id_ertn_flush}}   & wb_ertn_pc | {32{wb_pref_refetch}} & wb_pc) :
           (br_taken_cancel) ? br_target :
           seq_pc;
    assign pref_adef	= ((pc & 2'b11) != 2'b00);

    reg cancel_inst;
    reg exception_cancel_flag;
    reg [31:0] cached_npc;
    reg [31:0] cached_inst;
    always @(posedge clk) begin
        if (reset) begin
            cancel_inst <= 0;
            exception_cancel_flag <= 0;
            cached_npc <= 32'b0;
            cached_inst <= 32'b0;
        end
        if (wb_has_exception || wb_id_ertn_flush || wb_pref_refetch) begin
            exception_cancel_flag <= 1;
            cached_npc <= nextpc; // 异常处理程序入口
        end
        else if ((if_allowin && inst_sram_req == 0) && !waiting_for_inst) begin
            if (exception_cancel_flag) begin
                exception_cancel_flag <= 0;
            end
            else if (cancel_inst) begin
                cancel_inst <= 0;
            end
        end
        else if (br_taken_cancel) begin
            cancel_inst <= 1;
            cached_npc <= nextpc; // 跳转目标
        end
    end

    reg waiting_for_inst;

    always @(posedge clk) begin
        if (reset) begin
            waiting_for_inst <= 0;
            inst_sram_req <= 0;
            pc <= 32'h1bfffffc;     //trick: to make nextpc be 0x1c000000 during reset
        end
        if ((if_allowin && inst_sram_req == 0) && !waiting_for_inst) begin // TODO: 如果有地址错误则不发出请求
            inst_sram_req <= 1;
            if (exception_cancel_flag) begin
                pc <= cached_npc;
            end
            else if (cancel_inst) begin
                pc <= cached_npc;
            end
            else begin
                pc <= nextpc;
            end
        end
        else if (inst_sram_addr_ok && inst_sram_req) begin
            inst_sram_req <= 0;
            waiting_for_inst <= 1;
        end
        else if (inst_sram_data_ok && waiting_for_inst) begin
            waiting_for_inst <= 0;
            cached_inst <= inst_sram_rdata;
        end
    end

    wire pref_refetch = //out_crmd_pg &&
         // 流水线中有写 DA PG DMW0 DMW1 ASID 即CSRWR 这些 以及TLBRD  TODO:在PG翻译模式下才判断
         (id_valid&&(csr_we&&(csr==`CSR_CRMD || csr==`CSR_CRMD || csr==`CSR_DMW0 || csr==`CSR_DMW1 || csr==`CSR_ASID) || tlbrd_op || tlbwr_op || tlbfill_op || invtlb_valid )
          || ex_valid&&(ex_csr_we&&(ex_csr==`CSR_CRMD || ex_csr==`CSR_CRMD || ex_csr==`CSR_DMW0 || ex_csr==`CSR_DMW1 || ex_csr==`CSR_ASID) || ex_tlbrd_op || ex_tlbwr_op || ex_tlbfill_op || ex_invtlb_valid)
          || mem_valid&&(mem_csr_we&&(mem_csr==`CSR_CRMD || mem_csr==`CSR_CRMD || mem_csr==`CSR_DMW0 || mem_csr==`CSR_DMW1 || mem_csr==`CSR_ASID) || mem_tlbrd_op || mem_tlbwr_op || mem_tlbfill_op || mem_invtlb_valid) // invtlb在ex段执行完，那么在ex之后就应该触发重取指 此处为了简化设计都是在WB段触发重取指
          || wb_valid&&(wb_csr_we&&(wb_csr_num==`CSR_CRMD || wb_csr_num==`CSR_CRMD || wb_csr_num==`CSR_DMW0 || wb_csr_num==`CSR_DMW1 || wb_csr_num==`CSR_ASID) || wb_tlbrd_op || wb_tlbwr_op || wb_tlbfill_op || wb_invtlb_valid));

    wire [31:0] inst_sram_vaddr = pref_adef ? 32'h1c000000 : pc;

    // input dec
    wire [18:0] s0_vppn;
    wire s0_va_bit12;
    wire [9:0] s0_asid;


    /*------MMU------*/

    // 直接地址翻译部件
    wire [31:0] inst_sram_daddr = inst_sram_vaddr;
    // 直接映射窗口地址翻译部件
    wire inst_hit_dmw0 =inst_sram_vaddr[31:29]==out_dmw0[`CSR_DMW0_VSEG]&&(out_crmd_plv==2'b00 && out_dmw0[`CSR_DMW0_PLV0] || out_crmd_plv==2'b11 && out_dmw0[`CSR_DMW0_PLV3]);
    wire inst_hit_dmw1 = inst_sram_vaddr[31:29]==out_dmw1[`CSR_DMW1_VSEG]&&(out_crmd_plv==2'b00 && out_dmw1[`CSR_DMW1_PLV0] || out_crmd_plv==2'b11 && out_dmw1[`CSR_DMW1_PLV3]);
    wire [31:0] inst_sram_dmwaddr =
         inst_hit_dmw0?
         {out_dmw0[`CSR_DMW0_PSEG],inst_sram_vaddr[28:0]}:
         inst_hit_dmw1?
         {out_dmw1[`CSR_DMW1_PSEG],inst_sram_vaddr[28:0]}: // 特权等级不合规相当于不命中，只进入页表映射模式，不在此时发出异常
         inst_sram_vaddr ;
    // TLB地址翻译部件
    wire inst_use_tlb = out_crmd_pg && !inst_hit_dmw0 && !inst_hit_dmw1;
    assign {s0_vppn,s0_va_bit12} = inst_sram_vaddr[31:12];
    assign s0_asid = out_asid_asid;
    wire [31:0] inst_sram_tlbaddr = {s0_ppn,inst_sram_vaddr[11:0]};
    // 异常
    wire pref_tlbr = out_crmd_pg ? ~s0_found && inst_use_tlb: 0;
    wire pref_pif = out_crmd_pg ? ~s0_v && !pref_tlbr && inst_use_tlb: 0;
    wire pref_ppi = out_crmd_pg ? (out_crmd_plv > s0_plv) && !pref_tlbr && !pref_pif && inst_use_tlb: 0;
    wire pref_has_exception = pref_adef | pref_tlbr | pref_pif | pref_ppi;

    // MUX
    wire [31:0] inst_sram_paddr;
    assign inst_sram_paddr = out_crmd_da ? inst_sram_daddr :
           inst_hit_dmw0 || inst_hit_dmw1 ? inst_sram_dmwaddr :
           inst_sram_tlbaddr;


    assign inst_sram_wr = 0;
    // assign inst_sram_size = 2'h2;
    assign inst_sram_wstrb    = 4'b0;
    // assign inst_sram_addr  = inst_sram_paddr; // 发生取指地址错时将PC置默认值
    assign inst_sram_index = inst_sram_vaddr[11:4];
    assign inst_sram_tag = inst_sram_paddr[31:12];
    assign inst_sram_offset = inst_sram_vaddr[3:0];
    assign inst_sram_wdata = 32'b0;

    /*------IF------*/

    reg [63:0] if_buffer;
    reg buffer_valid;
    always @(posedge clk) begin
        if (reset) begin
            if_buffer <= 64'b0;
            buffer_valid <= 0;
        end
        else if (!id_allowin && if_ready_go) begin
            if_buffer <= {pref_adef,if_data_in,if_pc};
            buffer_valid <= 1'b0;
        end
        else begin
            buffer_valid <= 0;
        end
    end

    // ID 段把所有标志都生成
    /*------ID------*/
    assign inst            = id_inst;

    assign op_31_26  = inst[31:26];
    assign op_25_22  = inst[25:22];
    assign op_21_20  = inst[21:20];
    assign op_19_15  = inst[19:15];
    assign op_14_10  = inst[14:10];
    assign op_09_05  = inst[9:5];
    assign op_04_00  = inst[4:0];

    assign rd   = inst[ 4: 0];
    assign rj   = inst[ 9: 5];
    assign rk   = inst[14:10];
    assign csr	= inst_rdcntid ? `CSR_TID : inst[23:10];

    assign i12  = inst[21:10];
    assign i20  = inst[24: 5];
    assign i16  = inst[25:10];
    assign i26  = {inst[ 9: 0], inst[25:10]};

    decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
    decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
    decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
    decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));
    decoder_5_32 u_dec4(.in(op_14_10 ), .out(op_14_10_d ));
    decoder_5_32 u_dec5(.in(op_09_05 ), .out(op_09_05_d )); // wmask
    decoder_5_32 u_dec6(.in(op_04_00 ), .out(op_04_00_d ));

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
    assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
    assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
    assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
    assign inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
    assign inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
    assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
    assign inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
    assign inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
    assign inst_jirl   = op_31_26_d[6'h13];
    assign inst_b      = op_31_26_d[6'h14];
    assign inst_bl     = op_31_26_d[6'h15];
    assign inst_beq    = op_31_26_d[6'h16];
    assign inst_bne    = op_31_26_d[6'h17];
    assign inst_blt    = op_31_26_d[6'h18];
    assign inst_bge    = op_31_26_d[6'h19];
    assign inst_bltu   = op_31_26_d[6'h1a];
    assign inst_bgeu   = op_31_26_d[6'h1b];
    assign inst_lu12i_w= op_31_26_d[6'h05] & ~inst[25];

    assign inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h8];
    assign inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h9];

    assign inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'hd];
    assign inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'he];
    assign inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'hf];

    assign inst_sll_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
    assign inst_srl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
    assign inst_sra_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];

    assign inst_pcaddu12i = op_31_26_d[6'h07] & ~inst[25];
    // id mul signals: mul_signed,mul_hres,res_from_mul,mul_forward

    assign inst_mul_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
    assign inst_mulh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
    assign inst_mulh_wu= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];

    assign inst_div_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
    assign inst_mod_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
    assign inst_div_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
    assign inst_mod_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];

    assign inst_break = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];
    assign inst_syscall = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];
    assign inst_ertn = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & op_14_10_d[5'h0e] & op_09_05_d[5'h00] & op_04_00_d[5'h00];

    assign inst_csrrd = op_31_26_d[6'h01] & ~inst[25] & ~inst[24] & op_09_05_d[5'h00];
    assign inst_csrwr = op_31_26_d[6'h01] & ~inst[25] & ~inst[24] & op_09_05_d[5'h01];
    assign inst_csrxchg = op_31_26_d[6'h01] & ~inst[25] & ~inst[24] & (rj != 0 && rj!= 1);

    assign inst_rdcntid = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & op_14_10_d[5'h18] & op_04_00_d[5'h00];
    assign inst_rdcntvl_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & op_14_10_d[5'h18] & op_09_05_d[5'h00];
    assign inst_rdcntvh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h00] & op_14_10_d[5'h19] & op_09_05_d[5'h00];

    assign inst_tlbsrch = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & op_14_10_d[5'h0a] & op_09_05_d[5'h00] & op_04_00_d[5'h00];
    assign inst_tlbrd = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & op_14_10_d[5'h0b] & op_09_05_d[5'h00] & op_04_00_d[5'h00];
    assign inst_tlbwr = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & op_14_10_d[5'h0c] & op_09_05_d[5'h00] & op_04_00_d[5'h00];
    assign inst_tlbfill = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & op_14_10_d[5'h0d] & op_09_05_d[5'h00] & op_04_00_d[5'h00];
    assign inst_invtlb = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h13];

    wire invtlb_op_inv;
    assign invtlb_op_inv = (rd[4:3] != 2'b00 || rd == 5'b00111) && inst_invtlb; // op > 6
    assign {tlbsrch_op,tlbrd_op,tlbwr_op,tlbfill_op,invtlb_valid} = {inst_tlbsrch,inst_tlbrd,inst_tlbwr,inst_tlbfill,inst_invtlb & ~invtlb_op_inv};
    assign invtlb_op = rd;

    assign res_from_timer = inst_rdcntvl_w | inst_rdcntvh_w;
    assign timer_op = inst_rdcntvh_w;

    assign id_ine = ~(inst_add_w | inst_sub_w | inst_slt | inst_sltu | inst_nor
                      | inst_and | inst_or | inst_xor | inst_slli_w | inst_srli_w
                      | inst_srai_w | inst_addi_w | inst_ld_b | inst_ld_h | inst_ld_w
                      | inst_st_b | inst_st_h | inst_st_w | inst_ld_bu | inst_ld_hu
                      | inst_jirl | inst_b | inst_bl | inst_beq | inst_bne | inst_blt
                      | inst_bge | inst_bltu | inst_bgeu | inst_lu12i_w | inst_slti
                      | inst_sltui | inst_andi | inst_ori | inst_xori | inst_sll_w
                      | inst_srl_w | inst_sra_w | inst_pcaddu12i | inst_mul_w | inst_mulh_w
                      | inst_mulh_wu | inst_div_w | inst_mod_w | inst_div_wu | inst_mod_wu
                      | inst_break | inst_syscall | inst_ertn | inst_csrrd | inst_csrwr
                      | inst_csrxchg | inst_rdcntvl_w | inst_rdcntvh_w | inst_rdcntid | inst_tlbsrch
                      | inst_tlbrd | inst_tlbwr | inst_tlbfill | inst_invtlb) | invtlb_op_inv; // 指令不存在异常 或者指令保留异常

    assign id_syscall = inst_syscall;
    assign id_break = inst_break; // 系统调用和断点异常
    assign id_has_int = wb_has_int;
    assign id_ertn_flush = inst_ertn;

    assign csr_mask = {32{inst_csrwr}} | {32{inst_csrxchg}} & rj_value;
    assign csr_we = inst_csrwr | inst_csrxchg;
    assign csr_wvalue = rd==0 ? 32'b0 : rkd_value;

    assign inst_csr = inst_csrrd | inst_csrwr | inst_csrxchg | inst_rdcntid; // inst_csr

    assign mul_signed = inst_mul_w | inst_mulh_w;
    assign mul_hres = inst_mulh_w | inst_mulh_wu;
    assign mul_enable = inst_mul_w | inst_mulh_w | inst_mulh_wu;

    assign div_enable = inst_div_w | inst_mod_w | inst_div_wu | inst_mod_wu;
    assign div_signed = inst_div_w | inst_mod_w;
    assign div_res_remainder = inst_mod_w | inst_mod_wu;


    assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu | inst_st_b | inst_st_h
           | inst_jirl | inst_bl | inst_pcaddu12i;
    assign alu_op[ 1] = inst_sub_w;
    assign alu_op[ 2] = inst_slt | inst_slti;
    assign alu_op[ 3] = inst_sltu | inst_sltui;
    assign alu_op[ 4] = inst_and | inst_andi;
    assign alu_op[ 5] = inst_nor;
    assign alu_op[ 6] = inst_or | inst_ori;
    assign alu_op[ 7] = inst_xor | inst_xori;
    assign alu_op[ 8] = inst_slli_w | inst_sll_w;
    assign alu_op[ 9] = inst_srli_w | inst_srl_w;
    assign alu_op[10] = inst_srai_w | inst_sra_w;
    assign alu_op[11] = inst_lu12i_w;

    assign op_st_b = inst_st_b;
    assign op_st_h = inst_st_h;
    assign op_st_w = inst_st_w;
    wire op_store = inst_st_b | inst_st_h | inst_st_w;
    wire op_load = inst_ld_w | inst_ld_h | inst_ld_hu | inst_ld_b | inst_ld_bu;

    assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
    assign need_ui12  =  inst_andi | inst_ori | inst_xori;
    assign need_si12  =  inst_addi_w | inst_ld_b | inst_ld_h | inst_ld_w | inst_ld_bu | inst_ld_hu | inst_st_b | inst_st_h | inst_st_w | inst_slti | inst_sltui;
    assign need_si16  =  inst_jirl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
    assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;
    assign need_si26  =  inst_b | inst_bl;
    assign src2_is_4  =  inst_jirl | inst_bl;

    assign imm = src2_is_4 ? 32'h4                      :
           need_si20 ? {i20[19:0], 12'b0}         :
           need_si12 ? {{20{i12[11]}}, i12[11:0]}  :
           need_ui12 ? {20'b0, i12[11:0]} :
           /*need_ui5*/ {27'b0,i12[4:0]};

    assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
           {{14{i16[15]}}, i16[15:0], 2'b0} ;

    assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

    assign src_reg_is_rd = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_st_w | inst_st_b | inst_st_h | inst_csrwr | inst_csrxchg;

    assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;

    assign src2_is_imm   = inst_slli_w |
           inst_srli_w |
           inst_srai_w |
           inst_addi_w |
           inst_ld_b   |
           inst_ld_bu  |
           inst_ld_h   |
           inst_ld_hu  |
           inst_ld_w   |
           inst_st_b   |
           inst_st_h   |
           inst_st_w   |
           inst_lu12i_w|
           inst_jirl   |
           inst_bl     |
           inst_slti   |
           inst_sltui  |
           inst_andi   |
           inst_ori    |
           inst_xori   |
           inst_pcaddu12i;

    //（其实 ex_forward表示前递alu结果，mem_forward表示前递内存读结果）
    assign ex_forward = inst_add_w | inst_sub_w | inst_slt |
           inst_sltu | inst_nor | inst_and | inst_or |
           inst_xor | inst_slli_w | inst_srli_w | inst_srai_w |
           inst_addi_w | inst_jirl | inst_bl | inst_lu12i_w |
           inst_slti | inst_sltui | inst_andi | inst_ori |
           inst_xori | inst_sll_w | inst_srl_w | inst_sra_w | inst_pcaddu12i |
           inst_div_w | inst_div_wu | inst_mod_w | inst_mod_wu | inst_mul_w | inst_mulh_w | inst_mulh_wu
           | inst_rdcntvl_w | inst_rdcntvh_w;
    assign mem_forward = inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu;
    assign wb_forward = inst_csrwr | inst_csrrd | inst_csrxchg | inst_rdcntid;

    assign res_from_mem  = inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu;
    assign dst_is_r1     = inst_bl;
    assign dst_is_rj	 = inst_rdcntid;
    assign gr_we         = ~inst_st_b & ~inst_st_h & ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_blt & ~inst_bge & ~inst_bltu & ~inst_bgeu & ~inst_b & ~inst_tlbsrch & ~inst_tlbfill & ~inst_tlbrd & ~inst_tlbwr & ~inst_invtlb;
    assign dest          = dst_is_r1 ? 5'd1 : dst_is_rj ? rj : rd;

    assign mem_op = inst_ld_w | inst_ld_h | inst_ld_b | inst_ld_bu | inst_ld_hu | inst_st_b | inst_st_w | inst_st_h;

    assign mem_word		= inst_ld_w;
    assign mem_half		= inst_ld_h | inst_ld_hu;
    assign mem_byte		= inst_ld_b | inst_ld_bu;
    assign mem_uext		= inst_ld_hu | inst_ld_bu;
    assign mem_iext		= inst_ld_b | inst_ld_h;

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

    wire op_br_compare;
    wire br_valid;
    assign op_br_compare = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
    assign rj_value  = (ex_valid && rf_raddr1 == ex_dest && ex_ex_forward)? EX_result :
           (mem_valid && rf_raddr1 == mem_dest && mem_ex_forward) ? mem_EX_result: // mem段之间是没有优先级的 但是流水段之间有。
           (mem_valid && rf_raddr1 == mem_dest && mem_mem_forward)? mem_result:
           (rf_raddr1 != 0 && wb_valid && rf_raddr1 == wb_dest && (wb_wb_forward || wb_ex_forward || wb_mem_forward))? final_result:
           rf_rdata1;
    assign rkd_value = (ex_valid && rf_raddr2 == ex_dest && ex_ex_forward)? EX_result :
           (mem_valid && rf_raddr2 == mem_dest && mem_ex_forward) ? mem_EX_result:
           (mem_valid && rf_raddr2 == mem_dest && mem_mem_forward)? mem_result:
           (rf_raddr2 != 0 && wb_valid && rf_raddr2 == wb_dest && (wb_wb_forward || wb_ex_forward || wb_mem_forward))? final_result:
           rf_rdata2;

    assign br_valid = ~(op_br_compare && (ex_valid && (ex_ex_forward || ex_mem_forward) && (rf_raddr1 == ex_dest || rf_raddr2 == ex_dest ) // 跟EX段的ex或mem数据相关
                                          || mem_valid && mem_mem_forward && (rf_raddr1 == mem_dest || rf_raddr2 == mem_dest)) // 等待MEM段的MEM_out再forward给branch
                        || (ex_valid && ex_inst_csr && data_related_ex)
                        || (mem_valid && mem_inst_csr && data_related_mem));

    assign rj_eq_rd = (rj_value == rkd_value);
    assign rj_less_rd = ($signed(rj_value) < $signed(rkd_value));
    assign rj_uless_rd = ($unsigned(rj_value) < $unsigned(rkd_value));
    assign br_taken = (   inst_beq  &&  rj_eq_rd
                          || inst_bne  && !rj_eq_rd
                          || inst_blt && rj_less_rd
                          || inst_bge && !rj_less_rd
                          || inst_bltu && rj_uless_rd
                          || inst_bgeu && !rj_uless_rd
                          || inst_jirl
                          || inst_bl
                          || inst_b
                      ) && valid && br_valid;
    assign br_target = (inst_beq || inst_bne || inst_blt || inst_bge || inst_bltu || inst_bgeu || inst_bl || inst_b) ? (id_pc + br_offs) :
           /*inst_jirl*/ (rj_value + jirl_offs);

    assign alu_src1 = src1_is_pc  ? id_pc[31:0] : rj_value;
    assign alu_src2 = src2_is_imm ? imm : rkd_value;

    /*------EX------*/

    alu u_alu(
            .alu_op     (ex_alu_op    ),
            .alu_src1   (ex_alu_src1  ),
            .alu_src2   (ex_alu_src2  ),
            .alu_result (alu_result)
        );

    // mul
    // output declaration of module mul
    wire [31:0] mul_result;

    mul_ip u_mul_ip(
               .mul_hres		(ex_mul_hres),
               .mul_signed 	(ex_mul_signed  ),
               .x          	(ex_alu_src1           ),
               .y          	(ex_alu_src2           ),
               .result     	(mul_result      )
           );

    // div
    // output declaration of module div
    wire [31:0] div_s;
    wire [31:0] div_r;
    wire div_complete;

    div u_div(
            .div_clk		(clk		),
            .resetn			(resetn			),
            .div			(ex_div_enable & ~(mem_has_exception | wb_has_exception | ex_has_exception | mem_pref_refetch | wb_pref_refetch | ex_pref_refetch)			),
            .div_signed		(ex_div_signed				),
            .x				(ex_alu_src1		),
            .y				(ex_alu_src2			),
            .s				(div_s		),
            .r				(div_r		),
            .complete		(div_complete)
        );
    wire [31:0] div_result;
    assign div_result = ex_div_res_remainder ? div_r : div_s;

    wire [31:0] timer_value;
    timer u_timer(
              .clk	(clk	),
              .reset	(reset),
              .timer_op	(ex_timer_op),
              .rvalue	(timer_value)
          );

    assign EX_result = ex_res_from_timer ? timer_value :
           ex_div_enable ? div_result :
           ex_mul_enable ? mul_result :
           alu_result; // EX结果的MUX GATE

    wire ex_ale; // 地址非对齐异常

    assign ex_ale = ex_op_st_h & (EX_result[0]!=1'b0)
           |	ex_op_st_w & (EX_result[1:0]!=2'b0)
           |	ex_mem_word & (EX_result[1:0]!=2'b0)
           |	ex_mem_half & (EX_result[0]!=1'b0);

    wire [3:0] mem_we;
    assign mem_we = ex_op_st_b ? (EX_result[1:0]==2'b00 ? 4'b0001 :
                                  EX_result[1:0]==2'b01 ? 4'b0010 :
                                  EX_result[1:0]==2'b10 ? 4'b0100 :
                                  4'b1000) :
           ex_op_st_h ? (EX_result[1:0]==2'b00 ? 4'b0011 :
                         4'b1100) :
           {4{ex_op_st_w}};
    assign id_has_exception = id_valid & (id_pref_adef | id_ine | id_break | id_syscall | id_has_int | id_ertn_flush | id_pref_tlbr | id_pref_pif | id_pref_ppi);
    assign mem_has_exception = mem_valid & (mem_pref_adef | mem_ex_ale | mem_id_ine | mem_id_break | mem_id_syscall | mem_id_has_int | mem_id_ertn_flush | mem_pref_tlbr | mem_pref_pif | mem_pref_ppi | mem_ex_tlbr | mem_ex_pil | mem_ex_pis | mem_ex_ppi | mem_ex_pme);
    assign ex_has_exception = ex_valid & (ex_ale | ex_pref_adef | ex_id_ine | ex_id_break | ex_id_syscall | ex_id_has_int | ex_id_ertn_flush | ex_pref_tlbr | ex_pref_pif | ex_pref_ppi | ex_tlbr | ex_pil | ex_pis | ex_ppi | ex_pme);


    /*T L B*/
    // output declaration of module tlb
    wire s0_found;
    wire [3:0] s0_index;
    wire [19:0] s0_ppn;
    wire [5:0] s0_ps;
    wire [1:0] s0_plv;
    wire [1:0] s0_mat;
    wire s0_d;
    wire s0_v;
    wire s1_found;
    wire [3:0] s1_index;
    wire [19:0] s1_ppn;
    wire [5:0] s1_ps;
    wire [1:0] s1_plv;
    wire [1:0] s1_mat;
    wire s1_d;
    wire s1_v;
    wire r_e;
    wire [18:0] r_vppn;
    wire [5:0] r_ps;
    wire [9:0] r_asid;
    wire r_g;
    wire [19:0] r_ppn0;
    wire [1:0] r_plv0;
    wire [1:0] r_mat0;
    wire r_d0;
    wire r_v0;
    wire [19:0] r_ppn1;
    wire [1:0] r_plv1;
    wire [1:0] r_mat1;
    wire r_d1;
    wire r_v1;


    wire [18:0] s1_vppn;
    wire s1_va_bit12;
    wire [9:0] s1_asid;

    wire [3:0] w_index;
    wire w_e;
    wire [18:0] w_vppn;
    wire [5:0] w_ps;
    wire [9:0] w_asid;
    wire w_g;
    wire [19:0] w_ppn0;
    wire [1:0] w_plv0;
    wire [1:0] w_mat0;
    wire w_d0;
    wire w_v0;
    wire [19:0] w_ppn1;
    wire [1:0] w_plv1;
    wire [1:0] w_mat1;
    wire w_d1;
    wire w_v1;


    /*------MMU Unit------*/
    wire [31:0] data_sram_vaddr = EX_result & 32'hFFFF_FFFC;

    // 直接地址翻译部件
    wire [31:0] data_sram_daddr = data_sram_vaddr;

    // 直接映射
    wire data_hit_dmw0 = data_sram_vaddr[31:29]==out_dmw0[`CSR_DMW0_VSEG]&&(out_crmd_plv==2'b00 && out_dmw0[`CSR_DMW0_PLV0] || out_crmd_plv==2'b11 && out_dmw0[`CSR_DMW0_PLV3]);
    wire data_hit_dmw1 = data_sram_vaddr[31:29]==out_dmw1[`CSR_DMW1_VSEG]&&(out_crmd_plv==2'b00 && out_dmw1[`CSR_DMW1_PLV0] || out_crmd_plv==2'b11 && out_dmw1[`CSR_DMW1_PLV3]);
    wire [31:0] data_sram_dmwaddr =
         data_hit_dmw0?{out_dmw0[`CSR_DMW0_PSEG],data_sram_vaddr[28:0]}:
         data_hit_dmw1?{out_dmw1[`CSR_DMW1_PSEG],data_sram_vaddr[28:0]}:
         data_sram_vaddr ;

    // 页表映射
    assign s1_vppn = ex_tlbsrch_op ? out_tlbehi_vppn : (ex_invtlb_valid ? invtlb_va[31:13] : data_sram_vaddr[31:13]); // data vppn MUX
    assign s1_va_bit12 = ex_mem_op ? data_sram_vaddr[12] : 0;
    assign s1_asid = ex_invtlb_valid ? invtlb_asid :
           // ex_tlbsrch_op/ex_mem_op
           out_asid_asid;
    wire [31:0] data_sram_tlbaddr = {s1_ppn,data_sram_vaddr[11:0]};

    // 异常  tlbr > pi* > ppi > pme
    wire data_use_tlb = out_crmd_pg && !data_hit_dmw0 && !data_hit_dmw1;
    wire ex_tlbr = out_crmd_pg ? !s1_found && ex_mem_op && data_use_tlb : 0;
    wire ex_pil = out_crmd_pg ? !s1_v && ex_op_load && !ex_tlbr && data_use_tlb: 0;
    wire ex_pis = out_crmd_pg ? !s1_v && ex_op_store && !ex_tlbr && data_use_tlb: 0;
    wire ex_ppi = out_crmd_pg ? (out_crmd_plv > s1_plv) && ex_mem_op && !ex_tlbr && !ex_pil && !ex_pis && data_use_tlb: 0;
    wire ex_pme = out_crmd_pg ? ex_op_store && !s1_d && !ex_tlbr && !ex_pil && !ex_pis && !ex_ppi && data_use_tlb: 0;
    wire ex_has_addr_exception = ex_tlbr | ex_pil | ex_pis | ex_ppi | ex_pme;

    // MUX
    wire [31:0] data_sram_paddr;
    assign data_sram_paddr = out_crmd_da ? data_sram_daddr :
           (data_hit_dmw0 || data_hit_dmw1) ? data_sram_dmwaddr :
           data_sram_tlbaddr;

    assign data_sram_mat = out_crmd_da ? out_crmd_datm :
           data_hit_dmw0 ? out_dmw0[`CSR_DMW0_MAT] :
           data_hit_dmw1 ? out_dmw1[`CSR_DMW1_MAT] :
           s1_mat;

    // assign data_sram_req = ex_mem_op && mem_allowin;
    assign data_sram_wr = (ex_op_st_b | ex_op_st_h | ex_op_st_w) && (!wb_pref_refetch && !mem_pref_refetch && !ex_pref_refetch && !wb_has_exception && !mem_has_exception && !ex_has_exception) && ex_valid; // 如果其或者其后的流水段发生异常，则停止写ram
    assign data_sram_size = (ex_mem_byte) ? 2'b00 :
           (ex_mem_half) ? 2'b01 : // 写传输size=4靠写掩码写位 读定义传输size
           2'b10;
    assign data_sram_wstrb    = mem_we & {4{valid}};
    assign data_sram_index = data_sram_vaddr[11:4];
    assign data_sram_tag = data_sram_paddr[31:12];
    assign data_sram_offset = data_sram_vaddr[3:0];
    assign data_sram_wdata = ex_op_st_b ? {4{ex_rkd_value[7:0]}} :
           ex_op_st_h ? {2{ex_rkd_value[15:0]}} :
           ex_rkd_value;

    reg waiting_for_data;
    always @(posedge clk) begin
        if (reset ) begin
            data_sram_req <= 0;
            waiting_for_data <= 0;
        end
        if (ex_valid && ex_mem_op && mem_allowin && !waiting_for_data) begin // TODO:不发出产生地址异常的请求
            data_sram_req <= 1;
        end
        if (data_sram_addr_ok && data_sram_req) begin
            data_sram_req <= 0;
            waiting_for_data <= 1;
        end
        else if (waiting_for_data && data_sram_data_ok) begin
            waiting_for_data <= 0;
        end
    end


    wire out_crmd_da;
    wire out_crmd_pg;
	wire [1:0] out_crmd_datm;
    wire [1:0] out_crmd_plv;
    wire [31:0] out_dmw0;
    wire [31:0] out_dmw1;
    wire [9:0] out_asid_asid;
    wire [18:0] out_tlbehi_vppn;
    wire [3:0] out_tlbidx_index;
    wire [31:0] out_tlbelo0;
    wire [31:0] out_tlbelo1;
    wire [5:0] out_tlbidx_ps;
    wire [5:0] out_estat_ecode;

    wire [3:0] in_tlbidx_index;
    wire in_tlbidx_ne;
    wire [9:0] in_asid_asid;
    wire [18:0] in_tlbehi_vppn;
    wire [31:0] in_tlbelo0;
    wire [31:0] in_tlbelo1;
    wire [5:0] in_tlbidx_ps;

    // EX tlbsrch
    wire [3:0] tlbsrch_tlbidx_index;
    wire tlbsrch_tlbidx_ne;


    assign tlbsrch_tlbidx_index = s1_found ? {12'b0,s1_index} : out_tlbidx_index;
    assign tlbsrch_tlbidx_ne = s1_found ? 0 : 1;

    // WB tlbrd
    wire [3:0] r_index;
    wire tlbrd_tlbidx_ne;
    wire [18:0] tlbrd_tlbehi_vppn;
    wire [31:0] tlbrd_tlbelo0;
    wire [31:0] tlbrd_tlbelo1;
    wire [5:0] tlbrd_tlbidx_ps;
    wire [9:0] tlbrd_asid_asid;

    assign r_index = wb_tlbrd_op ? out_tlbidx_index : 0;
    assign tlbrd_tlbidx_ne = r_e ? 0 : 1;
    assign tlbrd_tlbehi_vppn = r_e ? r_vppn : 0;
    assign tlbrd_tlbelo0 = r_e ? {4'b0,r_ppn0,1'b0,r_g,r_mat0,r_plv0,r_d0,r_v0} : 0;
    assign tlbrd_tlbelo1 = r_e ? {4'b0,r_ppn1,1'b0,r_g,r_mat1,r_plv1,r_d1,r_v1} : 0;
    assign tlbrd_tlbidx_ps = r_e ? r_ps : 0;
    assign tlbrd_asid_asid = r_e ? r_asid : 0;

    // WB tlbwr/tlbfill
    wire tlb_we;
    assign tlb_we = wb_tlbwr_op | wb_tlbfill_op;
    assign w_index = out_tlbidx_index; // TODO:TLBFILL为了简化实现，定义与tlbwr相同的index
    assign w_e = (out_estat_ecode==`ECODE_TLBR) ? 1 :
           ~out_tlbidx_ne;
    assign {w_vppn,w_ps,w_g,w_asid} = {out_tlbehi_vppn,out_tlbidx_ps,
                                       out_tlbelo0[`CSR_TLBELO0_G]&out_tlbelo1[`CSR_TLBELO1_G],
                                       out_asid_asid};
    assign {w_ppn0,w_plv0,w_mat0,w_d0,w_v0} = {out_tlbelo0[`CSR_TLBELO0_PPN],
            out_tlbelo0[`CSR_TLBELO0_PLV],
            out_tlbelo0[`CSR_TLBELO0_MAT],
            out_tlbelo0[`CSR_TLBELO0_D],
            out_tlbelo0[`CSR_TLBELO0_V]};
    assign {w_ppn1,w_plv1,w_mat1,w_d1,w_v1} = {out_tlbelo1[`CSR_TLBELO1_PPN],
            out_tlbelo1[`CSR_TLBELO1_PLV],
            out_tlbelo1[`CSR_TLBELO1_MAT],
            out_tlbelo1[`CSR_TLBELO1_D],
            out_tlbelo1[`CSR_TLBELO1_V]};

    // EX invtlb
    wire [9:0] invtlb_asid;
    wire [31:0] invtlb_va;
    assign invtlb_asid = ex_rj_value[9:0];
    assign invtlb_va = ex_rkd_value;

    // MUX
    assign in_tlbidx_index = tlbsrch_tlbidx_index;
    assign in_tlbidx_ne = wb_tlbrd_op ? tlbrd_tlbidx_ne : tlbsrch_tlbidx_ne;
    assign in_asid_asid = tlbrd_asid_asid;
    assign in_tlbehi_vppn = tlbrd_tlbehi_vppn;
    assign in_tlbelo0 = tlbrd_tlbelo0;
    assign in_tlbelo1 = tlbrd_tlbelo1;
    assign in_tlbidx_ps = tlbrd_tlbidx_ps;

    tlb #(
            .TLBNUM 	(16  ))
        u_tlb(
            .clk          	(clk           ),
            .s0_vppn      	(s0_vppn       ),
            .s0_va_bit12  	(s0_va_bit12   ),
            .s0_asid      	(s0_asid       ),
            .s0_found     	(s0_found      ),
            .s0_index     	(s0_index      ),
            .s0_ppn       	(s0_ppn        ),
            .s0_ps        	(s0_ps         ),
            .s0_plv       	(s0_plv        ),
            .s0_mat       	(s0_mat        ),
            .s0_d         	(s0_d          ),
            .s0_v         	(s0_v          ),

            .s1_vppn      	(s1_vppn       ),
            .s1_va_bit12  	(s1_va_bit12   ),
            .s1_asid      	(s1_asid       ),
            .s1_found     	(s1_found      ),
            .s1_index     	(s1_index      ),
            .s1_ppn       	(s1_ppn        ),
            .s1_ps        	(s1_ps         ),
            .s1_plv       	(s1_plv        ),
            .s1_mat       	(s1_mat        ),
            .s1_d         	(s1_d          ),
            .s1_v         	(s1_v          ),

            .invtlb_valid 	(ex_invtlb_valid  ),
            .invtlb_op    	(ex_invtlb_op     ),

            .we           	(tlb_we            ),
            .w_index      	(w_index       ),
            .w_e          	(w_e           ),
            .w_vppn       	(w_vppn        ),
            .w_ps         	(w_ps          ),
            .w_asid       	(w_asid        ),
            .w_g          	(w_g           ),
            .w_ppn0       	(w_ppn0        ),
            .w_plv0       	(w_plv0        ),
            .w_mat0       	(w_mat0        ),
            .w_d0         	(w_d0          ),
            .w_v0         	(w_v0          ),
            .w_ppn1       	(w_ppn1        ),
            .w_plv1       	(w_plv1        ),
            .w_mat1       	(w_mat1        ),
            .w_d1         	(w_d1          ),
            .w_v1         	(w_v1          ),

            .r_index      	(r_index       ),
            .r_e          	(r_e           ),
            .r_vppn       	(r_vppn        ),
            .r_ps         	(r_ps          ),
            .r_asid       	(r_asid        ),
            .r_g          	(r_g           ),
            .r_ppn0       	(r_ppn0        ),
            .r_plv0       	(r_plv0        ),
            .r_mat0       	(r_mat0        ),
            .r_d0         	(r_d0          ),
            .r_v0         	(r_v0          ),
            .r_ppn1       	(r_ppn1        ),
            .r_plv1       	(r_plv1        ),
            .r_mat1       	(r_mat1        ),
            .r_d1         	(r_d1          ),
            .r_v1         	(r_v1          )
        );


    /*------MEM------*/

    wire [31:0] mem_out;
    assign mem_out =
           mem_mem_word ? data_sram_rdata :
           mem_mem_half ? (mem_EX_result[1:0] == 2'b00 ? {16'b0, data_sram_rdata[15:0]} :
                           {16'b0, data_sram_rdata[31:16]}) :
           mem_mem_byte ? (mem_EX_result[1:0] == 2'b00 ? {24'b0, data_sram_rdata[7:0]}   :
                           mem_EX_result[1:0] == 2'b01 ? {24'b0, data_sram_rdata[15:8]}  :
                           mem_EX_result[1:0] == 2'b10 ? {24'b0, data_sram_rdata[23:16]} :
                           {24'b0, data_sram_rdata[31:24]}) :
           32'b0;


    assign mem_result =
           mem_mem_uext ? (
               mem_mem_half ? {16'b0, mem_out[15:0]} :
               mem_mem_byte ? {24'b0, mem_out[7:0]} :
               mem_out
           ) :
           mem_mem_iext ? (
               mem_mem_half ? {{16{mem_out[15]}}, mem_out[15:0]} :
               mem_mem_byte ? {{24{mem_out[7]}}, mem_out[7:0]} :
               mem_out
           ) :
           mem_out;

    /*------WB------*/

    // CSR相关指令


    // 异常信号处理
    wire wb_has_exception;
    wire [5:0] wb_ecode;
    wire wb_esubcode;

    assign wb_has_exception = (wb_pref_adef | wb_ex_ale | wb_id_ine | wb_id_break | wb_id_syscall | wb_id_has_int | wb_pref_tlbr | wb_pref_pif | wb_pref_ppi | wb_ex_tlbr | wb_ex_pil | wb_ex_pis | wb_ex_ppi | wb_ex_pme) & wb_valid;
    assign wb_ecode = {6{wb_pref_adef}} & `ECODE_ADE
           | {6{wb_ex_ale}} & `ECODE_ALE
           | {6{wb_id_ine}} & `ECODE_INE
           | {6{wb_id_break}} & `ECODE_BRK
           | {6{wb_id_syscall}} & `ECODE_SYS
           | {6{wb_id_has_int}} & `ECODE_INT
           | {6{wb_pref_tlbr}} & `ECODE_TLBR
           | {6{wb_pref_pif}} & `ECODE_PIF
           | {6{wb_pref_ppi}} & `ECODE_PPI
           | {6{wb_ex_tlbr}} & `ECODE_TLBR
           | {6{wb_ex_pil}} & `ECODE_PIL
           | {6{wb_ex_pis}} & `ECODE_PIS
           | {6{wb_ex_ppi}} & `ECODE_PPI
           | {6{wb_ex_pme}} & `ECODE_PME;
    assign wb_esubcode = wb_pref_adef & `ESUBCODE_ADEF; // TODO:ADEM暂未实现

    wire [31:0] wb_ex_entry; // 传给IF
    wire wb_has_int; // 传给ID
    wire [31:0] wb_ertn_pc; // 传给IF

    wire [31:0] wb_csr_rvalue;

    // TODO: 线中断暂未实现
    wire [7:0] hw_int_in = 8'b0;
    wire ipi_int_in = 1'b0;
    wire [8:0] coreid_in = 9'b0;

    wire [31:0] wb_vaddr = (wb_pref_tlbr || wb_pref_ppi || wb_pref_pif) ? wb_pc : wb_EX_result;

    // CSR寄存器
    csr_reg u_csr_reg(
                // input
                .clk	(clk),
                .reset		(reset),
                /***指令访问接口***/
                // input
                .csr_re		(1),
                .csr_num	(wb_csr_num),
                .csr_we		(wb_csr_we & wb_valid),
                .csr_wmask	(wb_csr_mask),
                .csr_wvalue	(wb_csr_wvalue),

                .tlbsrch_op (ex_tlbsrch_op),
                .tlbrd_op (wb_tlbrd_op),
                // TLBSRCH TLBRD 对CSR有更改 其他TLB指令都是读CSR

                // output
                .csr_rvalue	(wb_csr_rvalue),
                /***硬件交互接口***/
                // input
                .wb_pc(wb_pc),
                .wb_ex(wb_has_exception),
                .wb_ecode(wb_ecode),
                .wb_esubcode(wb_esubcode),
                .wb_vaddr(wb_vaddr),
                .ertn_flush(wb_id_ertn_flush),
                .hw_int_in(hw_int_in),
                .ipi_int_in(ipi_int_in),
                .coreid_in(coreid_in),
                // output
                .ex_entry(wb_ex_entry), // 送往取指的异常处理入口地址
                .has_int(wb_has_int), // 送往ID的中断有效信号
                .ertn_pc(wb_ertn_pc), // 送往取指的ertn返回的指令地址

                .in_tlbidx_index(in_tlbidx_index),
                .in_tlbidx_ne(in_tlbidx_ne),
                .in_asid_asid(in_asid_asid),
                .in_tlbehi_vppn(in_tlbehi_vppn),
                .in_tlbelo0(in_tlbelo0),
                .in_tlbelo1(in_tlbelo1),
                .in_tlbidx_ps(in_tlbidx_ps),
                .out_crmd_da(out_crmd_da),
                .out_crmd_pg(out_crmd_pg),
				.out_crmd_datm(out_crmd_datm),
                .out_crmd_plv(out_crmd_plv),
                .out_dmw0(out_dmw0),
                .out_dmw1(out_dmw1),
                .out_tlbidx_index(out_tlbidx_index),
                .out_tlbidx_ne(out_tlbidx_ne),
                .out_asid_asid(out_asid_asid),
                .out_tlbehi_vppn(out_tlbehi_vppn),
                .out_tlbelo0(out_tlbelo0),
                .out_tlbelo1(out_tlbelo1),
                .out_tlbidx_ps(out_tlbidx_ps),
                .out_estat_ecode(out_estat_ecode)

            );

    // 写回
    assign final_result = wb_inst_csr ? wb_csr_rvalue :
           wb_res_from_mem ? wb_mem_result :
           wb_EX_result;

    assign rf_we    = wb_gr_we && valid && wb_valid && ~wb_has_exception && ~wb_pref_refetch;
    assign rf_waddr = wb_dest;
    assign rf_wdata = final_result;

    // debug info generate
    assign debug_wb_pc       = wb_pc;
    assign debug_wb_rf_we   = {4{(wb_pc == 32'h1bfffffc) ? 0 : rf_we}};
    assign debug_wb_rf_wnum  = wb_dest;
    assign debug_wb_rf_wdata = final_result;

    /*-------PIPELINE------*/

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


    wire br_taken_cancel = br_taken & id_valid; // todo

    // pre-IF stage
    wire validin;
    wire pre_if_ready_go;
    wire to_fs_valid;
    assign to_fs_valid = inst_sram_req && inst_sram_addr_ok && !exception_cancel_flag && !cancel_inst && !id_has_exception && !ex_has_exception && !mem_has_exception && !wb_has_exception && !wb_id_ertn_flush && !wb_pref_refetch;

    assign pre_if_ready_go = to_fs_valid;
    assign validin = ~(wb_id_ertn_flush | wb_has_exception | wb_pref_refetch) & pre_if_ready_go ;

    // if stage
    wire [31:0] data_in;
    assign data_in = inst_sram_rdata;

    wire if_allowin;
    wire if_ready_go;
    wire if_to_id_valid;
    assign if_ready_go = !waiting_for_inst || buffer_valid; // todo
    assign if_allowin = !if_valid || if_ready_go && id_allowin; // 当前stage无效 或者 准备走并且下一个允许进  则当前可以进
    assign if_to_id_valid = if_valid && if_ready_go; // 当前stage无效或不能走则下一个stage不更新
    always @(posedge clk) begin
        if (reset) begin
            if_valid <= 1'b0;
            if_reg <= 500'b0;
        end
        else if (if_allowin) begin
            if ((wb_id_ertn_flush || wb_has_exception || wb_pref_refetch) && to_fs_valid) begin
                if_valid <= 1'b0;
            end
            else if (br_taken_cancel) begin
                if_valid <= 1'b0;
            end
            else begin
                if_valid <= validin;
            end
        end

        if (validin && if_allowin) begin
            if_reg[31:0] <= pc;
            if_reg[32] <= pref_refetch; // 为什么别的pref生成的标志不用传输？ 因为别的都是根据pc计算的，这个是根据流水线状态
        end
    end

    wire [31:0] if_pc;
    wire [31:0] if_data_in;
    wire if_pref_refetch;

    assign if_pc = if_reg[31:0];
    assign if_data_in = cached_inst;
    assign if_pref_refetch = if_reg[32];

    // id stage

    // --- 数据相关的阻塞用 ---
    // 1.rj | rk = dest:
    // add,sub,slt,sltu,NOR,and,or,xor
    // 2.rj == dest?:
    // slli,srli,srai,addi,ld,jirl
    // 3.rj | rd = dest�?
    // st,beq,bne

    wire rjk_dest_inst = inst_add_w | inst_sub_w | inst_slt | inst_sltu | inst_nor | inst_and | inst_or | inst_xor | inst_sll_w | inst_srl_w | inst_sra_w | inst_mul_w | inst_mulh_w | inst_mulh_wu | inst_div_w | inst_div_wu | inst_mod_w | inst_mod_wu | inst_invtlb;
    wire rj_dest_inst = inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w | inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu | inst_jirl | inst_slti | inst_sltui | inst_andi | inst_ori | inst_xori;
    wire rjd_dest_inst = inst_st_w | inst_st_b | inst_st_h | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu | inst_csrxchg;
    wire rd_dest_inst = inst_csrwr;
    wire is_data_related =
         (rjk_dest_inst & (( ex_valid == 1 && (rj == ex_dest || rk == ex_dest) ) ||
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
          ));
    wire data_related_ex = (rjk_dest_inst & (rj == ex_dest || rk == ex_dest)
                            | rjd_dest_inst & (rj == ex_dest || rd == ex_dest)
                            | rj_dest_inst & (rj == ex_dest)
                            | rd_dest_inst & (rd == ex_dest)
                           ) & ex_valid;
    wire data_related_mem = (rjk_dest_inst & (rj == mem_dest || rk == mem_dest)
                             | rjd_dest_inst & (rj == mem_dest || rd == mem_dest)
                             | rj_dest_inst & (rj == mem_dest)
                             | rd_dest_inst & (rd == mem_dest)
                            ) & mem_valid;

    wire id_allowin;
    wire id_ready_go;
    wire id_to_ex_valid;

    assign id_need_forward_data = rjk_dest_inst | rj_dest_inst | rjd_dest_inst; // 如lu12i不需要forward则不需要load-use阻塞

    assign id_ready_go =~(
               ((ex_valid & ex_mem_forward & (ex_dest == rf_raddr1 || ex_dest == rf_raddr2))  // load-use 阻塞两个流水级 等MEM出数据了再回绕
                | (mem_valid & mem_mem_forward & (mem_dest == rf_raddr1 || mem_dest == rf_raddr2))
                | (op_br_compare & ex_valid & ex_ex_forward & (ex_dest == rf_raddr1 || ex_dest == rf_raddr2)) // 遇到数据冲突的branch指令阻塞一次取mem段alures用于去除关键路径
                | (ex_valid & ex_inst_csr & data_related_ex) //
                | (mem_valid & mem_inst_csr & data_related_mem) // 指令与CSR的rd数据相关，则阻塞到ID段2拍
               )
               & id_need_forward_data
           ); // todo
    assign id_allowin = !id_valid || id_ready_go && ex_allowin;
    assign id_to_ex_valid = id_valid && id_ready_go;
    always @(posedge clk) begin
        if (reset) begin
            id_valid <= 1'b0;
            id_reg <= 500'b0;
        end
        else if (id_allowin) begin
            if (wb_id_ertn_flush | wb_has_exception | mem_has_exception | ex_has_exception | id_has_exception | exception_cancel_flag | wb_pref_refetch) begin
                id_valid <= 1'b0;
            end
            else if (br_taken_cancel || cancel_inst) begin
                id_valid <= 1'b0; // 控制相关
            end
            else begin
                id_valid <= if_to_id_valid;
            end
        end

        if (if_to_id_valid && id_allowin) begin
            id_reg[31:0] <= if_pc;
            id_reg[63:32] <= if_data_in; // data in = inst_sram_rdata
            id_reg[64] <= pref_adef; // 取地址错异常标志
            id_reg[65] <= pref_tlbr;
            id_reg[66] <= pref_pif;
            id_reg[67] <= pref_ppi;
            id_reg[68] <= if_pref_refetch;
        end
        else if (if_to_id_valid && id_allowin && buffer_valid) begin
            id_reg[64:0] <= if_buffer;
        end
    end

    wire [31:0] id_pc;
    wire [31:0] id_inst;
    wire id_pref_adef;
    wire id_pref_tlbr;
    wire id_pref_pif;
    wire id_pref_ppi;
    wire id_pref_refetch;

    assign id_pc = id_reg[31:0];
    assign id_inst = id_reg[63:32];
    assign id_pref_adef = id_reg[64];
    assign id_pref_tlbr = id_reg[65];
    assign id_pref_pif = id_reg[66];
    assign id_pref_ppi = id_reg[67];
    assign id_pref_refetch = id_reg[68];

    wire ex_srch_mem_wr = ex_tlbsrch_op && (mem_csr_we && (mem_csr==`CSR_ASID || mem_csr==`CSR_TLBEHI) || mem_tlbrd_op) && mem_valid;

    wire ex_allowin;
    wire ex_ready_go;
    wire ex_to_mem_valid;

    // ex stage
    assign ex_ready_go = ex_div_enable ? div_complete :
           ex_mem_op ? data_sram_req && data_sram_addr_ok :
           ex_tlbsrch_op ? ~ex_srch_mem_wr :
           1; // todo
    assign ex_allowin = !ex_valid || ex_ready_go && mem_allowin;
    assign ex_to_mem_valid = ex_valid && ex_ready_go;
    always @(posedge clk) begin
        if (reset) begin
            ex_valid <= 1'b0;
            ex_reg <= 500'b0;
        end
        else if (wb_id_ertn_flush | wb_has_exception | wb_pref_refetch) begin
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
            ex_reg[141] <= gr_we;
            ex_reg[146:142] <= dest;
            ex_reg[147] <= res_from_mem;
            ex_reg[179:148] <= rkd_value;

            ex_reg[180] <= ex_forward;
            ex_reg[181] <= mem_forward;
            ex_reg[182] <= wb_forward;

            ex_reg[214:183] <= rj_value;

            ex_reg[215] <= mul_signed;
            ex_reg[216] <= mul_hres;
            ex_reg[217] <= mul_enable;

            ex_reg[219] <= div_enable;
            ex_reg[220] <= div_signed;
            ex_reg[221] <= div_res_remainder;

            ex_reg[222] <= mem_word;
            ex_reg[223] <= mem_half;
            ex_reg[224] <= mem_byte;
            ex_reg[225] <= mem_uext;
            ex_reg[226] <= mem_iext;

            ex_reg[227] <= op_st_b;
            ex_reg[228] <= op_st_h;
            ex_reg[229] <= op_st_w;

            ex_reg[230] <= id_pref_adef;
            ex_reg[231] <= id_ine;
            ex_reg[232] <= id_break;
            ex_reg[233] <= id_syscall;
            ex_reg[234] <= id_has_int;
            ex_reg[235] <= id_ertn_flush;

            ex_reg[249:236] <= csr;
            ex_reg[281:250] <= csr_mask;
            ex_reg[282] <= csr_we;
            ex_reg[314:283] <= csr_wvalue;
            ex_reg[315] <= inst_csr;

            ex_reg[316] <= res_from_timer;
            ex_reg[317] <= timer_op;
            ex_reg[318] <= mem_op;
            ex_reg[319] <= tlbsrch_op;
            ex_reg[320] <= tlbrd_op;
            ex_reg[321] <= tlbwr_op;
            ex_reg[322] <= tlbfill_op;
            ex_reg[323] <= invtlb_valid;
            ex_reg[328:324] <= invtlb_op;
            ex_reg[329] <= op_store;
            ex_reg[330] <= op_load;

            ex_reg[331] <= id_pref_tlbr;
            ex_reg[332] <= id_pref_pif;
            ex_reg[333] <= id_pref_ppi;
            ex_reg[334] <= id_pref_refetch;
        end
    end

    wire		ex_mul_signed;
    wire		ex_mul_hres;
    wire		ex_mul_enable;

    wire [31:0] ex_pc;
    wire [31:0] ex_inst;
    wire ex_pref_adef;
    wire ex_id_ine;
    wire ex_id_break;
    wire ex_id_syscall;
    wire ex_id_has_int;
    wire ex_id_ertn_flush;
    wire ex_res_from_timer;
    wire ex_timer_op;

    wire [13:0] ex_csr;
    wire [31:0] ex_csr_mask;
    wire ex_csr_we;
    wire [31:0] ex_csr_wvalue;
    wire ex_inst_csr;

    wire [31:0] ex_alu_src1;
    wire [31:0] ex_alu_src2;
    wire [11:0] ex_alu_op;

    wire		ex_div_enable;
    wire		ex_div_signed;
    wire		ex_div_res_remainder;

    wire		ex_op_st_b;
    wire		ex_op_st_h;
    wire		ex_op_st_w;

    wire		ex_pref_tlbr;
    wire		ex_pref_pif;
    wire		ex_pref_ppi;

    wire		ex_pref_refetch;

    wire ex_gr_we;
    wire [4:0] ex_dest;
    wire ex_res_from_mem;
    wire [31:0] ex_rj_value;
    wire [31:0] ex_rkd_value;
    wire ex_mem_word;
    wire ex_mem_half;
    wire ex_mem_byte;
    wire ex_mem_uext;
    wire ex_mem_iext;

    wire ex_ex_forward;
    wire ex_mem_forward;
    wire ex_wb_forward;

    wire ex_mem_op;

    wire ex_tlbsrch_op;
    wire ex_tlbrd_op;
    wire ex_tlbwr_op;
    wire ex_tlbfill_op;
    wire ex_invtlb_valid;
    wire [4:0] ex_invtlb_op;

    wire ex_op_store;
    wire ex_op_load;

    assign ex_mul_signed = ex_reg[215];
    assign ex_mul_hres = ex_reg[216];
    assign ex_mul_enable = ex_reg[217];

    assign ex_div_enable = ex_reg[219];
    assign ex_div_signed = ex_reg[220];
    assign ex_div_res_remainder = ex_reg[221];

    assign ex_pc = ex_reg[31:0];
    assign ex_inst = ex_reg[63:32];
    assign ex_alu_src1 = ex_reg[95:64];
    assign ex_alu_src2 = ex_reg[127:96];
    assign ex_alu_op = ex_reg[139:128];

    assign ex_gr_we = ex_reg[141];
    assign ex_dest = ex_reg[146:142];
    assign ex_res_from_mem = ex_reg[147];
    assign ex_rkd_value = ex_reg[179:148];
    assign ex_rj_value = ex_reg[214:183];

    assign ex_ex_forward = ex_reg[180];
    assign ex_mem_forward = ex_reg[181];
    assign ex_wb_forward = ex_reg[182];

    assign ex_mem_word = ex_reg[222];
    assign ex_mem_half = ex_reg[223];
    assign ex_mem_byte = ex_reg[224];
    assign ex_mem_uext = ex_reg[225];
    assign ex_mem_iext = ex_reg[226];

    assign ex_op_st_b = ex_reg[227];
    assign ex_op_st_h = ex_reg[228];
    assign ex_op_st_w = ex_reg[229];

    assign ex_pref_adef = ex_reg[230];
    assign ex_id_ine = ex_reg[231];
    assign ex_id_break = ex_reg[232];
    assign ex_id_syscall = ex_reg[233];
    assign ex_id_has_int = ex_reg[234];
    assign ex_id_ertn_flush = ex_reg[235];

    assign ex_csr = ex_reg[249:236];
    assign ex_csr_mask = ex_reg[281:250];
    assign ex_csr_we = ex_reg[282];
    assign ex_csr_wvalue = ex_reg[314:283];
    assign ex_inst_csr = ex_reg[315];

    assign ex_res_from_timer = ex_reg[316];
    assign ex_timer_op = ex_reg[317];
    assign ex_mem_op = ex_reg[318];

    assign ex_tlbsrch_op = ex_reg[319];
    assign ex_tlbrd_op = ex_reg[320];
    assign ex_tlbwr_op = ex_reg[321];
    assign ex_tlbfill_op = ex_reg[322];
    assign ex_invtlb_valid = ex_reg[323];
    assign ex_invtlb_op = ex_reg[328:324];
    assign ex_op_store = ex_reg[329];
    assign ex_op_load = ex_reg[330];

    assign ex_pref_tlbr = ex_reg[331];
    assign ex_pref_pif = ex_reg[332];
    assign ex_pref_ppi = ex_reg[333];
    assign ex_pref_refetch = ex_reg[334];

    // mem stage
    wire mem_allowin;
    wire mem_ready_go;
    wire mem_to_wb_valid;

    assign mem_ready_go = !waiting_for_data;
    assign mem_allowin = !mem_valid || mem_ready_go && wb_allowin;
    assign mem_to_wb_valid = mem_valid && mem_ready_go;
    always @(posedge clk) begin
        if (reset) begin
            mem_valid <= 1'b0;
            mem_reg <= 500'b0;
        end
        else if (wb_id_ertn_flush | wb_has_exception | wb_pref_refetch) begin
            mem_valid <= 1'b0;
        end
        else if (mem_allowin) begin
            mem_valid <= ex_to_mem_valid;
        end

        if (ex_to_mem_valid && mem_allowin) begin
            mem_reg[31:0] <= ex_pc;
            mem_reg[63:32] <= ex_inst;
            mem_reg[65] <= ex_gr_we;
            mem_reg[70:66] <= ex_dest;
            mem_reg[71] <= ex_res_from_mem;
            mem_reg[103:72] <= ex_rkd_value;
            mem_reg[135:104] <= EX_result; // EX result

            mem_reg[136] <= ex_ex_forward;
            mem_reg[137] <= ex_mem_forward;
            mem_reg[138] <= ex_wb_forward;

            mem_reg[143] <= ex_mem_word;
            mem_reg[144] <= ex_mem_half;
            mem_reg[145] <= ex_mem_byte;
            mem_reg[146] <= ex_mem_uext;
            mem_reg[147] <= ex_mem_iext;

            mem_reg[148] <= ex_op_st_b;
            mem_reg[149] <= ex_op_st_h;
            mem_reg[150] <= ex_op_st_w;

            mem_reg[151] <= ex_pref_adef;
            mem_reg[152] <= ex_ale;
            mem_reg[153] <= ex_id_ine;
            mem_reg[154] <= ex_id_break;
            mem_reg[155] <= ex_id_syscall;
            mem_reg[156] <= ex_id_has_int;
            mem_reg[157] <= ex_id_ertn_flush;

            mem_reg[171:158] <= ex_csr;
            mem_reg[203:172] <= ex_csr_mask;
            mem_reg[204] <= ex_csr_we;
            mem_reg[236:205] <= ex_csr_wvalue;
            mem_reg[237] <= ex_inst_csr;
            mem_reg[238] <= ex_mem_op;

            mem_reg[239] <= ex_tlbrd_op;
            mem_reg[240] <= ex_tlbwr_op;
            mem_reg[241] <= ex_tlbfill_op;

            mem_reg[242] <= ex_pref_tlbr;
            mem_reg[243] <= ex_pref_pif;
            mem_reg[244] <= ex_pref_ppi;
            mem_reg[245] <= ex_tlbr;
            mem_reg[246] <= ex_pil;
            mem_reg[247] <= ex_pis;
            mem_reg[248] <= ex_ppi;
            mem_reg[249] <= ex_pme;
            mem_reg[250] <= ex_pref_refetch;
            mem_reg[251] <= ex_invtlb_valid;
        end
    end

    wire [31:0] mem_pc;
    wire [31:0] mem_inst;
    wire mem_gr_we;
    wire [4:0] mem_dest;
    wire mem_res_from_mem;
    wire [31:0] mem_rkd_value;
    wire [31:0] mem_EX_result;

    wire mem_ex_forward;
    wire mem_mem_forward;
    wire mem_wb_forward;

    wire mem_mem_word;
    wire mem_mem_half;
    wire mem_mem_byte;
    wire mem_mem_uext;
    wire mem_mem_iext;

    wire mem_op_st_b;
    wire mem_op_st_h;
    wire mem_op_st_w;

    wire mem_pref_adef;
    wire mem_ex_ale;
    wire mem_id_ine;
    wire mem_id_break;
    wire mem_id_syscall;
    wire mem_id_has_int;
    wire mem_id_ertn_flush;

    wire [13:0] mem_csr;
    wire [31:0] mem_csr_mask;
    wire mem_csr_we;
    wire [31:0] mem_csr_wvalue;
    wire mem_inst_csr;

    wire mem_mem_op;

    wire mem_tlbrd_op;
    wire mem_tlbwr_op;
    wire mem_tlbfill_op;

    wire mem_pref_tlbr;
    wire mem_pref_pif;
    wire mem_pref_ppi;
    wire mem_ex_tlbr;
    wire mem_ex_pil;
    wire mem_ex_pis;
    wire mem_ex_ppi;
    wire mem_ex_pme;

    wire mem_pref_refetch;

    assign mem_pc = mem_reg[31:0];
    assign mem_inst = mem_reg[63:32];
    assign mem_gr_we = mem_reg[65];
    assign mem_dest = mem_reg[70:66];
    assign mem_res_from_mem = mem_reg[71];
    assign mem_rkd_value = mem_reg[103:72];
    assign mem_EX_result = mem_reg[135:104];

    assign mem_ex_forward = mem_reg[136];
    assign mem_mem_forward = mem_reg[137];
    assign mem_wb_forward = mem_reg[138];

    assign mem_mem_word = mem_reg[143];
    assign mem_mem_half = mem_reg[144];
    assign mem_mem_byte = mem_reg[145];
    assign mem_mem_uext = mem_reg[146];
    assign mem_mem_iext = mem_reg[147];

    assign mem_op_st_b = mem_reg[148];
    assign mem_op_st_h = mem_reg[149];
    assign mem_op_st_w = mem_reg[150];

    assign mem_pref_adef = mem_reg[151];
    assign mem_ex_ale = mem_reg[152];
    assign mem_id_ine = mem_reg[153];
    assign mem_id_break = mem_reg[154];
    assign mem_id_syscall = mem_reg[155];
    assign mem_id_has_int = mem_reg[156];
    assign mem_id_ertn_flush = mem_reg[157];

    assign mem_csr = mem_reg[171:158];
    assign mem_csr_mask = mem_reg[203:172];
    assign mem_csr_we = mem_reg[204];
    assign mem_csr_wvalue = mem_reg[236:205];
    assign mem_inst_csr = mem_reg[237];

    assign mem_mem_op = mem_reg[238];

    assign mem_tlbrd_op = mem_reg[239];
    assign mem_tlbwr_op = mem_reg[240];
    assign mem_tlbfill_op = mem_reg[241];

    assign mem_pref_tlbr = mem_reg[242];
    assign mem_pref_pif = mem_reg[243];
    assign mem_pref_ppi = mem_reg[244];
    assign mem_ex_tlbr = mem_reg[245];
    assign mem_ex_pil = mem_reg[246];
    assign mem_ex_pis = mem_reg[247];
    assign mem_ex_ppi = mem_reg[248];
    assign mem_ex_pme = mem_reg[249];

    assign mem_pref_refetch = mem_reg[250];
    assign mem_invtlb_valid = mem_reg[251];

    // wb stage
    wire out_allow = 1;


    wire wb_ready_go;
    assign wb_ready_go = 1; // todo
    assign wb_allowin = !wb_valid || wb_ready_go && out_allow; // out allow = ?
    always @(posedge clk) begin
        if (reset) begin
            wb_valid <= 1'b0;
            wb_reg <= 500'b0;
        end
        else if (wb_id_ertn_flush || wb_has_exception || wb_pref_refetch) begin
            wb_valid <= 1'b0;
        end
        else if (wb_allowin) begin
            wb_valid = mem_to_wb_valid;
        end

        if (mem_to_wb_valid && wb_allowin) begin
            wb_reg[31:0] <= mem_pc;
            wb_reg[63:32] <= mem_inst;
            wb_reg[64] <= mem_gr_we;
            wb_reg[69:65] <= mem_dest;
            wb_reg[70] <= mem_res_from_mem;
            wb_reg[102:71] <= mem_EX_result;

            wb_reg[103] <= mem_ex_forward;
            wb_reg[104] <= mem_mem_forward;
            wb_reg[105] <= mem_wb_forward;

            wb_reg[140] <= mem_mem_word;
            wb_reg[141] <= mem_mem_half;
            wb_reg[142] <= mem_mem_byte;
            wb_reg[143] <= mem_mem_uext;
            wb_reg[144] <= mem_mem_iext;

            wb_reg[176:145] <= mem_result;

            wb_reg[177] <= mem_pref_adef;
            wb_reg[178] <= mem_ex_ale;
            wb_reg[179] <= mem_id_ine;
            wb_reg[180] <= mem_id_break;
            wb_reg[181] <= mem_id_syscall;
            wb_reg[182] <= mem_id_has_int;
            wb_reg[183] <= mem_id_ertn_flush;

            wb_reg[197:184] <= mem_csr;
            wb_reg[229:198] <= mem_csr_mask;
            wb_reg[230] <= mem_csr_we;
            wb_reg[262:231] <= mem_csr_wvalue;
            wb_reg[263] <= mem_inst_csr;

            wb_reg[264] <= mem_tlbrd_op;
            wb_reg[265] <= mem_tlbwr_op;
            wb_reg[266] <= mem_tlbfill_op;

            wb_reg[267] <= mem_pref_tlbr;
            wb_reg[268] <= mem_pref_pif;
            wb_reg[269] <= mem_pref_ppi;
            wb_reg[270] <= mem_ex_tlbr;
            wb_reg[271] <= mem_ex_pil;
            wb_reg[272] <= mem_ex_pis;
            wb_reg[273] <= mem_ex_ppi;
            wb_reg[274] <= mem_ex_pme;
            wb_reg[275] <= mem_pref_refetch;
            wb_reg[276] <= mem_invtlb_valid;
        end
    end
    assign validout = wb_valid && wb_ready_go ; // not defined
    assign dataout = wb_reg; // not defined

    wire [31:0] wb_pc;
    wire [31:0] wb_inst;
    wire wb_gr_we;
    wire [4:0] wb_dest;
    wire [31:0] wb_EX_result;
    wire wb_res_from_mem;

    wire wb_ex_forward;
    wire wb_mem_forward;
    wire wb_wb_forward;

    wire wb_mem_word;
    wire wb_mem_half;
    wire wb_mem_byte;
    wire wb_mem_uext;
    wire wb_mem_iext;

    wire [31:0] wb_mem_result;

    wire wb_pref_adef;
    wire wb_ex_ale;
    wire wb_id_ine;
    wire wb_id_break;
    wire wb_id_syscall;
    wire wb_id_has_int;
    wire wb_id_ertn_flush;

    wire [13:0] wb_csr_num;
    wire [31:0] wb_csr_mask;
    wire wb_csr_we;
    wire [31:0] wb_csr_wvalue;

    wire wb_tlbrd_op;
    wire wb_tlbwr_op;
    wire wb_tlbfill_op;

    wire wb_pref_tlbr;
    wire wb_pref_pif;
    wire wb_pref_ppi;
    wire wb_ex_tlbr;
    wire wb_ex_pil;
    wire wb_ex_pis;
    wire wb_ex_ppi;
    wire wb_ex_pme;
    wire wb_pref_refetch;
    wire wb_invtlb_valid;

    assign wb_pc = wb_reg[31:0];
    assign wb_inst = wb_reg[63:32];
    assign wb_gr_we = wb_reg[64];
    assign wb_dest = wb_reg[69:65];
    assign wb_res_from_mem = wb_reg[70];
    assign wb_EX_result = wb_reg[102:71];

    assign wb_ex_forward = wb_reg[103];
    assign wb_mem_forward = wb_reg[104];
    assign wb_wb_forward = wb_reg[105];

    assign wb_mem_word = wb_reg[140];
    assign wb_mem_half = wb_reg[141];
    assign wb_mem_byte = wb_reg[142];
    assign wb_mem_uext = wb_reg[143];
    assign wb_mem_iext = wb_reg[144];

    assign wb_mem_result = wb_reg[176:145];

    /*------中断信号------*/
    assign wb_pref_adef = wb_reg[177];
    assign wb_ex_ale = wb_reg[178];
    assign wb_id_ine = wb_reg[179];
    assign wb_id_break = wb_reg[180];
    assign wb_id_syscall = wb_reg[181];
    assign wb_id_has_int = wb_reg[182];
    assign wb_id_ertn_flush = wb_reg[183] & wb_valid;

    /*------csr读写指令信号------*/

    assign wb_csr_num = wb_reg[197:184];
    assign wb_csr_mask = wb_reg[229:198];
    assign wb_csr_we = wb_reg[230];
    assign wb_csr_wvalue = wb_reg[262:231];
    assign wb_inst_csr = wb_reg[263];

    /*------tlb指令信号------*/
    assign wb_tlbrd_op = wb_reg[264];
    assign wb_tlbwr_op = wb_reg[265];
    assign wb_tlbfill_op = wb_reg[266];

    /*------页异常------*/
    assign wb_pref_tlbr = wb_reg[267];
    assign wb_pref_pif = wb_reg[268];
    assign wb_pref_ppi = wb_reg[269];
    assign wb_ex_tlbr = wb_reg[270];
    assign wb_ex_pil = wb_reg[271];
    assign wb_ex_pis = wb_reg[272];
    assign wb_ex_ppi = wb_reg[273];
    assign wb_ex_pme = wb_reg[274];

    assign wb_pref_refetch = wb_reg[275] & wb_valid;
    assign wb_invtlb_valid = wb_reg[276];
endmodule
