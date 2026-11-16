`timescale 1ns / 1ps

module tb_alu;

    reg  [31:0] a, b;
    reg  [3:0]  ctrl;
    wire [31:0] y;
    wire        zero;
    wire        overflow;
    wire        negative;
    wire        carry;

    alu dut(
        .i_a(a), 
        .i_b(b), 
        .i_ctrl(ctrl),
        .o_y(y), 
        .o_zero(zero), 
        .o_overflow(overflow),
        .o_negative(negative),
        .o_carry(carry)
    );

    integer errors = 0;
    integer tests  = 0;

    task test_result(input [31:0] expected, input [8*24-1:0] name);
        begin
            tests = tests + 1;
            #1;
            if (y !== expected) begin
                $display("FAIL %0s: got %h, expected %h", name, y, expected);
                errors = errors + 1;
            end
            if (negative !== expected[31]) begin
                $display("FAIL %0s: negative = %b, expected %b", name, negative, expected[31]);
                errors = errors + 1;
            end
            if (ctrl != 4'b0000 && ctrl != 4'b0001 && carry !== 1'b0) begin
                $display("FAIL %0s: carry/borrow must be 0 outside ADD/SUB", name);
                errors = errors + 1;
            end
        end
    endtask
    
    task test_flags(
        input expected_zero,
        input expected_negative,
        input expected_carry,
        input expected_overflow
    );
        begin
            // Call immediately after test_result(), which already waits #1.
            if (zero !== expected_zero ||
                negative !== expected_negative ||
                carry !== expected_carry ||
                overflow !== expected_overflow) begin
                $display("FAIL flags: got Z=%b N=%b C=%b V=%b; expected Z=%b N=%b C=%b V=%b",
                         zero, negative, carry, overflow,
                         expected_zero, expected_negative,
                         expected_carry, expected_overflow);
                errors = errors + 1;
            end
        end
    endtask

    reg [8*8-1:0] operation;

    always @(*) begin
        case (ctrl)
            4'b0000: operation = "ADD";
            4'b0001: operation = "SUB";
            4'b0010: operation = "AND";
            4'b0011: operation = "OR";
            4'b0100: operation = "LUI";
            4'b0101: operation = "SLL";
            4'b0110: operation = "SRL";
            4'b0111: operation = "XOR";
            4'b1000: operation = "ROTR";
            4'b1001: operation = "WSBH";
            4'b1010: operation = "SLT";
            default: operation = "UNKNOWN";
        endcase
    end

    initial begin
        // Run operations in ascending control-code order.
        // test_flags arguments: zero, negative, carry, overflow.

        // 0 - ADD
        a=32'd10; b=32'd20; ctrl=4'b0000;
        test_result(32'd30, "add 10+20");
        if (carry !== 1'b0) begin
            $display("FAIL: expected ADD carry = 0");
            errors = errors + 1;
        end
        a=32'hFFFFFFFF; b=32'd1;
        test_result(32'h0, "add overflow wraps to 0");
        if (carry !== 1'b1) begin
            $display("FAIL: expected ADD carry = 1");
            errors = errors + 1;
        end
        a=32'h7FFFFFFF; b=32'h00000001;
        test_result(32'h80000000, "add signed overflow");
        if (carry !== 1'b0) begin
            $display("FAIL: signed overflow must not imply carry");
            errors = errors + 1;
        end
        if (overflow !== 1'b1) begin
            $display("FAIL: expected ADD overflow = 1");
            errors = errors + 1;
        end
        a=32'h80000000; b=32'hFFFFFFFF;
        test_result(32'h7FFFFFFF, "add negative overflow");
        test_flags(0, 0, 1, 1);
        a=32'hFFFFFFFF; b=32'h00000001;
        test_result(32'h00000000, "add carry, no overflow");
        test_flags(1, 0, 1, 0);
        a=32'hFFFFFFFF; b=32'hFFFFFFFF;
        test_result(32'hFFFFFFFE, "add negative result");
        test_flags(0, 1, 1, 0);
        a=32'h7FFFFFFF; b=32'h00000001;
        test_result(32'h80000000, "ADD overflow flags");
        test_flags(0, 1, 0, 1);
        a=32'hFFFFFFFF; b=32'h00000001;
        test_result(32'h00000000, "ADD carry flags");
        test_flags(1, 0, 1, 0);

        // 1 - SUB
        a=32'd20; b=32'd10; ctrl=4'b0001;
        test_result(32'd10, "sub 20-10");
        test_flags(0, 0, 0, 0); // No unsigned borrow: 20 >= 10.
        a=32'd10; b=32'd20;
        test_result(32'hFFFFFFF6, "sub 10-20 = -10");
        test_flags(0, 1, 1, 0); // Unsigned borrow: 10 < 20.
        a=32'h80000000; b=32'h00000001;
        test_result(32'h7FFFFFFF, "sub negative overflow");
        test_flags(0, 0, 0, 1);
        a=32'h80000000; b=32'hFFFFFFFF;
        test_result(32'h80000001, "sub without overflow");
        test_flags(0, 1, 1, 0); // Unsigned borrow, but no signed overflow.
        a=32'd5; b=32'd5;
        test_result(32'h00000000, "sub zero flags");
        test_flags(1, 0, 0, 0);
        // Additional zero-flag check kept with SUB.
        a=32'd5; b=32'd5;
        #1;
        if (zero !== 1'b1) begin
            $display("FAIL zero flag on 5-5"); errors=errors+1;
        end
        a=32'h00000000; b=32'h00000001;
        test_result(32'hFFFFFFFF, "sub 0-1 borrow");
        test_flags(0, 1, 1, 0);
        a=32'hFFFFFFFF; b=32'h00000000;
        test_result(32'hFFFFFFFF, "sub max-0 no borrow");
        test_flags(0, 1, 0, 0);
        a=32'h7FFFFFFF; b=32'hFFFFFFFF;
        test_result(32'h80000000, "sub positive overflow");
        test_flags(0, 1, 1, 1); // Both unsigned borrow and signed overflow.

        // 2 - AND. The preceding SUB asserted borrow/overflow; AND clears both.
        a=32'h7FFFFFFF; b=32'h00000001; ctrl=4'b0010;
        test_result(32'h00000001, "AND clears overflow");
        test_flags(0, 0, 0, 0);
        a=32'hFF00FF00; b=32'h0FF00FF0;
        test_result(32'h0F000F00, "and mask");
        a=32'd1; b=32'd1;
        #1;
        if (zero !== 1'b0) begin
            $display("FAIL zero flag on 1&1 (result=1)"); errors=errors+1;
        end

        // 3 - OR. Carry and overflow must both be zero for logical operations.
        a=32'hFF00FF00; b=32'h0FF00FF0; ctrl=4'b0011;
        test_result(32'hFFF0_FFF0, "or merge");
        a=32'hFFFFFFFF; b=32'h00000001;
        test_result(32'hFFFFFFFF, "OR carry is zero");
        test_flags(0, 1, 0, 0);

        // 4 - LUI
        a=32'h00000000; b=32'h00001234; ctrl=4'b0100;
        test_result(32'h12340000, "lui immediate");
        b=32'hFFFF8001;
        test_result(32'h80010000, "lui negative immediate");

        // 5 - SLL (A is the shift amount)
        a=32'd2; b=32'h0000_0005; ctrl=4'b0101;
        test_result(32'h0000_0014, "sll 5 by 2");

        // 6 - SRL
        a=32'd1; b=32'h0000_0014; ctrl=4'b0110;
        test_result(32'h0000_000A, "srl 20 by 1");

        // 7 - XOR
        a=32'hA5A5_0F0F; b=32'hFFFF_00FF; ctrl=4'b0111;
        test_result(32'h5A5A_0FF0, "xor");

        // 8 - ROTR
        a=32'd8; b=32'h1234_5678; ctrl=4'b1000;
        test_result(32'h7812_3456, "rotr wraps low byte");
        a=32'd0;
        test_result(32'h1234_5678, "rotr by 0");
        a=32'd31; b=32'h8000_0001;
        test_result(32'h0000_0003, "rotr by 31");

        // 9 - WSBH
        a=0; b=32'h1234_5678; ctrl=4'b1001;
        test_result(32'h3412_7856, "wsbh");

        // 10 - SLT (signed)
        a=32'hFFFFFFFF; b=32'd1; ctrl=4'b1010;
        test_result(32'd1, "slt -1 < 1 (true)");
        a=32'd1; b=32'hFFFFFFFF;
        test_result(32'd0, "slt 1 < -1 (false)");
        a=32'd5; b=32'd5;
        test_result(32'd0, "slt 5 < 5 (false)");

        $display("--- %0d tests, %0d errors ---", tests, errors);
        if (errors == 0) $display("PASS"); else $display("FAILED");
        $finish;
    end
endmodule
