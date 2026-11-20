`timescale 1ns / 1ps

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
    integer code;

    reg [8*8-1:0] condition_name;
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

    task test_branch(input exp_taken, input [8*32-1:0] name);
        begin
            #1;
            checks = checks + 1;
            if (taken !== exp_taken) begin
                $display("FAIL %0s: branch=%b cond=%h rs=%h equal=%b, got %b expected %b", name, branch, cond, rs, equal, taken, exp_taken);
                errors = errors + 1;
            end
        end
    endtask

    // These cases depend only on rs, regardless of equality with rt.
    task test_rs_condition(input [31:0] rs_value, input exp_taken, input [8*32-1:0] name);
        begin
            rs = rs_value;
            equal = 0; test_branch(exp_taken, name);
            equal = 1; test_branch(exp_taken, name);
        end
    endtask

    initial begin
        branch=1;
        // beq (cond=0): taken if equal
        cond=4'b0000;
        rs=32'h8000_0000;
        equal=1; test_branch(1, "beq equal=1");
        equal=0; test_branch(0, "beq equal=0");
        rs=32'd0;
        test_branch(0, "beq equal=0 even with rs=0");
        equal=1; test_branch(1, "beq equal=1 with rs=0");

        // bne (cond=1): taken if unequal
        cond=4'b0001;
        rs=32'h8000_0000;
        equal=0; test_branch(1, "bne equal=0");
        equal=1; test_branch(0, "bne equal=1");
        rs=32'd0;
        test_branch(0, "bne equal=1 with rs=0");
        equal=0; test_branch(1, "bne equal=0 even with rs=0");

        // bltz (cond=2): taken iff rs[31]=1
        cond=4'b0010;
        test_rs_condition(32'h8000_0000, 1, "bltz negative");
        test_rs_condition(32'h7FFF_FFFF, 0, "bltz positive");
        test_rs_condition(32'h0000_0000, 0, "bltz zero");

        // bgez (cond=3): taken iff rs[31]=0
        cond=4'b0011;
        test_rs_condition(32'h8000_0000, 0, "bgez negative");
        test_rs_condition(32'h7FFF_FFFF, 1, "bgez positive");
        test_rs_condition(32'h0000_0000, 1, "bgez zero");

        // blez (cond=4): taken for negative and zero, not positive
        cond=4'b0100;
        test_rs_condition(32'h8000_0000, 1, "blez negative");
        test_rs_condition(32'h0000_0000, 1, "blez zero");
        test_rs_condition(32'h0000_0001, 0, "blez positive");

        // bgtz (cond=5): taken only for positive
        cond=4'b0101;
        test_rs_condition(32'h8000_0000, 0, "bgtz negative");
        test_rs_condition(32'h0000_0000, 0, "bgtz zero");
        test_rs_condition(32'h0000_0001, 1, "bgtz positive");

        // The remaining internal condition codes never take a branch.
        for (code = 6; code < 16; code = code + 1) begin
            cond = code[3:0];
            test_rs_condition(32'hFFFF_FFFF, 0, "unsupported code negative");
            test_rs_condition(32'd0, 0, "unsupported code zero");
            test_rs_condition(32'd1, 0, "unsupported code positive");
        end

        // The branch enable gates every condition.
        branch = 0;
        for (code = 0; code < 16; code = code + 1) begin
            cond = code[3:0];
            test_rs_condition(32'hFFFF_FFFF, 0, "disabled branch negative");
            test_rs_condition(32'd0, 0, "disabled branch zero");
            test_rs_condition(32'd1, 0, "disabled branch positive");
        end

        $display("--- %0d checks, %0d errors ---", checks, errors);
        if (errors==0) $display("PASS"); else $display("FAILED");
        $finish;
    end
endmodule
