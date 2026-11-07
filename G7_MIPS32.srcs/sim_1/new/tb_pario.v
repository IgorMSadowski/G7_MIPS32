`timescale 1ns / 1ps

module tb_pario;
    reg clk = 0;
    reg rst = 1;
    reg write_enable = 0;
    reg [7:0] pins = 0;
    reg [31:0] write_data = 0;
    wire [31:0] read_data;
    wire [2:0] led;
    reg [8*24-1:0] test_name;
    reg [8*16-1:0] pario_phase;
    integer errors = 0;
    integer checks = 0;

    always #5 clk = ~clk;

    pario dut(
        .i_clk(clk), .i_rst(rst),
        .i_write_enable(write_enable), .i_pins(pins),
        .i_write_data(write_data), .o_read_data(read_data), .o_led(led)
    );

    task check(input condition, input [8*56-1:0] name);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                $display("FAIL %0s", name);
                errors = errors + 1;
            end
        end
    endtask

    initial begin

        test_name = "PARIO RESET AND LED OUTPUT";
        pario_phase = "RESET";
        repeat (2) @(posedge clk);
        #1;
        check(led === 3'b000, "reset clears LED output");

        pario_phase = "WRITE LED";
        @(negedge clk);
        rst = 0;
        write_enable = 1;
        write_data = 32'h0000_00FD;
        @(posedge clk);
        #1;
        check(led === 3'b101, "write uses only the three low bits");

        pario_phase = "READ PINS";
        @(negedge clk);
        write_enable = 0;
        write_data = 32'h0000_0002;
        pins = 8'h5A;
        #1;
        check(read_data === 32'h0000_005A, "read data zero-extends the pins");
        @(posedge clk);
        #1;
        check(led === 3'b101, "LED output holds without a write");

        if (errors == 0) $display("PASS: %0d PARIO checks", checks);
        else $display("FAILED: %0d of %0d PARIO checks", errors, checks);
        $finish;
    end
endmodule
