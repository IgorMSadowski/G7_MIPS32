`timescale 1ns / 1ps

// cond comes from the control unit. This test drives it directly.
module tb_bdu;

    reg branch;
    reg [3:0] cond;
    reg [31:0] rs;
    reg equal;
    wire taken;

    bdu dut(
        .i_branch(branch), .i_branch_cond(cond),
        .i_rs(rs), .i_equal(equal), .o_branch_taken(taken)
    );

    integer errors = 0;
    integer checks = 0;

    // Branch name for the waveform.
    reg [63:0] condition_name;
    always @(*) begin
        if (!branch)
            condition_name = "DISABLED";
        else begin
            case (cond)
                4'b0000: condition_name = "BEQ";
                4'b0001: condition_name = "BNE";
                4'b0010: condition_name = "BLTZ";
                4'b0011: condition_name = "BGEZ";
                4'b0100: condition_name = "BLEZ";
                4'b0101: condition_name = "BGTZ";
                default: condition_name = "UNKNOWN";
            endcase
        end
    end

    task test_branch(input expected_taken, input [255:0] description);
        begin
            checks = checks + 1;
            if (taken !== expected_taken) begin
                $display("FAIL %0s: branch=%b cond=%h rs=%h equal=%b, got %b expected %b", description, branch, cond, rs, equal, taken, expected_taken);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        branch = 1;

        // BEQ takes the branch when equal is 1.
        cond = 4'd0;
        rs = 32'h8000_0000; equal = 1'b1;
        #1;
        test_branch(1'b1, "BEQ equal inputs");
        #19;

        rs = 32'h8000_0000; equal = 1'b0;
        #1;
        test_branch(1'b0, "BEQ different inputs");
        #19;

        rs = 32'h0000_0000; equal = 1'b0;
        #1;
        test_branch(1'b0, "BEQ different inputs with rs = 0");
        #19;

        rs = 32'h0000_0000; equal = 1'b1;
        #1;
        test_branch(1'b1, "BEQ equal inputs with rs = 0");
        #19;

        // BNE takes the branch when equal is 0.
        cond = 4'd1;
        rs = 32'h8000_0000; equal = 1'b0;
        #1;
        test_branch(1'b1, "BNE different inputs");
        #19;

        rs = 32'h8000_0000; equal = 1'b1;
        #1;
        test_branch(1'b0, "BNE equal inputs");
        #19;

        rs = 32'h0000_0000; equal = 1'b1;
        #1;
        test_branch(1'b0, "BNE equal inputs with rs = 0");
        #19;

        rs = 32'h0000_0000; equal = 1'b0;
        #1;
        test_branch(1'b1, "BNE different inputs with rs = 0");
        #19;

        // BLTZ tests rs < 0 with either value of equal.
        cond = 4'd2;
        rs = 32'h8000_0000; equal = 1'b0;
        #1;
        test_branch(1'b1, "BLTZ rs negative, equal = 0");
        #19;

        rs = 32'h8000_0000; equal = 1'b1;
        #1;
        test_branch(1'b1, "BLTZ rs negative, equal = 1");
        #19;

        rs = 32'h7FFF_FFFF; equal = 1'b0;
        #1;
        test_branch(1'b0, "BLTZ rs positive, equal = 0");
        #19;

        rs = 32'h7FFF_FFFF; equal = 1'b1;
        #1;
        test_branch(1'b0, "BLTZ rs positive, equal = 1");
        #19;

        rs = 32'h0000_0000; equal = 1'b0;
        #1;
        test_branch(1'b0, "BLTZ rs zero, equal = 0");
        #19;

        rs = 32'h0000_0000; equal = 1'b1;
        #1;
        test_branch(1'b0, "BLTZ rs zero, equal = 1");
        #19;

        // BGEZ tests rs >= 0 with either value of equal.
        cond = 4'd3;
        rs = 32'h8000_0000; equal = 1'b0;
        #1;
        test_branch(1'b0, "BGEZ rs negative, equal = 0");
        #19;

        rs = 32'h8000_0000; equal = 1'b1;
        #1;
        test_branch(1'b0, "BGEZ rs negative, equal = 1");
        #19;

        rs = 32'h7FFF_FFFF; equal = 1'b0;
        #1;
        test_branch(1'b1, "BGEZ rs positive, equal = 0");
        #19;

        rs = 32'h7FFF_FFFF; equal = 1'b1;
        #1;
        test_branch(1'b1, "BGEZ rs positive, equal = 1");
        #19;

        rs = 32'h0000_0000; equal = 1'b0;
        #1;
        test_branch(1'b1, "BGEZ rs zero, equal = 0");
        #19;

        rs = 32'h0000_0000; equal = 1'b1;
        #1;
        test_branch(1'b1, "BGEZ rs zero, equal = 1");
        #19;

        // BLEZ tests rs <= 0 with either value of equal.
        cond = 4'd4;
        rs = 32'h8000_0000; equal = 1'b0;
        #1;
        test_branch(1'b1, "BLEZ rs negative, equal = 0");
        #19;

        rs = 32'h8000_0000; equal = 1'b1;
        #1;
        test_branch(1'b1, "BLEZ rs negative, equal = 1");
        #19;

        rs = 32'h0000_0000; equal = 1'b0;
        #1;
        test_branch(1'b1, "BLEZ rs zero, equal = 0");
        #19;

        rs = 32'h0000_0000; equal = 1'b1;
        #1;
        test_branch(1'b1, "BLEZ rs zero, equal = 1");
        #19;

        rs = 32'h0000_0001; equal = 1'b0;
        #1;
        test_branch(1'b0, "BLEZ rs positive, equal = 0");
        #19;

        rs = 32'h0000_0001; equal = 1'b1;
        #1;
        test_branch(1'b0, "BLEZ rs positive, equal = 1");
        #19;

        // BGTZ tests rs > 0 with either value of equal.
        cond = 4'd5;
        rs = 32'h8000_0000; equal = 1'b0;
        #1;
        test_branch(1'b0, "BGTZ rs negative, equal = 0");
        #19;

        rs = 32'h8000_0000; equal = 1'b1;
        #1;
        test_branch(1'b0, "BGTZ rs negative, equal = 1");
        #19;

        rs = 32'h0000_0000; equal = 1'b0;
        #1;
        test_branch(1'b0, "BGTZ rs zero, equal = 0");
        #19;

        rs = 32'h0000_0000; equal = 1'b1;
        #1;
        test_branch(1'b0, "BGTZ rs zero, equal = 1");
        #19;

        rs = 32'h0000_0001; equal = 1'b0;
        #1;
        test_branch(1'b1, "BGTZ rs positive, equal = 0");
        #19;

        rs = 32'h0000_0001; equal = 1'b1;
        #1;
        test_branch(1'b1, "BGTZ rs positive, equal = 1");
        #19;

        // Unsupported condition codes give taken = 0.
        cond = 4'd6;
        rs = 32'hFFFF_FFFF; equal = 1'b0;
        #1;
        test_branch(1'b0, "unsupported condition 6");
        #19;

        cond = 4'd15;
        rs = 32'h0000_0001; equal = 1'b1;
        #1;
        test_branch(1'b0, "unsupported condition 15");
        #19;

        // Disable branching for two cases that would otherwise be taken.
        branch = 0;
        cond = 4'd0;
        rs = 32'h0000_0000; equal = 1'b1;
        #1;
        test_branch(1'b0, "disabled BEQ");
        #19;

        cond = 4'd5;
        rs = 32'h0000_0001; equal = 1'b0;
        #1;
        test_branch(1'b0, "disabled BGTZ");
        #19;

        $display("--- %0d checks, %0d errors ---", checks, errors);
        if (errors==0) $display("PASS"); else $display("FAILED");
        $finish;
    end
endmodule
