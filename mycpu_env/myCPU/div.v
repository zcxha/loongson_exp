module div(
        input wire div_clk,
        input wire resetn, // 复位信号，低电平有效
        input wire div, // 除法开启标志
        input wire div_signed, // 控制符号
        input wire [31:0] x, // 被除数
        input wire [31:0] y, // 除数
        output wire [31:0] s, // 除法结果，商
        output wire [31:0] r, // 除法结果，余数
        output reg complete // 除法完成信号，除法内部count计算达到33
    );

    reg [5:0] count; // 迭代计数器

    wire [31:0] src1;
    wire [31:0] src2;
    assign src1 = (div_signed & x[31]) ? ((~x) + 1) : x;
    assign src2 = (div_signed & y[31]) ? ((~y) + 1) : y;

	reg shift_run;

    reg [31:0] y_reg; // 除数寄存器
    reg src1_sign;
    reg src2_sign;

    reg [32:0] try_reg; // 试减
	reg [32:0] init_treg;


    reg [63:0] RQ_reg;
    always @(posedge div_clk) begin
        if (~resetn) begin
            count <= 6'b0;
            complete <= 1'b0;
			shift_run <= 1'b0;
            y_reg <= 32'b0;
            RQ_reg <= 64'b0;
        end
        if (div && !shift_run && !complete) begin
			RQ_reg <= {32'b0,src1};
            y_reg <= src2;
            src1_sign <= div_signed & x[31];
            src2_sign <= div_signed & y[31];
			shift_run <= 1'b1;
			count <= 6'b0;
        end

        if (count == 6'd31) begin
            complete <= 1'b1;
			shift_run <= 1'b0;
		end else begin
			complete <= 1'b0;
		end
    end

    always @(posedge div_clk) begin
        if (~resetn) begin
            try_reg = 33'b0;
        end
        if (div && shift_run && !complete) begin
			count <= count + 1;
            try_reg = RQ_reg[63:31] + (~{1'b0,y_reg[31:0]}) + 1; // 试减

            if (try_reg[32] == 1) begin
                RQ_reg <= RQ_reg << 1;
            end
            else begin
                RQ_reg <= RQ_reg << 1;
                RQ_reg[63:32] <= try_reg[31:0];
                RQ_reg[0] <= 1;
            end
        end
    end

    assign r = (src1_sign && src2_sign) || (src1_sign && !src2_sign) ? (~RQ_reg[63:32]) + 1 :
           RQ_reg[63:32];
    assign s = (src1_sign && !src2_sign) || (!src1_sign && src2_sign) ? (~RQ_reg[31:0]) + 1 :
           RQ_reg[31:0];

endmodule
