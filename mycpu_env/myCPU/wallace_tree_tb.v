`timescale 1ns/1ps
module wallace_tree_tb;

    wire [16:0] in;
    wire [13:0] cin;

    assign in = 17'b1_1011_0111_1001_1000;
    assign cin = 14'b0;

    // output declaration of module wallace_tree
    wire [13:0] cout;
    wire sum_final;
    wire c_final;
    
    wallace_tree u_wallace_tree(
        .column_bits    (in          ),
        .cin            (cin         ),
        .cout           (cout        ),
        .sum_final      (sum_final   ),
        .c_final        (c_final     )
    );

    // 添加 initial 块包裹 display
    initial begin
        #10; // 等待一段时间，确保仿真器有时间执行
        $display("cout=%x, sum_final=%b, c_final=%b", cout, sum_final, c_final);
        $finish;
    end

endmodule
