// tb_bram_no_output_register.v
`timescale 1ns/1ps

module tb_bram_no_output_register;

    reg clk;
    reg we;
    reg [3:0] addr;
    reg [31:0] din;
    wire [31:0] dout;

    // Instantiate BRAM
    bram_no_output_register uut (
        .clka(clk),
        .wea(we),
        .addra(addr),
        .dina(din),
        .douta(dout)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk; // 100MHz clock
    integer i;
    // Test process
    initial begin
        $display("Start BRAM test without output register");
        we = 0;
        addr = 0;
        din = 0;
        #10;

        // Write phase
        for (i = 0; i < 8; i=i+1) begin
            @(posedge clk);
            we <= 1;
            addr <= i;
            din <= i * 10;
        end

        @(posedge clk);
        we <= 0;

        // Read phase
        for (i = 0; i < 8; i=i+1) begin
            @(posedge clk);
            addr <= i;
            #1 $display("Read addr=%0d, dout=%0d", addr, dout);  // Note: dout is combinational
        end

        #20;
        $finish;
    end

endmodule
