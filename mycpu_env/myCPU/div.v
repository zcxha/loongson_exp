module div(
	input wire div_clk,
	input wire resetn, // 复位信号，低电平有效
	input wire div, // 除法开启标志
	input wire div_signed, // 控制符号
	input wire [31:0] x, // 被除数
	input wire [31:0] y, // 除数
	output wire [31:0] s, // 除法结果，商
	output wire [31:0] r, // 除法结果，余数
	output wire complete // 除法完成信号，除法内部count计算达到33
)