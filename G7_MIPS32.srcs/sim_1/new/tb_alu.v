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
        check(32'hFFF0_FFF0, "or merge");

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

        // ---- XOR ----
        a=32'hA5A5_0F0F; b=32'hFFFF_00FF; ctrl=4'b0011;
        check(32'h5A5A_0FF0, "xor");

        // ---- Shifts and rotate (A is the shift amount) ----
        a=32'd2; b=32'h0000_0005; ctrl=4'b1001;
        check(32'h0000_0014, "sll 5 by 2");
        a=32'd1; b=32'h0000_0014; ctrl=4'b1010;
        check(32'h0000_000A, "srl 20 by 1");
        a=32'd8; b=32'h1234_0000; ctrl=4'b1101;
        check(32'h0012_3400, "rotr by 8");

        // ---- WSBH ----
        a=0; b=32'h1234_5678; ctrl=4'b1100;
        check(32'h3412_7856, "wsbh");

        // ---- LUI ----
        a=32'hDEADBEEF; b=32'h00001234; ctrl=4'b1000;
        check(32'h12340000, "lui immediate");
        b=32'hFFFF8001;
        check(32'h80010000, "lui negative immediate");

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