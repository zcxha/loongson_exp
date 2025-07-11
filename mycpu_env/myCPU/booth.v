module booth(
	input wire y2,
	input wire y1,
	input wire y0,
	input wire [65:0] X,
	output wire [65:0] P, // 表示66位部分积
	output wire c // 表示求和时对部分积取反再加一
);


wire S_negX;
wire S_posX;
wire S_neg2X;
wire S_pos2X;

assign S_negX = ~(~ (y2&y1&~y0)& ~(y2&~y1&y0));
assign S_posX = ~(~ (~y2&y1&~y0)& ~(~y2&~y1&y0));
assign S_neg2X= ~(~ (y2&~y1&~y0));
assign S_pos2X= ~(~ (~y2&y1&y0));

assign P = {66{S_negX}} & ((~X)+1) |
			{66{S_posX}} & X |
			{66{S_neg2X}} & (((~X) + 1) << 1) | 
			{66{S_pos2X}} & (X << 1);

assign c = S_negX | S_neg2X;

endmodule