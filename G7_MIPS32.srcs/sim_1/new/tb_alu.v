`timescale 1ns / 1ps

module tb_alu;

    reg  [31:0] a, b;
    reg  [3:0]  ctrl;
    wire [31:0] y;
    wire        zero;

    alu dut(
        .i_a(a), .i_b(b), .i_ctrl(ctrl),
        .o_y(y), .o_zero(zero)
    );

    integer errors = 0;
    integer tests  = 0;

    task check(input [31:0] expected, input [8*24-1:0] name);
        begin
            tests = tests + 1;
            #1;
            if (y !== expected) begin
                $display("FAIL %0s: got %h, expected %h", name, y, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        // ---- AND ----
        a=32'hFF00FF00; b=32'h0FF00FF0; ctrl=4'b0000;
        check(32'h0F000F00, "and mask");

        // ---- OR ----
        a=32'hFF00FF00; b=32'h0FF00FF0; ctrl=4'b0001;
        check(32'hFFFF_FFF0, "or merge");

        // ---- ADD (wraps on overflow, no trap) ----
        a=32'd10; b=32'd20; ctrl=4'b0010;
        check(32'd30, "add 10+20");
        a=32'hFFFFFFFF; b=32'd1; ctrl=4'b0010;
        check(32'h0, "add overflow wraps to 0");

        // ---- SUB ----
        a=32'd20; b=32'd10; ctrl=4'b0110;
        check(32'd10, "sub 20-10");
        a=32'd10; b=32'd20; ctrl=4'b0110;
        check(32'hFFFFFFF6, "sub 10-20 = -10");

        // ---- SLT (signed) ----
        a=32'hFFFFFFFF; b=32'd1; ctrl=4'b0111;
        check(32'd1, "slt -1 < 1 (true)");
        a=32'd1; b=32'hFFFFFFFF; ctrl=4'b0111;
        check(32'd0, "slt 1 < -1 (false)");
        a=32'd5; b=32'd5; ctrl=4'b0111;
        check(32'd0, "slt 5 < 5 (false)");

        // ---- Zero flag ----
        a=32'd5; b=32'd5; ctrl=4'b0110;
        #1;
        if (zero !== 1'b1) begin
            $display("FAIL zero flag on 5-5"); errors=errors+1;
        end
        a=32'd1; b=32'd1; ctrl=4'b0000;
        #1;
        if (zero !== 1'b0) begin
            $display("FAIL zero flag on 1&1 (result=1)"); errors=errors+1;
        end

        $display("--- %0d tests, %0d errors ---", tests, errors);
        if (errors == 0) $display("PASS"); else $display("FAILED");
        $finish;
    end
endmodule