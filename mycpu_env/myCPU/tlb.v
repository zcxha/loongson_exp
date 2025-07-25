module tlb #(
        parameter TLBNUM = 16  // TLB项数量
    ) (
        input wire clk,

        // Search Port 0 (for fetch)
        input  wire [18:0] s0_vppn,
        input  wire        s0_va_bit12, // 指的取0还是1页表项
        input  wire [9:0]  s0_asid,
        output wire        s0_found,
        output wire [$clog2(TLBNUM)-1:0] s0_index,
        output wire [19:0] s0_ppn,
        output wire [5:0]  s0_ps,
        output wire [1:0]  s0_plv,
        output wire [1:0]  s0_mat,
        output wire        s0_d,
        output wire        s0_v,

        // Search Port 1 (for load/store)
        input  wire [18:0] s1_vppn,
        input  wire        s1_va_bit12,
        input  wire [9:0]  s1_asid,
        output wire        s1_found,
        output wire [$clog2(TLBNUM)-1:0] s1_index,
        output wire [19:0] s1_ppn,
        output wire [5:0]  s1_ps,
        output wire [1:0]  s1_plv,
        output wire [1:0]  s1_mat,
        output wire        s1_d,
        output wire        s1_v,

        // Invalidation Interface
        input wire         invtlb_valid,
        input wire [4:0]   invtlb_op,

        // Write Port
        input wire                         we,
        input wire [$clog2(TLBNUM)-1:0]    w_index,
        input wire                         w_e,
        input wire [18:0]                  w_vppn,
        input wire [5:0]                   w_ps,
        input wire [9:0]                   w_asid,
        input wire                         w_g,
        input wire [19:0]                  w_ppn0,
        input wire [1:0]                   w_plv0,
        input wire [1:0]                   w_mat0,
        input wire                         w_d0,
        input wire                         w_v0,
        input wire [19:0]                  w_ppn1,
        input wire [1:0]                   w_plv1,
        input wire [1:0]                   w_mat1,
        input wire                         w_d1,
        input wire                         w_v1,

        // Read Port
        input  wire [$clog2(TLBNUM)-1:0]   r_index,
        output wire                        r_e,
        output wire [18:0]                 r_vppn,
        output wire [5:0]                  r_ps,
        output wire [9:0]                  r_asid,
        output wire                        r_g,
        output wire [19:0]                 r_ppn0,
        output wire [1:0]                  r_plv0,
        output wire [1:0]                  r_mat0,
        output wire                        r_d0,
        output wire                        r_v0,
        output wire [19:0]                 r_ppn1,
        output wire [1:0]                  r_plv1,
        output wire [1:0]                  r_mat1,
        output wire                        r_d1,
        output wire                        r_v1
    );

    // TLB Entry Storage Arrays
    reg [TLBNUM-1:0]               tlb_e;       // Entry valid bit
    reg [TLBNUM-1:0]               tlb_ps4MB;   // Page size: 1=4MB, 0=4KB
    reg [18:0]                     tlb_vppn   [TLBNUM-1:0];  // Virtual PPage Number
    reg [9:0]                      tlb_asid   [TLBNUM-1:0];  // Address Space ID
    reg                            tlb_g      [TLBNUM-1:0];  // Global bit
    reg [19:0]                     tlb_ppn0   [TLBNUM-1:0];  // Physical Page Number 0
    reg [1:0]                      tlb_plv0   [TLBNUM-1:0];  // Privilege Level 0
    reg [1:0]                      tlb_mat0   [TLBNUM-1:0];  // Memory Access Type 0
    reg                            tlb_d0     [TLBNUM-1:0];  // Dirty bit 0
    reg                            tlb_v0     [TLBNUM-1:0];  // Valid bit 0
    reg [19:0]                     tlb_ppn1   [TLBNUM-1:0];  // Physical Page Number 1
    reg [1:0]                      tlb_plv1   [TLBNUM-1:0];  // Privilege Level 1
    reg [1:0]                      tlb_mat1   [TLBNUM-1:0];  // Memory Access Type 1
    reg                            tlb_d1     [TLBNUM-1:0];  // Dirty bit 1
    reg                            tlb_v1     [TLBNUM-1:0];  // Valid bit 1

    always @(posedge clk) begin
        if (we) begin
            tlb_e[w_index] <= w_e;
            tlb_vppn[w_index] <= w_vppn;
            tlb_ps4MB[w_index] <= (w_ps==6'd21 ? 1 : 0);
            tlb_asid[w_index] <= w_asid;
            tlb_g[w_index] <= w_g;
            tlb_ppn0[w_index] <= w_ppn0;
            tlb_plv0[w_index] <= w_plv0;
            tlb_mat0[w_index] <= w_mat0;
            tlb_d0[w_index] <= w_d0;
            tlb_v0[w_index] <= w_v0;
            tlb_ppn1[w_index] <= w_ppn1;
            tlb_plv1[w_index] <= w_plv1;
            tlb_mat1[w_index] <= w_mat1;
            tlb_d1[w_index] <= w_d1;
            tlb_v1[w_index] <= w_v1;
        end
    end

    assign r_e = tlb_e[r_index];
    assign r_vppn = tlb_vppn[r_index];
    assign r_ps = tlb_ps4MB[r_index] ? 6'd21 : 6'd12;
    assign r_asid = tlb_asid[r_index];
    assign r_g = tlb_g[r_index];
    assign r_ppn0 = tlb_ppn0[r_index];
    assign r_plv0 = tlb_plv0[r_index];
    assign r_mat0 = tlb_mat0[r_index];
    assign r_d0 = tlb_d0[r_index];
    assign r_v0 = tlb_v0[r_index];
    assign r_ppn1 = tlb_ppn1[r_index];
    assign r_plv1 = tlb_plv1[r_index];
    assign r_mat1 = tlb_mat1[r_index];
    assign r_d1 = tlb_d1[r_index];
    assign r_v1 = tlb_v1[r_index];

	wire s0_va_bit; // bit21/bit12
	wire s1_va_bit;


    wire [TLBNUM-1:0] match0;
    wire [TLBNUM-1:0] match1;
    genvar i;
    generate
        for (i = 0; i < TLBNUM; i = i + 1) begin: match_gen
            assign match0[i] = (s0_vppn[18:9]==tlb_vppn[i][18:9])
                   && (tlb_ps4MB[i] || (s0_vppn[8:0]==tlb_vppn[i][8:0]))
                   && ((tlb_asid[i]==s0_asid) || tlb_g[i]) && tlb_e[i];
            assign match1[i] = (s1_vppn[18:9]==tlb_vppn[i][18:9])
                   && (tlb_ps4MB[i] || (s1_vppn[8:0]==tlb_vppn[i][8:0]))
                   && ((tlb_asid[i]==s1_asid) || tlb_g[i]) && tlb_e[i];
        end
    endgenerate
    assign s0_found = |match0;
    // TODO:这里先设置成16位
    assign s0_index = ({4{match0[4'd0]}} & 4'd0)
           | ({4{match0[4'd1]}} & 4'd1)
           | ({4{match0[4'd2]}} & 4'd2)
           | ({4{match0[4'd3]}} & 4'd3)
           | ({4{match0[4'd4]}} & 4'd4)
           | ({4{match0[4'd5]}} & 4'd5)
           | ({4{match0[4'd6]}} & 4'd6)
           | ({4{match0[4'd7]}} & 4'd7)
           | ({4{match0[4'd8]}} & 4'd8)
           | ({4{match0[4'd9]}} & 4'd9)
           | ({4{match0[4'd10]}} & 4'd10)
           | ({4{match0[4'd11]}} & 4'd11)
           | ({4{match0[4'd12]}} & 4'd12)
           | ({4{match0[4'd13]}} & 4'd13)
           | ({4{match0[4'd14]}} & 4'd14)
           | ({4{match0[4'd15]}} & 4'd15)
           ;
	assign s0_va_bit = tlb_ps4MB[s0_index] ? s0_vppn[8] : s0_va_bit12;
    assign s0_ps  = (tlb_ps4MB[s0_index] ? 6'd21 : 6'd12);
    assign s0_ppn = s0_va_bit ? tlb_ppn1[s0_index] : tlb_ppn0[s0_index];
    assign s0_plv = s0_va_bit ? tlb_plv1[s0_index] : tlb_plv0[s0_index];
    assign s0_mat = s0_va_bit ? tlb_mat1[s0_index] : tlb_mat0[s0_index];
    assign s0_d   = s0_va_bit ? tlb_d1[s0_index] : tlb_d0[s0_index];
    assign s0_v   = s0_va_bit ? tlb_v1[s0_index] : tlb_v0[s0_index];

    assign s1_found = |match1;
    // TODO:这里先设置成16位
    assign s1_index = ({4{match1[4'd0]}} & 4'd0)
           | ({4{match1[4'd1]}} & 4'd1)
           | ({4{match1[4'd2]}} & 4'd2)
           | ({4{match1[4'd3]}} & 4'd3)
           | ({4{match1[4'd4]}} & 4'd4)
           | ({4{match1[4'd5]}} & 4'd5)
           | ({4{match1[4'd6]}} & 4'd6)
           | ({4{match1[4'd7]}} & 4'd7)
           | ({4{match1[4'd8]}} & 4'd8)
           | ({4{match1[4'd9]}} & 4'd9)
           | ({4{match1[4'd10]}} & 4'd10)
           | ({4{match1[4'd11]}} & 4'd11)
           | ({4{match1[4'd12]}} & 4'd12)
           | ({4{match1[4'd13]}} & 4'd13)
           | ({4{match1[4'd14]}} & 4'd14)
           | ({4{match1[4'd15]}} & 4'd15)
           ;
	assign s1_va_bit = tlb_ps4MB[s1_index] ? s1_vppn[8] : s1_va_bit12;
    assign s1_ps  = (tlb_ps4MB[s1_index] ? 6'd21 : 6'd12);
    assign s1_ppn = s1_va_bit ? tlb_ppn1[s1_index] : tlb_ppn0[s1_index];
    assign s1_plv = s1_va_bit ? tlb_plv1[s1_index] : tlb_plv0[s1_index];
    assign s1_mat = s1_va_bit ? tlb_mat1[s1_index] : tlb_mat0[s1_index];
    assign s1_d   = s1_va_bit ? tlb_d1[s1_index] : tlb_d0[s1_index];
    assign s1_v   = s1_va_bit ? tlb_v1[s1_index] : tlb_v0[s1_index];

    wire [TLBNUM-1:0] inv_match;
    wire [TLBNUM-1:0] cond1; // G域是否为0
    wire [TLBNUM-1:0] cond2; // G域是否为1
    wire [TLBNUM-1:0] cond3; // s1_asid是否等于ASID域
    wire [TLBNUM-1:0] cond4; // s1_vppn是否匹配VPPN和PS域

    genvar iinv;
    generate
        for (i = 0; i < TLBNUM; i = i + 1) begin: inv_match_gen
            assign cond1[i] = tlb_g[i]==0;
            assign cond2[i] = tlb_g[i]==1;
            assign cond3[i] = s1_asid==tlb_asid[i];
            assign cond4[i] = s1_vppn[18:9]==tlb_vppn[i][18:9]
                   && (tlb_ps4MB[i] || s1_vppn[8:0]==tlb_vppn[i][8:0]);
            assign inv_match[i] = (invtlb_op==5'h0)
                   || (invtlb_op==5'h1)
                   || (invtlb_op==5'h2) && cond2[i]
                   || (invtlb_op==5'h3) && cond1[i]
                   || (invtlb_op==5'h4) && cond1[i] && cond3[i]
                   || (invtlb_op==5'h5) && cond1[i] && cond3[i] && cond4[i]
                   || (invtlb_op==5'h6) && (cond2[i] || cond3[i]) && cond4[i];
        end
    endgenerate

    always @(posedge clk) begin
        if (invtlb_valid) begin
            tlb_e <= ~inv_match & tlb_e;
        end
    end

endmodule
