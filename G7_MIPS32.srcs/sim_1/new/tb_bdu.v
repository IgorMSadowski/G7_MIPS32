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

    task check(input exp_taken, input [8*32-1:0] name);
        begin
            #1;
            if (taken !== exp_taken) begin
                $display("FAIL %0s: got %b expected %b", name, taken, exp_taken);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        // branch=0 → always 0 regardless of cond/rs/zero
        branch=0; cond=0; rs=0; zero=1;
        check(0, "branch=0 always 0");

        branch=1;
        // beq (cond=0): taken iff zero
        cond=4'b0000;
        zero=1; check(1, "beq zero=1");
        zero=0; check(0, "beq zero=0");

        // bne (cond=1): taken iff !zero
        cond=4'b0001;
        zero=0; check(1, "bne zero=0");
        zero=1; check(0, "bne zero=1");

        // bltz (cond=2): taken iff rs[31]=1
        cond=4'b0010;
        rs=32'h8000_0000; check(1, "bltz negative");
        rs=32'h7FFF_FFFF; check(0, "bltz positive");
        rs=32'h0000_0000; check(0, "bltz zero");

        // bgez (cond=3): taken iff rs[31]=0
        cond=4'b0011;
        rs=32'h8000_0000; check(0, "bgez negative");
        rs=32'h7FFF_FFFF; check(1, "bgez positive");
        rs=32'h0000_0000; check(1, "bgez zero");

        $display("--- %0d errors ---", errors);
        if (errors==0) $display("PASS"); else $display("FAILED");
        $finish;
    end
endmodule