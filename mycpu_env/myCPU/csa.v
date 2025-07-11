module csa#(
	parameter n = 15 // 全加器阵列。n为输入个数
)
(
	input wire [n-1:0] column_bits,
	output wire[n/3-1:0] sum_out,
	output wire[n/3-1:0] carry_out
);
	genvar i;
	generate
		for(i = 0; i < n/3; i = i + 1) begin : csa_loop
			adder u_adder(
				.A    	(column_bits[3*i+2]     ),
				.B    	(column_bits[3*i+1]     ),
				.Cin  	(column_bits[3*i]   ),
				.S    	(sum_out[i]     ),
				.Cout 	(carry_out[i]  )
			);
		end
	endgenerate

endmodule