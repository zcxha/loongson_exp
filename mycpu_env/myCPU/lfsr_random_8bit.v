module lfsr_random_8bit (
    input  wire clk,
    input  wire resetn,       // 异步复位，低有效
    input  wire enable,       // 有效时更新随机数
    output reg  [7:0] random1  // 输出的随机数
);

    wire feedback = random1[7] ^ random1[5] ^ random1[4] ^ random1[3];  // x^8 + x^6 + x^5 + x^4 + 1

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            random1 <= 8'h1;  // 初始化为非零值
        else if (enable)
            random1 <= {random1[6:0], feedback};
    end

endmodule
