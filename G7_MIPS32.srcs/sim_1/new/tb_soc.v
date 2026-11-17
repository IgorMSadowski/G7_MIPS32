`timescale 1ns / 1ps

module tb_soc;

    reg clk;
    reg rst;
    wire [0:0] led;

    // Board input: 125 MHz (8 ns period).
    // The Clock Wizard inside soc generates the 50 MHz CPU clock.
    always #4 clk = ~clk;

    soc dut (
        .i_clk(clk),
        .i_rst(rst),
        .o_led(led)
    );

    initial begin
        clk = 1'b0;
        rst = 1'b1;

        // Hold reset for 25 rising edges of the board clock.
        repeat (25) @(posedge clk);
        rst = 1'b0;

        // Wait until the clock is ready and the internal reset is released.
        wait (dut.soc_reset == 1'b0);

        // Observe 50 CPU cycles after startup (50 MHz internal clock).
        repeat (50) @(posedge dut.clk_50mhz);
    // Let the final registered updates settle before finishing.
        #1;

        $finish;
    end

endmodule
