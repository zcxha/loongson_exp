module mul(
        input wire mul_clk,
        input wire resetn, // 复位信号，低电平有效
        input wire mul_signed,
        input wire [31:0] x,
        input wire [31:0] y,
        output wire [63:0] result
    );

    wire [65:0] src1;
    wire [32:0] src2;

    assign src1 = mul_signed ? {{34{x[31]}}, x} : {34'b0, x}; // 被乘数
    assign src2 = mul_signed ? {y[31],y} : {1'b0,y};


    // **part1:gen partial product**
    wire [65:0] partial_products [16:0];

    genvar i;
    generate
        for (i = 0; i < 17; i = i + 1) begin : booth_gen
            // output declaration of module booth
            wire [65:0] P;
            wire c;
            wire y2;
            wire y1;
            wire y0;
            wire[65:0] X;
            wire [65:0] P_signed;

            assign X = src1;
            assign y2 = (2*i + 1 <= 32) ? src2[2 * i + 1] : (mul_signed & y[31]);
            assign y1 = src2[2 * i];
            assign y0 = 2 * i > 1 ? src2[2 * i - 1] : 1'b0;

            booth u_booth(
                      .y2 	(y2  ),
                      .y1 	(y1  ),
                      .y0 	(y0  ),
                      .X  	(X   ),
                      .P  	(P   ),
                      .c  	(c   )
                  );
            assign P_signed = P;
            assign partial_products[i] = P_signed << (2*i);
        end
    endgenerate

    wire [65:0] result_part1;
    assign result_part1 = partial_products[0] + partial_products[1] + partial_products[2] + partial_products[3] +
           partial_products[4] + partial_products[5] + partial_products[6] + partial_products[7] +
           partial_products[8] + partial_products[9] + partial_products[10] + partial_products[11] +
           partial_products[12] + partial_products[13] + partial_products[14] + partial_products[15] + partial_products[16];

    //**part2 transpose
    wire [16:0] wallace_input [65:0];
    genvar i2,j;
    generate
        for (j = 0; j < 66; j = j + 1) begin : col_loop
            for(i2 = 0; i2 < 17; i2 = i2 + 1) begin : row_loop
                assign wallace_input[j][i2] = partial_products[i2][j]; // 第一行为LSB 即原来数字的最右边 即partial[i][0] 即最低位，所以从第一行开始累加进位
            end
        end
    endgenerate

    // reg [16:0] wallace_input_reg [65:0];
    // integer i_0;
    // always @(posedge mul_clk or negedge resetn) begin
    //     if (!resetn) begin
    //         for (i_0 = 0; i_0 < 66; i_0 = i_0 + 1) begin
    //             wallace_input_reg[i_0] <= 17'b0;
    //         end
    //     end
    //     else begin
    //         for (i_0 = 0; i_0 < 66; i_0 = i_0 + 1) begin
    //             wallace_input_reg[i_0] <= wallace_input[i_0];
    //         end
    //     end
    // end


    //**part3 Wallace tree
    wire [13:0] carry [66:0]; // 存传递的C
    wire [13:0] sum   [66:0];
    wire [65:0] carry_out;// 存输出的
    wire [65:0] sum_out;
    assign carry[0] = 14'b0;
    genvar i3;
    generate
        for(i3 = 0; i3 <= 32; i3 = i3 + 1) begin : wallace_loop //因为低位在63开始
            // input: wallace_input[i]
            // input: carry[i]
            // output: carry[i+1]
            // output: sum[i]
            // output declaration of module wallace_tree
            wallace_tree u_wallace_tree(
                             .column_bits 	(wallace_input[i3]  ),
                             .cin         	(carry[i3]          ),
                             .cout        	(carry[i3+1]         ),
                             .sum_final   	(sum_out[i3]    ),
                             .c_final     	(carry_out[i3]      )
                         );
        end
    endgenerate

	reg [16:0] pl_wallace_input [65:0];
	reg [13:0] pl_carry; // 流水段1最后一层carry结果
	reg [32:0] pl_carry_out; // 流水段1的carry out 结果
	reg [32:0] pl_sum_out; // 流水段1的sum out结果
	integer i_0;

	always @(posedge mul_clk) begin
		if (~resetn) begin
			for (i_0 = 0; i_0 < 66; i_0 = i_0 + 1) begin
				pl_wallace_input[i_0] <=17'b0;
			end
			pl_carry <= 14'b0;
			pl_carry_out <= 66'b0;
			pl_sum_out <= 66'b0;
		end
		else begin
			for (i_0 = 0; i_0 < 66; i_0 = i_0 + 1) begin
				pl_wallace_input[i_0] <= wallace_input[i_0];
			end
			pl_carry <= carry[33];
			pl_carry_out <= carry_out[32:0];
			pl_sum_out <= sum_out[32:0];
		end
	end
	// ***流水段2***
	wire [13:0] pl2_carry [66:0];
	wire [65:0] pl2_sum_out;
	wire [65:0] pl2_carry_out;
	assign pl2_carry[33] = pl_carry;
	assign pl2_sum_out[32:0] = pl_sum_out;
	assign pl2_carry_out[32:0] = pl_carry_out;

    genvar pl_i3;
    generate
        for (pl_i3 = 33; pl_i3 <= 65; pl_i3 = pl_i3 + 1) begin : pl_wallace
            wallace_tree u_wallace_tree(
                             .column_bits 	(pl_wallace_input[pl_i3]  ),
                             .cin         	(pl2_carry[pl_i3]          ),
                             .cout        	(pl2_carry[pl_i3+1]         ),
                             .sum_final   	(pl2_sum_out[pl_i3]    ),
                             .c_final     	(pl2_carry_out[pl_i3]      )
                         );
        end
    endgenerate

    wire [65:0] addsrc1;
    wire [65:0] addsrc2;

    assign addsrc1 = pl2_sum_out;
    assign addsrc2 = pl2_carry_out << 1;

    wire [65:0] result_full;
    assign result_full = addsrc1 + addsrc2;
    assign result = result_full[63:0];

endmodule
