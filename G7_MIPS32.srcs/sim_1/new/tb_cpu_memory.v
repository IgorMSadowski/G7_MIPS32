`timescale 1ns / 1ps

// Isolated CPU/DMEM test: instructions are supplied by this testbench.
// No instruction ROM or program initialization settings are changed.
module tb_cpu_memory;
    reg clk = 0, rst = 1, en = 0;
    reg [31:0] instr = 0;
    wire [31:0] rdata, wdata, pc, addr;
    wire re, we;
    integer errors = 0;
    integer checks = 0;

    always #5 clk = ~clk;

    cpu dut(
        .i_clk(clk), .i_rst(rst), .i_en(en),
        .i_instr(instr), .i_rdata(rdata),
        .o_wdata(wdata), .o_pc(pc), .o_alu_out(addr),
        .o_mem_read(re), .o_mem_write(we)
    );
    data_memory dm(
        .i_clk(clk), .i_rst(rst), .i_en(en), .i_addr(addr),
        .i_wdata(wdata), .i_re(re), .i_we(we), .o_rdata(rdata)
    );

    task check(input condition, input [8*64-1:0] name);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL %0s", name);
            end
        end
    endtask

    initial begin
        #1;
        check(re === 0 && we === 0, "no memory requests during reset");
        repeat (2) @(negedge clk);
        rst = 0; en = 1;
        @(posedge clk); #1; // Initial FETCH -> EXEC.

        @(negedge clk); instr = 32'h2008002A; // addi t0,zero,42
        @(posedge clk); #1;
        check(dut.u_dp.registers._rf[8] === 32'd42, "prepare store value");

        @(negedge clk); instr = 32'hAC080000; en = 0; // paused sw t0,0(zero)
        repeat (2) begin
            @(posedge clk); #1;
            check(re === 0 && we === 0, "paused store has no request");
        end
        @(negedge clk); en = 1; #1;
        check(we === 1 && addr === 0 && wdata === 42, "enabled store request");
        @(posedge clk); #1; // Store commits.

        @(negedge clk); instr = 32'h8C090000; en = 0; // paused lw t1,0(zero)
        @(posedge clk); #1;
        check(re === 0 && we === 0, "paused load has no request");
        @(negedge clk); en = 1; #1;
        check(re === 1 && we === 0, "load request during EXEC");
        @(posedge clk); #1; // DMEM returns 42; FSM enters LOAD.
        check(dut.u_dp._state === 2 && rdata === 42, "load data ready");
        check(re === 0 && we === 0, "LOAD has no extra memory request");

        // Change to the next instruction while the pending load is paused.
        @(negedge clk); instr = 32'hAC000004; en = 0; // next: sw zero,4(zero)
        repeat (3) begin
            @(posedge clk); #1;
            check(rdata === 42 && dut.u_dp._state === 2 && re === 0 && we === 0,
                  "pending load survives pause and next instruction");
        end
        @(negedge clk); en = 1;
        @(posedge clk); #1;
        check(dut.u_dp.registers._rf[9] === 42, "load writes saved destination");

        // The zero flag stays internal to the datapath and must still reach BDU.
        // t0 and t1 both contain 42; the branch offset is two words (8 bytes).
        @(negedge clk); instr = 32'h11090002; #1; // beq t0,t1,2
        check(dut.u_dp._zero === 1'b1 && dut.u_dp._branch_taken === 1'b1 &&
              dut.u_dp._pc_next === (dut.u_dp._pc4 + 32'd8),
              "BEQ takes equal operands using internal zero flag");
        @(posedge clk); #1;

        @(negedge clk); instr = 32'h15090002; #1; // bne t0,t1,2
        check(dut.u_dp._zero === 1'b1 && dut.u_dp._branch_taken === 1'b0 &&
              dut.u_dp._pc_next === dut.u_dp._pc4,
              "BNE falls through for equal operands");
        @(posedge clk); #1;

        @(negedge clk); instr = 32'h11000002; #1; // beq t0,zero,2
        check(dut.u_dp._zero === 1'b0 && dut.u_dp._branch_taken === 1'b0 &&
              dut.u_dp._pc_next === dut.u_dp._pc4,
              "BEQ falls through for unequal operands");
        @(posedge clk); #1;

        @(negedge clk); instr = 32'h15000002; #1; // bne t0,zero,2
        check(dut.u_dp._zero === 1'b0 && dut.u_dp._branch_taken === 1'b1 &&
              dut.u_dp._pc_next === (dut.u_dp._pc4 + 32'd8),
              "BNE takes unequal operands using internal zero flag");
        @(posedge clk); #1;

        // Unknown REGIMM selector with a zero ALU result must not branch.
        // Previously this could select BEQ's condition and jump by the offset.
        @(negedge clk); instr = 32'h04020004; #1;
        check(dut.u_dp._pc_next === dut.u_dp._pc4,
              "unsupported REGIMM advances sequentially even when ALU zero");
        @(posedge clk); #1;

        // Noncanonical shift (bits 25:22 nonzero) must not overwrite t0.
        @(negedge clk); instr = 32'h00604002;
        @(posedge clk); #1;
        check(dut.u_dp.registers._rf[8] === 42,
              "unsupported shift encoding cannot write a register");

        // Unknown R-type function must not execute the default ALU ADD.
        @(negedge clk); instr = 32'h0000403F;
        @(posedge clk); #1;
        check(dut.u_dp.registers._rf[8] === 42,
              "unsupported R-type function cannot overwrite a register");

        @(negedge clk); instr = 32'hAC000004; rst = 1; #1;
        check(re === 0 && we === 0, "reset blocks decoded store");
        $display("--- %0d memory/pause checks, %0d errors ---", checks, errors);
        if (errors == 0) $display("PASS"); else $display("FAILED");
        $finish;
    end

    initial begin
        #2000;
        errors = errors + 1;
        $display("TIMEOUT: CPU memory/pause test");
        $finish;
    end
endmodule
