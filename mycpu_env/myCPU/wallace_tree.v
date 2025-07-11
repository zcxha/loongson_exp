module wallace_tree(
	input wire [16:0] column_bits,
	input wire [13:0] cin,
	output wire [13:0] cout,
	output wire sum_final,
	output wire c_final
);
	wire s_01;
	wire c_01;
	adder u_add_01 (
		.A(column_bits[2]),
		.B(column_bits[3]),
		.Cin(column_bits[4]),
		.S(s_01),
		.Cout(c_01)
	);
	wire s_02;
	wire c_02;
	adder u_add_02 (
		.A(column_bits[5]),
		.B(column_bits[6]),
		.Cin(column_bits[7]),
		.S(s_02),
		.Cout(c_02)
	);
	wire s_03;
	wire c_03;
	adder u_add_03 (
		.A(column_bits[8]),
		.B(column_bits[9]),
		.Cin(column_bits[10]),
		.S(s_03),
		.Cout(c_03)
	);
	wire s_04;
	wire c_04;
	adder u_add_04 (
		.A(column_bits[11]),
		.B(column_bits[12]),
		.Cin(column_bits[13]),
		.S(s_04),
		.Cout(c_04)
	);
	wire s_05;
	wire c_05;
	adder u_add_05 (
		.A(column_bits[14]),
		.B(column_bits[15]),
		.Cin(column_bits[16]),
		.S(s_05),
		.Cout(c_05)
	);

	wire s_11;
	wire c_11;
	adder u_add_11 (
		.A(column_bits[0]),
		.B(column_bits[1]),
		.Cin(cin[0]),
		.S(s_11),
		.Cout(c_11)
	);
	wire s_12;
	wire c_12;
	adder u_add_12 (
		.A(cin[1]),
		.B(cin[2]),
		.Cin(cin[3]),
		.S(s_12),
		.Cout(c_12)
	);
	wire s_13;
	wire c_13;
	adder u_add_13 (
		.A(cin[4]),
		.B(s_01),
		.Cin(s_02),
		.S(s_13),
		.Cout(c_13)
	);
	wire s_14;
	wire c_14;
	adder u_add_14 (
		.A(s_03),
		.B(s_04),
		.Cin(s_05),
		.S(s_14),
		.Cout(c_14)
	);

	wire s_21;
	wire c_21;
	adder u_add_21 (
		.A(cin[5]),
		.B(cin[6]),
		.Cin(s_11),
		.S(s_21),
		.Cout(c_21)
	);
	wire s_22;
	wire c_22;
	adder u_add_22 (
		.A(s_12),
		.B(s_13),
		.Cin(s_14),
		.S(s_22),
		.Cout(c_22)
	);

	wire s_31;
	wire c_31;
	adder u_add_31 (
		.A(cin[7]),
		.B(cin[8]),
		.Cin(cin[9]),
		.S(s_31),
		.Cout(c_31)
	);
	wire s_32;
	wire c_32;
	adder u_add_32 (
		.A(cin[10]),
		.B(s_21),
		.Cin(s_22),
		.S(s_32),
		.Cout(c_32)
	);

	wire s_41;
	wire c_41;
	adder u_add_41 (
		.A(cin[11]),
		.B(s_31),
		.Cin(s_32),
		.S(s_41),
		.Cout(c_41)
	);

	wire s_51;
	wire c_51;
	adder u_add_51 (
		.A(cin[12]),
		.B(cin[13]),
		.Cin(s_41),
		.S(s_51),
		.Cout(c_51)
	);
	assign cout = {c_41,c_32,c_31,c_22,c_21,c_14,c_13,c_12,c_11,c_05,c_04,c_03,c_02,c_01};
	assign sum_final = s_51;
	assign c_final = c_51;

endmodule