`timescale 1ns / 1ps

module tb_bdu;

    reg        branch;
    reg [3:0]  cond;
    reg [31:0] rs;
    reg        zero;
    wire       taken;

    bdu dut(
        .i_branch(branch), .i_branch_cond(cond),
        .i_rs(rs), .i_zero(zero), .o_branch_taken(taken)
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

    task check(input exp_taken, input [8*32-1:0] name);
        begin
            #1;
            checks = checks + 1;
            if (taken !== exp_taken) begin
                $display("FAIL %0s: branch=%b cond=%h rs=%h zero=%b, got %b expected %b",
                         name, branch, cond, rs, zero, taken, exp_taken);
                errors = errors + 1;
            end
        end
    endtask

    // These cases must give the same decision for either ALU zero flag value.
    task check_rs(input [31:0] rs_value, input exp_taken, input [8*32-1:0] name);
        begin
            rs = rs_value;
            zero = 0; check(exp_taken, name);
            zero = 1; check(exp_taken, name);
        end
    endtask

    initial begin
        branch=1;
        // beq (cond=0): taken if zero
        cond=4'b0000;
        rs=32'h8000_0000;
        zero=1; check(1, "beq zero=1");
        zero=0; check(0, "beq zero=0");
        rs=32'd0;
        check(0, "beq zero=0 even with rs=0");
        zero=1; check(1, "beq zero=1 with rs=0");

        // bne (cond=1): taken iff !zero
        cond=4'b0001;
        rs=32'h8000_0000;
        zero=0; check(1, "bne zero=0");
        zero=1; check(0, "bne zero=1");
        rs=32'd0;
        check(0, "bne zero=1 with rs=0");
        zero=0; check(1, "bne zero=0 even with rs=0");

        // bltz (cond=2): taken iff rs[31]=1
        cond=4'b0010;
        check_rs(32'h8000_0000, 1, "bltz negative");
        check_rs(32'h7FFF_FFFF, 0, "bltz positive");
        check_rs(32'h0000_0000, 0, "bltz zero");

        // bgez (cond=3): taken iff rs[31]=0
        cond=4'b0011;
        check_rs(32'h8000_0000, 0, "bgez negative");
        check_rs(32'h7FFF_FFFF, 1, "bgez positive");
        check_rs(32'h0000_0000, 1, "bgez zero");

        // blez (cond=4): taken for negative and zero, not positive
        cond=4'b0100;
        check_rs(32'h8000_0000, 1, "blez negative");
        check_rs(32'h0000_0000, 1, "blez zero");
        check_rs(32'h0000_0001, 0, "blez positive");

        // bgtz (cond=5): taken only for positive
        cond=4'b0101;
        check_rs(32'h8000_0000, 0, "bgtz negative");
        check_rs(32'h0000_0000, 0, "bgtz zero");
        check_rs(32'h0000_0001, 1, "bgtz positive");

        // The remaining internal condition codes never take a branch.
        for (code = 6; code < 16; code = code + 1) begin
            cond = code[3:0];
            check_rs(32'hFFFF_FFFF, 0, "unsupported code negative");
            check_rs(32'd0, 0, "unsupported code zero");
            check_rs(32'd1, 0, "unsupported code positive");
        end

        // The branch enable gates every condition.
        branch = 0;
        for (code = 0; code < 16; code = code + 1) begin
            cond = code[3:0];
            check_rs(32'hFFFF_FFFF, 0, "disabled branch negative");
            check_rs(32'd0, 0, "disabled branch zero");
            check_rs(32'd1, 0, "disabled branch positive");
        end

        $display("--- %0d checks, %0d errors ---", checks, errors);
        if (errors==0) $display("PASS"); else $display("FAILED");
        $finish;
    end
endmodule
