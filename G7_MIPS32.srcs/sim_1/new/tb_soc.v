`timescale 1ns / 1ps

// Run soc_test.mem and check the program's writes to RAM byte address 0x000003F8.
module tb_soc;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg [31:0] checkpoint = 0;
    reg [31:0] expected_checkpoint = 1;
    reg [159:0] step;
    integer errors = 0;

    // 125 MHz at the board input. The Clock Wizard generates 50 MHz.
    always #4 clk = ~clk;

    soc dut (
        .i_clk(clk),
        .i_rst(rst),
        .i_sw(2'b00),
        .i_btn1(1'b0),
        .o_led()
    );

    always @(*) begin
        case (checkpoint)
            0: step = "STARTUP             ";
            1: step = "ARITHMETIC PASSED   ";
            2: step = "SHIFTS PASSED       ";
            3: step = "RAM PASSED          ";
            4: step = "BRANCHES PASSED     ";
            5: step = "JUMPS PASSED        ";
            6: step = "PASS                ";
            7: step = "FAIL                ";
            default: step = "UNEXPECTED          ";
        endcase
    end

    // RAM Write is already qualified by the decoder. Word index 0xFE is byte address 0x3F8.
    always @(posedge dut.clk_50mhz) begin
        if (!rst && dut.ram_write === 1'b1 && dut._alu_out[9:2] === 8'hFE) begin
            checkpoint = dut._wdata;
            if (checkpoint !== expected_checkpoint) begin
                $display("FAIL: RAM checkpoint = %h, expected %h", checkpoint, expected_checkpoint);
                errors = errors + 1;
                $finish;
            end
            expected_checkpoint = expected_checkpoint + 1;
        end
    end

    initial begin
        // Keep board reset active through the FPGA's global startup reset.
        repeat (25) @(posedge clk);
        #1;
        rst = 1'b0;

        wait (checkpoint === 32'd6);
        #40;
        $display("PASS: SoC program completed all six RAM checkpoints");
        $finish;
    end

    initial begin
        #20000;
        $display("FAIL: SoC program timed out at RAM checkpoint %h", checkpoint);
        errors = errors + 1;
        $finish;
    end
endmodule
