module lfsr_random_8bit (
    input  wire clk,
    input  wire resetn,       // 异步复位，低有效
    input  wire enable,       // 有效时更新随机数
    output reg  [7:0] random  // 输出的随机数
);

    wire feedback = random[7] ^ random[5] ^ random[4] ^ random[3];  // x^8 + x^6 + x^5 + x^4 + 1

    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            random <= 8'h1;  // 初始化为非零值
        else if (enable)
            random <= {random[6:0], feedback};
    end

endmodule
