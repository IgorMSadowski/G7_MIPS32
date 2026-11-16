`timescale 1ns / 1ps

module tb_soc;

    reg        clk;
    reg        rst;
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

        // Allow Clock Wizard startup and execution of the ROM program.
        repeat (600) @(posedge clk);

        $finish;
    end

endmodule
