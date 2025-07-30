`include "define.v"
module csr_reg(
        input wire clk, // 时钟信号
        input wire reset,
        /***指令访问接口***/
        input wire csr_re, // 读使能
        input wire [13:0] csr_num, // 寄存器号
        input wire csr_we, // 写使能
        input wire [31:0] csr_wmask, // 写掩码
        input wire [31:0] csr_wvalue, // 写数据
        output wire [31:0] csr_rvalue, // 寄存器读返回值

        input wire tlbsrch_op, // tlb指令
        input wire tlbrd_op,

        /***硬件交互接口***/
        input wire [31:0] wb_pc, // wb段pc
        input wire wb_ex, // wb段异常触发信号
        input wire [5:0] wb_ecode, // wb段ecode
        input wire wb_esubcode, // wb段esubcode
        input wire [31:0] wb_vaddr, // wb段异常访问地址

        input wire ertn_flush, // wb段ertn执行有效信号

        input wire [7:0] hw_int_in, // 8个硬中断
        input wire ipi_int_in, // 核间中断

        input wire [8:0] coreid_in, // 核编号CPUID

        output wire [31:0] ex_entry, // 送往取指的异常处理入口地址
        output wire has_int, // 送往ID的中断有效信号

        output wire [31:0] ertn_pc, // 送往取指的ertn返回的指令地址

        input wire [3:0] in_tlbidx_index,
        input wire in_tlbidx_ne,
        input wire [9:0] in_asid_asid,
        input wire [18:0] in_tlbehi_vppn,
        input wire [31:0] in_tlbelo0,
        input wire [31:0] in_tlbelo1,
        input wire [5:0] in_tlbidx_ps,

		output wire out_crmd_da,
		output wire out_crmd_pg,
		output wire [1:0] out_crmd_datm,
		output wire [1:0] out_crmd_plv,
		output wire [31:0] out_dmw0,
		output wire [31:0] out_dmw1,
        output wire [3:0] out_tlbidx_index,
        output wire [9:0] out_asid_asid,
        output wire [18:0] out_tlbehi_vppn,
        output wire [31:0] out_tlbelo0,
        output wire [31:0] out_tlbelo1,
        output wire [5:0] out_tlbidx_ps,
		output wire out_tlbidx_ne,
		output wire [5:0] out_estat_ecode
		

    );

    /**TLB**/
    //
    assign out_asid_asid = csr_asid_asid;
    assign out_tlbehi_vppn = csr_tlbehi_vppn;
    assign out_tlbidx_index = csr_tlbidx_index[3:0];
	assign out_tlbelo0 = csr_tlbelo0_rvalue;
	assign out_tlbelo1 = csr_tlbelo1_rvalue;
	assign out_tlbidx_ps = csr_tlbidx_ps;
	assign out_tlbidx_ne = csr_tlbidx_ne;
	assign out_estat_ecode = csr_estat_ecode;
	assign out_crmd_da = csr_crmd_da;
	assign out_crmd_pg = csr_crmd_pg;
	assign out_crmd_datm = csr_crmd_datm;
	assign out_dmw0 = csr_dmw0_rvalue;
	assign out_dmw1 = csr_dmw1_rvalue;
	assign out_crmd_plv = csr_crmd_plv;

    /**硬件接口逻辑**/
    assign has_int = ((csr_estat_is[12:0] & csr_ecfg_lie[12:0]) != 13'b0) && (csr_crmd_ie == 1'b1);

    assign ex_entry = wb_ex ? (wb_ecode==`ECODE_TLBR ? csr_tlbrentry_rvalue : csr_eentry_rvalue) : wb_pc;

    assign ertn_pc = csr_era_rvalue;

    /*---------基础控制状态寄存器----------*/
    /***CRMD registers***/
    reg [1:0] csr_crmd_plv;
    reg csr_crmd_ie;
    reg csr_crmd_da;
    reg csr_crmd_pg;
    reg [1:0] csr_crmd_datf;
    reg [1:0] csr_crmd_datm;

    always @(posedge clk) begin
        if (reset) begin
            csr_crmd_plv <= 2'b0;
            csr_crmd_ie <= 1'b0;
            csr_crmd_da <= 1'b1;
            csr_crmd_pg <= 1'b0;
            csr_crmd_datf <= 2'b0;
            csr_crmd_datm <= 2'b0;
        end
        else if (wb_ex) begin
			if (wb_ecode==`ECODE_TLBR) begin
				csr_crmd_da <= 1;
				csr_crmd_pg <= 0;
			end
            csr_crmd_plv <= 2'b0;
            csr_crmd_ie <= 1'b0;
        end
        else if (ertn_flush) begin
            csr_crmd_plv <= csr_prmd_pplv;
            csr_crmd_ie <= csr_prmd_pie;
			csr_crmd_da <= csr_estat_ecode==`ECODE_TLBR ? 0 : csr_crmd_da;
			csr_crmd_pg <= csr_estat_ecode==`ECODE_TLBR ? 1 : csr_crmd_pg;
        end
        else if (csr_we && csr_num==`CSR_CRMD) begin
            csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV]&csr_wvalue[`CSR_CRMD_PLV]
                         | ~csr_wmask[`CSR_CRMD_PLV]&csr_crmd_plv;
            csr_crmd_ie <= csr_wmask[`CSR_CRMD_IE]&csr_wvalue[`CSR_CRMD_IE]
                        | ~csr_wmask[`CSR_CRMD_IE]&csr_crmd_ie;
            csr_crmd_da <= csr_wmask[`CSR_CRMD_DA]&csr_wvalue[`CSR_CRMD_DA]
                        | ~csr_wmask[`CSR_CRMD_DA]&csr_crmd_da;
            csr_crmd_pg <= csr_wmask[`CSR_CRMD_PG]&csr_wvalue[`CSR_CRMD_PG]
                        | ~csr_wmask[`CSR_CRMD_PG]&csr_crmd_pg;
            csr_crmd_datf <= csr_wmask[`CSR_CRMD_DATF]&csr_wvalue[`CSR_CRMD_DATF]
                          | ~csr_wmask[`CSR_CRMD_DATF]&csr_crmd_datf;
            csr_crmd_datm <= csr_wmask[`CSR_CRMD_DATM]&csr_wvalue[`CSR_CRMD_DATM]
                          | ~csr_wmask[`CSR_CRMD_DATM]&csr_crmd_datm;
        end
    end

    /***PRMD registers***/
    reg [1:0] csr_prmd_pplv;
    reg csr_prmd_pie;

    always @(posedge clk) begin
        if (wb_ex) begin
            csr_prmd_pplv <= csr_crmd_plv;
            csr_prmd_pie <= csr_crmd_ie;
        end
        else if (csr_we && csr_num==`CSR_PRMD) begin
            csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV]&csr_wvalue[`CSR_PRMD_PPLV]
                          | ~csr_wmask[`CSR_PRMD_PPLV]&csr_prmd_pplv;
            csr_prmd_pie <= csr_wmask[`CSR_PRMD_PIE]&csr_wvalue[`CSR_PRMD_PIE]
                         | ~csr_wmask[`CSR_PRMD_PIE]&csr_prmd_pie;
        end
    end

    /***EUEN registers***/
    reg csr_euen_fpe;

    /***ECFG registers***/
    reg [12:0] csr_ecfg_lie; // lie[10] == 0;

    always @(posedge clk) begin
        if (reset)
            csr_ecfg_lie <= 13'b0;
        else if (csr_we && csr_num==`CSR_ECFG)
            csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE]&13'h1bff&csr_wvalue[`CSR_ECFG_LIE]
                         | ~csr_wmask[`CSR_ECFG_LIE]&13'h1bff&csr_ecfg_lie;
    end

    /***ESTAT registers***/
    reg [12:0] csr_estat_is;
    reg [5:0] csr_estat_ecode;
    reg [8:0] csr_estat_esubcode;

    always @(posedge clk) begin
        if (reset)
            csr_estat_is[1:0] <= 2'b0;
        else if (csr_we && csr_num==`CSR_ESTAT)
            csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10]&csr_wvalue[`CSR_ESTAT_IS10]
                        | ~csr_wmask[`CSR_ESTAT_IS10]&csr_estat_is[1:0];

        csr_estat_is[9:2] <= hw_int_in[7:0];

        csr_estat_is[10] <= 1'b0; // 保留位

        if (timer_cnt[31:0]==32'b0)
            csr_estat_is[11] <= 1'b1;
        else if (csr_we && csr_num==`CSR_TICLR && csr_wmask[`CSR_TICLR_CLR]
                 && csr_wvalue[`CSR_TICLR_CLR])
            csr_estat_is[11] <= 1'b0;

        csr_estat_is[12] <= ipi_int_in;
    end

    always @(posedge clk) begin
        if (wb_ex) begin
            csr_estat_ecode <= wb_ecode;
            csr_estat_esubcode <= wb_esubcode;
        end
    end

    /***ERA registers***/
    reg [31:0] csr_era_pc;

    always @(posedge clk) begin
        if (wb_ex)
            csr_era_pc <= wb_pc;
        else if (csr_we && csr_num==`CSR_ERA)
            csr_era_pc <= csr_wmask[`CSR_ERA_PC]&csr_wvalue[`CSR_ERA_PC]
                       | ~csr_wmask[`CSR_ERA_PC]&csr_era_pc;
    end

    /***BADV registers***/
    reg [31:0] csr_badv_vaddr;
    assign wb_ex_addr_err = wb_ecode==`ECODE_ADE || wb_ecode==`ECODE_ALE || wb_ecode==`ECODE_PIL || wb_ecode==`ECODE_PIS || wb_ecode==`ECODE_PIF || wb_ecode==`ECODE_PME || wb_ecode==`ECODE_PPI || wb_ecode==`ECODE_TLBR;

    always @(posedge clk) begin
        if (wb_ex && wb_ex_addr_err)
            csr_badv_vaddr <= (wb_ecode==`ECODE_ADE && wb_esubcode==`ESUBCODE_ADEF
			|| wb_ecode==`ECODE_PIF) ? wb_pc : wb_vaddr;
    end
    /***EENTRY registers***/
    reg [25:0] csr_eentry_va;
    always @(posedge clk) begin
        if (csr_we && csr_num==`CSR_EENTRY)
            csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA]&csr_wvalue[`CSR_EENTRY_VA]
                          | ~csr_wmask[`CSR_EENTRY_VA]&csr_eentry_va;
    end

    /***CPUID***/
    reg [8:0] csr_cpuid_coreid;

    /***SAVE0-3***/
    reg [31:0] csr_save0_data;
    reg [31:0] csr_save1_data;
    reg [31:0] csr_save2_data;
    reg [31:0] csr_save3_data;
    always @(posedge clk) begin
        if (csr_we && csr_num==`CSR_SAVE0)
            csr_save0_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                           | ~csr_wmask[`CSR_SAVE_DATA]&csr_save0_data;
        if (csr_we && csr_num==`CSR_SAVE1)
            csr_save1_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                           | ~csr_wmask[`CSR_SAVE_DATA]&csr_save1_data;
        if (csr_we && csr_num==`CSR_SAVE2)
            csr_save2_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                           | ~csr_wmask[`CSR_SAVE_DATA]&csr_save2_data;
        if (csr_we && csr_num==`CSR_SAVE3)
            csr_save3_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wvalue[`CSR_SAVE_DATA]
                           | ~csr_wmask[`CSR_SAVE_DATA]&csr_save3_data;

    end

    /***LLBCTL***/
    reg csr_llbctl_rollb;
    reg csr_llbctl_wcllb;
    reg csr_llbctl_klo;


    /*---------TODO: 映射地址翻译相关控制状态寄存器---------*/

    /***TLBIDX***/
    reg [15:0] csr_tlbidx_index;
    reg [5:0] csr_tlbidx_ps;
    reg csr_tlbidx_ne;
    always @(posedge clk) begin
        if (csr_we && csr_num==`CSR_TLBIDX) begin
            csr_tlbidx_index <= csr_wmask[`CSR_TLBIDX_INDEX]&csr_wvalue[`CSR_TLBIDX_INDEX]
                             | ~csr_wmask[`CSR_TLBIDX_INDEX]&csr_tlbidx_index;
            csr_tlbidx_ps <= csr_wmask[`CSR_TLBIDX_PS]&csr_wvalue[`CSR_TLBIDX_PS]
                          | ~csr_wmask[`CSR_TLBIDX_PS]&csr_tlbidx_ps;
            csr_tlbidx_ne <= csr_wmask[`CSR_TLBIDX_NE]&csr_wvalue[`CSR_TLBIDX_NE]
                          | ~csr_wmask[`CSR_TLBIDX_NE]&csr_tlbidx_ne;
        end
        else if (tlbrd_op) begin
            csr_tlbidx_ne <= in_tlbidx_ne;
			csr_tlbidx_ps <= in_tlbidx_ps;
        end
        else if (tlbsrch_op) begin // tlbsrch
            csr_tlbidx_index <= in_tlbidx_index;
            csr_tlbidx_ne <= in_tlbidx_ne;
        end
		else if (tlbrd_op) begin
			csr_tlbidx_ps <= in_tlbidx_ps;
		end

    end

    /***TLBEHI***/
    reg [18:0] csr_tlbehi_vppn;
	wire wb_tlbexception = wb_ecode==`ECODE_TLBR || wb_ecode==`ECODE_PIL || wb_ecode==`ECODE_PIF || wb_ecode==`ECODE_PIS || wb_ecode==`ECODE_PME || wb_ecode==`ECODE_PPI;
    always @(posedge clk) begin
        if (csr_we && csr_num==`CSR_TLBEHI)
            csr_tlbehi_vppn <= csr_wmask[`CSR_TLBEHI_VPPN]&csr_wvalue[`CSR_TLBEHI_VPPN]
                            | ~csr_wmask[`CSR_TLBEHI_VPPN]&csr_tlbehi_vppn;
		else if (wb_ex && wb_tlbexception) begin
			csr_tlbehi_vppn <= wb_vaddr[31:13];
		end
        else if (tlbrd_op) begin
            csr_tlbehi_vppn <= in_tlbehi_vppn;
        end
    end

    /***TLBELO0-1***/
    reg csr_tlbelo0_v;
    reg csr_tlbelo0_d;
    reg [1:0] csr_tlbelo0_plv;
    reg [1:0] csr_tlbelo0_mat;
    reg csr_tlbelo0_g;
    reg [19:0] csr_tlbelo0_ppn; // PALEN=32


    reg csr_tlbelo1_v;
    reg csr_tlbelo1_d;
    reg [1:0] csr_tlbelo1_plv;
    reg [1:0] csr_tlbelo1_mat;
    reg csr_tlbelo1_g;
    reg [19:0] csr_tlbelo1_ppn; // PALEN=32

    always @(posedge clk) begin
        if (csr_we && csr_num==`CSR_TLBELO0) begin
            csr_tlbelo0_v <= csr_wmask[`CSR_TLBELO0_V]&csr_wvalue[`CSR_TLBELO0_V]
                          | ~csr_wmask[`CSR_TLBELO0_V]&csr_tlbelo0_v;
            csr_tlbelo0_d <= csr_wmask[`CSR_TLBELO0_D]&csr_wvalue[`CSR_TLBELO0_D]
                          | ~csr_wmask[`CSR_TLBELO0_D]&csr_tlbelo0_d;
            csr_tlbelo0_plv <= csr_wmask[`CSR_TLBELO0_PLV]&csr_wvalue[`CSR_TLBELO0_PLV]
                            | ~csr_wmask[`CSR_TLBELO0_PLV]&csr_tlbelo0_plv;
            csr_tlbelo0_mat <= csr_wmask[`CSR_TLBELO0_MAT]&csr_wvalue[`CSR_TLBELO0_MAT]
                            | ~csr_wmask[`CSR_TLBELO0_MAT]&csr_tlbelo0_mat;
            csr_tlbelo0_g <= csr_wmask[`CSR_TLBELO0_G]&csr_wvalue[`CSR_TLBELO0_G]
                          | ~csr_wmask[`CSR_TLBELO0_G]&csr_tlbelo0_g;
            csr_tlbelo0_ppn <= csr_wmask[`CSR_TLBELO0_PPN]&csr_wvalue[`CSR_TLBELO0_PPN]
                            | ~csr_wmask[`CSR_TLBELO0_PPN]&csr_tlbelo0_ppn;
        end
        else if (tlbrd_op) begin
            csr_tlbelo0_v <= in_tlbelo0[`CSR_TLBELO0_V];
            csr_tlbelo0_d <= in_tlbelo0[`CSR_TLBELO0_D];
            csr_tlbelo0_plv <= in_tlbelo0[`CSR_TLBELO0_PLV];
            csr_tlbelo0_mat <= in_tlbelo0[`CSR_TLBELO0_MAT];
            csr_tlbelo0_g <= in_tlbelo0[`CSR_TLBELO0_G];
            csr_tlbelo0_ppn <= in_tlbelo0[`CSR_TLBELO0_PPN];
        end
        if (csr_we && csr_num==`CSR_TLBELO1) begin
            csr_tlbelo1_v <= csr_wmask[`CSR_TLBELO1_V]&csr_wvalue[`CSR_TLBELO1_V]
                          | ~csr_wmask[`CSR_TLBELO1_V]&csr_tlbelo1_v;
            csr_tlbelo1_d <= csr_wmask[`CSR_TLBELO1_D]&csr_wvalue[`CSR_TLBELO1_D]
                          | ~csr_wmask[`CSR_TLBELO1_D]&csr_tlbelo1_d;
            csr_tlbelo1_plv <= csr_wmask[`CSR_TLBELO1_PLV]&csr_wvalue[`CSR_TLBELO1_PLV]
                            | ~csr_wmask[`CSR_TLBELO1_PLV]&csr_tlbelo1_plv;
            csr_tlbelo1_mat <= csr_wmask[`CSR_TLBELO1_MAT]&csr_wvalue[`CSR_TLBELO1_MAT]
                            | ~csr_wmask[`CSR_TLBELO1_MAT]&csr_tlbelo1_mat;
            csr_tlbelo1_g <= csr_wmask[`CSR_TLBELO1_G]&csr_wvalue[`CSR_TLBELO1_G]
                          | ~csr_wmask[`CSR_TLBELO1_G]&csr_tlbelo1_g;
            csr_tlbelo1_ppn <= csr_wmask[`CSR_TLBELO1_PPN]&csr_wvalue[`CSR_TLBELO1_PPN]
                            | ~csr_wmask[`CSR_TLBELO1_PPN]&csr_tlbelo1_ppn;
        end
        else if (tlbrd_op) begin
            csr_tlbelo1_v <= in_tlbelo1[`CSR_TLBELO1_V];
            csr_tlbelo1_d <= in_tlbelo1[`CSR_TLBELO1_D];
            csr_tlbelo1_plv <= in_tlbelo1[`CSR_TLBELO1_PLV];
            csr_tlbelo1_mat <= in_tlbelo1[`CSR_TLBELO1_MAT];
            csr_tlbelo1_g <= in_tlbelo1[`CSR_TLBELO1_G];
            csr_tlbelo1_ppn <= in_tlbelo1[`CSR_TLBELO1_PPN];
        end
    end

    /***ASID***/
    reg [9:0] csr_asid_asid;
    reg [7:0] csr_asid_asidbits;
    always @(posedge clk) begin
        if (csr_we && csr_num==`CSR_ASID) begin
            csr_asid_asid <= csr_wmask[`CSR_ASID_ASID]&csr_wvalue[`CSR_ASID_ASID]
                          | ~csr_wmask[`CSR_ASID_ASID]&csr_asid_asid;
            csr_asid_asidbits <= csr_wmask[`CSR_ASID_ASIDBITS]&csr_wvalue[`CSR_ASID_ASIDBITS]
                              | ~csr_wmask[`CSR_ASID_ASIDBITS]&csr_asid_asidbits;
        end
        else if (tlbrd_op) begin
            csr_asid_asid <= in_asid_asid;
        end
    end

    /***PGDL***/
    reg [19:0] csr_pgdl_base;
    always @(posedge clk) begin
        if (csr_we && csr_num==`CSR_PGDL)
            csr_pgdl_base <= csr_wmask[`CSR_PGDL_BASE]&csr_wvalue[`CSR_PGDL_BASE]
                          | ~csr_wmask[`CSR_PGDL_BASE]&csr_pgdl_base;
    end

    /***PGDH***/
    reg [19:0] csr_pgdh_base;
    always @(posedge clk) begin
        if (csr_we && csr_num==`CSR_PGDH)
            csr_pgdh_base <= csr_wmask[`CSR_PGDH_BASE]&csr_wvalue[`CSR_PGDH_BASE]
                          | ~csr_wmask[`CSR_PGDH_BASE]&csr_pgdh_base;
    end
    /***PGD***/
    reg [19:0] csr_pgd_base;
    always @(posedge clk) begin
        if (csr_we && csr_num==`CSR_PGD)
            csr_pgd_base <= csr_wmask[`CSR_PGD_BASE]&csr_wvalue[`CSR_PGD_BASE]
                         | ~csr_wmask[`CSR_PGD_BASE]&csr_pgd_base;
    end
    /***TLBRENTRY***/
    reg [25:0] csr_tlbrentry_pa;
    always @(posedge clk) begin
        if (csr_we && csr_num==`CSR_TLBRENTRY)
            csr_tlbrentry_pa <= csr_wmask[`CSR_TLBRENTRY_PA]&csr_wvalue[`CSR_TLBRENTRY_PA]
                             | ~csr_wmask[`CSR_TLBRENTRY_PA]&csr_tlbrentry_pa;
    end

    /***DMW0-1***/
    reg csr_dmw0_plv0;
    reg csr_dmw0_plv3;
    reg [1:0] csr_dmw0_mat;
    reg [2:0] csr_dmw0_pseg;
    reg [2:0] csr_dmw0_vseg;

    reg csr_dmw1_plv0;
    reg csr_dmw1_plv3;
    reg [1:0] csr_dmw1_mat;
    reg [2:0] csr_dmw1_pseg;
    reg [2:0] csr_dmw1_vseg;

    always @(posedge clk) begin
		if (reset) begin
			csr_dmw0_plv0 <= 0;
			csr_dmw0_plv3 <= 0;
			csr_dmw1_plv0 <= 0;
			csr_dmw1_plv3 <= 0;
		end
        if (csr_we && csr_num==`CSR_DMW0) begin
            csr_dmw0_plv0 <= csr_wmask[`CSR_DMW0_PLV0]&csr_wvalue[`CSR_DMW0_PLV0]
                          | ~csr_wmask[`CSR_DMW0_PLV0]&csr_dmw0_plv0;
            csr_dmw0_plv3 <= csr_wmask[`CSR_DMW0_PLV3]&csr_wvalue[`CSR_DMW0_PLV3]
                          | ~csr_wmask[`CSR_DMW0_PLV3]&csr_dmw0_plv3;
            csr_dmw0_mat <= csr_wmask[`CSR_DMW0_MAT]&csr_wvalue[`CSR_DMW0_MAT]
                         | ~csr_wmask[`CSR_DMW0_MAT]&csr_dmw0_mat;
            csr_dmw0_pseg <= csr_wmask[`CSR_DMW0_PSEG]&csr_wvalue[`CSR_DMW0_PSEG]
                          | ~csr_wmask[`CSR_DMW0_PSEG]&csr_dmw0_pseg;
            csr_dmw0_vseg <= csr_wmask[`CSR_DMW0_VSEG]&csr_wvalue[`CSR_DMW0_VSEG]
                          | ~csr_wmask[`CSR_DMW0_VSEG]&csr_dmw0_vseg;
        end
        if (csr_we && csr_num==`CSR_DMW1) begin
            csr_dmw1_plv0 <= csr_wmask[`CSR_DMW1_PLV0]&csr_wvalue[`CSR_DMW1_PLV0]
                          | ~csr_wmask[`CSR_DMW1_PLV0]&csr_dmw1_plv0;
            csr_dmw1_plv3 <= csr_wmask[`CSR_DMW1_PLV3]&csr_wvalue[`CSR_DMW1_PLV3]
                          | ~csr_wmask[`CSR_DMW1_PLV3]&csr_dmw1_plv3;
            csr_dmw1_mat <= csr_wmask[`CSR_DMW1_MAT]&csr_wvalue[`CSR_DMW1_MAT]
                         | ~csr_wmask[`CSR_DMW1_MAT]&csr_dmw1_mat;
            csr_dmw1_pseg <= csr_wmask[`CSR_DMW1_PSEG]&csr_wvalue[`CSR_DMW1_PSEG]
                          | ~csr_wmask[`CSR_DMW1_PSEG]&csr_dmw1_pseg;
            csr_dmw1_vseg <= csr_wmask[`CSR_DMW1_VSEG]&csr_wvalue[`CSR_DMW1_VSEG]
                          | ~csr_wmask[`CSR_DMW1_VSEG]&csr_dmw1_vseg;
        end
    end


    /*------定时器相关控制状态寄存器------*/

    /***TID registers***/
    reg [31:0] csr_tid_tid;
    always @(posedge clk) begin
        if (reset)
            csr_tid_tid <= coreid_in;
        else if (csr_we && csr_num==`CSR_TID)
            csr_tid_tid <= csr_wmask[`CSR_TID_TID]&csr_wvalue[`CSR_TID_TID]
                        | ~csr_wmask[`CSR_TID_TID]&csr_tid_tid;
    end

    /***TCFG registers***/
    reg csr_tcfg_en;
    reg csr_tcfg_periodic;
    reg [29:0] csr_tcfg_initval;

    always @(posedge clk) begin
        if (reset)
            csr_tcfg_en <= 1'b0;
        else if (csr_we && csr_num==`CSR_TCFG)
            csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN]&csr_wvalue[`CSR_TCFG_EN]
                        | ~csr_wmask[`CSR_TCFG_EN]&csr_tcfg_en;

        if (csr_we && csr_num==`CSR_TCFG) begin
            csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIOD]&csr_wvalue[`CSR_TCFG_PERIOD]
                              | ~csr_wmask[`CSR_TCFG_PERIOD]&csr_tcfg_periodic;
            csr_tcfg_initval <= csr_wmask[`CSR_TCFG_INITV]&csr_wvalue[`CSR_TCFG_INITV]
                             | ~csr_wmask[`CSR_TCFG_INITV]&csr_tcfg_initval;
        end
    end

    /***TVAL registers***/
    wire [31:0] tcfg_next_value;
    wire [31:0] csr_tval;
    reg [31:0] timer_cnt;

    assign tcfg_next_value = csr_wmask[31:0]&csr_wvalue[31:0]
           | ~csr_wmask[31:0]&{csr_tcfg_initval,
                               csr_tcfg_periodic, csr_tcfg_en};

    always @(posedge clk) begin
        if (reset)
            timer_cnt <= 32'hffffffff;
        else if (csr_we && csr_num==`CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
            timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITV],2'b0};
        else if (csr_tcfg_en && timer_cnt!=32'hffffffff) begin
            if (timer_cnt[31:0]==32'b0 && csr_tcfg_periodic)
                timer_cnt <= {csr_tcfg_initval, 2'b0};
            else
                timer_cnt <= timer_cnt - 1'b1;
        end
    end

    assign csr_tval = timer_cnt[31:0];

    /***TICLR 定时中断清除***/
    wire csr_ticlr_clr;

    assign csr_ticlr_clr = 1'b0;

    /*------CSR读出逻辑------*/
    wire [31:0] csr_crmd_rvalue = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
    wire [31:0] csr_prmd_rvalue = {29'b0, csr_prmd_pie, csr_prmd_pplv};
    wire [31:0] csr_ecfg_rvalue = {19'b0, csr_ecfg_lie};
    wire [31:0] csr_estat_rvalue = {1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};
    wire [31:0] csr_era_rvalue = csr_era_pc;
    wire [31:0] csr_badv_rvalue = csr_badv_vaddr;
    wire [31:0] csr_eentry_rvalue = {csr_eentry_va, 6'b0};
    wire [31:0] csr_save0_rvalue = csr_save0_data;
    wire [31:0] csr_save1_rvalue = csr_save1_data;
    wire [31:0] csr_save2_rvalue = csr_save2_data;
    wire [31:0] csr_save3_rvalue = csr_save3_data;
    wire [31:0] csr_tid_rvalue = csr_tid_tid;
    wire [31:0] csr_tcfg_rvalue = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
    wire [31:0] csr_tval_rvalue = csr_tval;
    wire [31:0] csr_ticlr_rvalue = {32'b0};
    wire [31:0] csr_tlbidx_rvalue = {csr_tlbidx_ne,1'b0,csr_tlbidx_ps,8'b0,csr_tlbidx_index};
    wire [31:0] csr_tlbehi_rvalue = {csr_tlbehi_vppn,13'b0};
    wire [31:0] csr_tlbelo0_rvalue = {4'b0,csr_tlbelo0_ppn,1'b0,csr_tlbelo0_g,csr_tlbelo0_mat,csr_tlbelo0_plv,csr_tlbelo0_d,csr_tlbelo0_v};
    wire [31:0] csr_tlbelo1_rvalue = {4'b0,csr_tlbelo1_ppn,1'b0,csr_tlbelo1_g,csr_tlbelo1_mat,csr_tlbelo1_plv,csr_tlbelo1_d,csr_tlbelo1_v};
    wire [31:0] csr_asid_rvalue = {8'b0,csr_asid_asidbits,6'b0,csr_asid_asid};
    wire [31:0] csr_pgdl_rvalue = {csr_pgdl_base,12'b0};
    wire [31:0] csr_pgdh_rvalue = {csr_pgdh_base,12'b0};
    wire [31:0] csr_pgd_rvalue = csr_badv_vaddr[31] ? csr_pgdh_rvalue : csr_pgdl_rvalue;
    wire [31:0] csr_tlbrentry_rvalue = {csr_tlbrentry_pa,6'b0};
    wire [31:0] csr_dmw0_rvalue = {csr_dmw0_vseg,1'b0,csr_dmw0_pseg,19'b0,csr_dmw0_mat,csr_dmw0_plv3,2'b0,csr_dmw0_plv0};
    wire [31:0] csr_dmw1_rvalue = {csr_dmw1_vseg,1'b0,csr_dmw1_pseg,19'b0,csr_dmw1_mat,csr_dmw1_plv3,2'b0,csr_dmw1_plv0};

    assign csr_rvalue = {32{csr_num==`CSR_CRMD}} & csr_crmd_rvalue
           | {32{csr_num==`CSR_PRMD}} & csr_prmd_rvalue
           | {32{csr_num==`CSR_ECFG}} & csr_ecfg_rvalue
           | {32{csr_num==`CSR_ESTAT}} & csr_estat_rvalue
           | {32{csr_num==`CSR_ERA}} & csr_era_rvalue
           | {32{csr_num==`CSR_BADV}} & csr_badv_rvalue
           | {32{csr_num==`CSR_EENTRY}} & csr_eentry_rvalue
           | {32{csr_num==`CSR_SAVE0}} & csr_save0_rvalue
           | {32{csr_num==`CSR_SAVE1}} & csr_save1_rvalue
           | {32{csr_num==`CSR_SAVE2}} & csr_save2_rvalue
           | {32{csr_num==`CSR_SAVE3}} & csr_save3_rvalue
           | {32{csr_num==`CSR_TID}} & csr_tid_rvalue
           | {32{csr_num==`CSR_TCFG}} & csr_tcfg_rvalue
           | {32{csr_num==`CSR_TVAL}} & csr_tval_rvalue
           | {32{csr_num==`CSR_TICLR}} & csr_ticlr_rvalue
           | {32{csr_num==`CSR_TLBIDX}} & csr_tlbidx_rvalue
           | {32{csr_num==`CSR_TLBEHI}} & csr_tlbehi_rvalue
           | {32{csr_num==`CSR_TLBELO0}} & csr_tlbelo0_rvalue
           | {32{csr_num==`CSR_TLBELO1}} & csr_tlbelo1_rvalue
           | {32{csr_num==`CSR_ASID}} & csr_asid_rvalue
           | {32{csr_num==`CSR_PGDL}} & csr_pgdl_rvalue
           | {32{csr_num==`CSR_PGDH}} & csr_pgdh_rvalue
           | {32{csr_num==`CSR_PGD}} & csr_pgd_rvalue
           | {32{csr_num==`CSR_TLBRENTRY}} & csr_tlbrentry_rvalue
           | {32{csr_num==`CSR_DMW0}} & csr_dmw0_rvalue
           | {32{csr_num==`CSR_DMW1}} & csr_dmw1_rvalue;

endmodule
