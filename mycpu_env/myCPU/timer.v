module timer(
        input wire clk,
        input wire reset,
        input wire timer_op, // 1取高32位
        output wire [31:0] rvalue
    );
    reg [63:0] timer_cnt;

    always @(posedge clk) begin
        if (reset)
            timer_cnt <= 64'h0;
        else if (timer_cnt == 64'hffffffff_ffffffff)
            timer_cnt <= 64'h0;
        else
            timer_cnt <= timer_cnt + 1;
    end
    assign rvalue = {32{timer_op}} & timer_cnt[63:32]
           | {32{~timer_op}} & timer_cnt[31:0];
endmodule
