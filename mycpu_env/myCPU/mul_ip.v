module mul_ip(
	input wire mul_hres,
	input wire mul_signed,
	input wire [31:0] x,
	input wire [31:0] y,
	output wire [31:0] result
);
	wire [32:0] src1;
	wire [32:0] src2;

	assign src1 = {mul_signed & x[31],x};
	assign src2 = {mul_signed & y[31],y};

	wire [65:0] signed_result;

	assign signed_result = $signed(src1) * $signed(src2);

	assign result = mul_hres ? signed_result[63:32] : signed_result[31:0];
endmodule