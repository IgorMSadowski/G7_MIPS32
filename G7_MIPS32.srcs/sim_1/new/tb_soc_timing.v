`timescale 1ns / 1ps

module tb_soc_timing;
    reg clk = 1'b0;
    reg rst = 1'b1;
    wire [3:0] leds;
    integer errors = 0;

    always #4 clk = ~clk; // 125 MHz at K17

    soc dut (
        .i_clk(clk),
        .i_rst(rst),
        .i_sw(4'b1010),
        .i_btn(3'b101),
        .o_led(leds)
    );

    initial begin
        // Allow FPGA global reset to finish before releasing the board reset.
        repeat (16) @(negedge clk);
        if (leds !== 4'b0001) begin
            errors = errors + 1;
            $display("FAIL: expected reset LED pattern 0001, got %b", leds);
        end
        rst = 1'b0;

        // Observe the write at a port and allow time for the MMCM to lock.
        begin : wait_for_leds
            repeat (2500) begin
                @(negedge clk);
                if (leds === 4'b1010) begin
                    $display("OBSERVED: MMIO LED pattern 1010 at %0t", $time);
                    disable wait_for_leds;
                end
            end
        end
        if (leds !== 4'b1010) begin
            errors = errors + 1;
            $display("FAIL: expected MMIO LED pattern 1010, got %b", leds);
        end

        repeat (25) @(negedge clk);
        if (leds !== 4'b1010) begin
            errors = errors + 1;
            $display("FAIL: LED pattern did not hold, got %b", leds);
        end
        if (errors == 0)
            $display("PASS: SoC MMIO with Clocking Wizard, LEDs = %b", leds);
        $finish;
    end
endmodule
