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

		output wire [31:0] ertn_pc // 送往取指的ertn返回的指令地址
    );


    /**硬件接口逻辑**/
    assign has_int = ((csr_estat_is[12:0] & csr_ecfg_lie[12:0]) != 13'b0) && (csr_crmd_ie == 1'b1);

    assign ex_entry = wb_ex ? csr_eentry_rvalue : wb_pc;

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
            // TODO: MMU间接地址翻译尚未实现
            csr_crmd_da <= 1'b1;
            csr_crmd_pg <= 1'b0;
            csr_crmd_datf <= 2'b0;
            csr_crmd_datm <= 2'b0;
        end
        else if (wb_ex) begin
            csr_crmd_plv <= 2'b0;
            csr_crmd_ie <= 1'b0;
        end
        else if (ertn_flush) begin
            csr_crmd_plv <= csr_prmd_pplv;
            csr_crmd_ie <= csr_prmd_pie;
        end
        else if (csr_we && csr_num==`CSR_CRMD) begin
            csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV]&csr_wvalue[`CSR_CRMD_PLV]
                         | ~csr_wmask[`CSR_CRMD_PLV]&csr_crmd_plv;
            csr_crmd_ie <= csr_wmask[`CSR_CRMD_IE]&csr_wvalue[`CSR_CRMD_IE]
                        | ~csr_wmask[`CSR_CRMD_IE]&csr_crmd_ie;
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
    assign wb_ex_addr_err = wb_ecode==`ECODE_ADE || wb_ecode==`ECODE_ALE;

    always @(posedge clk) begin
        if (wb_ex && wb_ex_addr_err)
            csr_badv_vaddr <= (wb_ecode==`ECODE_ADE &&
                               wb_esubcode==`ESUBCODE_ADEF) ? wb_pc : wb_vaddr;
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

    /******/


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
           | {32{csr_num==`CSR_TICLR}} & csr_ticlr_rvalue;
endmodule
