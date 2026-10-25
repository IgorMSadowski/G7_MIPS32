`timescale 1ns / 1ps

module tb_soc;

    reg         i_clk;
    reg         i_rst;
    wire [0:0] o_led;

    // 50 MHz clock generation:
    // The clock signal toggles every 10ns, resulting in a full clock period of 20ns
    // period = 20 ns  ->  frequency = 1 / 20 ns = 50 MHz
    always #10 i_clk = ~i_clk;

    // DUT (Device Under Test): Instantiation of the SoC module in the testbench
    soc dut (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .o_led(o_led)
    );

    initial begin
        // Start with a known state
        i_clk = 1'b0;
        i_rst = 1'b1;
        

        // Hold reset for a few cycles
        repeat (5) @(posedge i_clk);
        // Reset goes down after 5 clock cycles
        i_rst = 1'b0;

        // Let the CPU run for a while using the instruction memory contents
        repeat (50) @(posedge i_clk);

        $display("Simulation finished.");
        $finish;
    end

endmodule
