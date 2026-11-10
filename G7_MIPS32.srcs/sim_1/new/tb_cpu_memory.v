`timescale 1ns / 1ps

// Isolated CPU/DMEM test: instructions are supplied by this testbench.
// No instruction ROM or program initialization settings are changed.
module tb_cpu_memory;
    reg clk = 0, rst = 1, en = 0;
    reg [31:0] instr = 32'hAC000004; // A decoded SW must wait for the first fetch.
    wire [31:0] rdata, wdata, pc, addr;
    wire re, we, imem_en;
    integer errors = 0;
    integer checks = 0;
    reg [8*24-1:0] test_name;
    reg [8*20-1:0] memory_phase;

    always #5 clk = ~clk;

    cpu dut(
        .i_clk(clk), .i_rst(rst), .i_en(en),
        .i_instr(instr), .i_rdata(rdata),
        .o_wdata(wdata), .o_pc(pc), .o_imem_en(imem_en), .o_alu_out(addr),
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

    task check_branch_fallthrough(input [31:0] encoding, input [8*24-1:0] name);
        reg [31:0] next_pc;
        begin
            @(negedge clk);
            instr = encoding;
            next_pc = dut.u_dp._pc_r + 32'd4;
            #1;
            check(dut.u_dp._branch_taken === 1'b0 && pc === next_pc, name);
            @(posedge clk); #1;
            check(dut.u_dp._pc_r === next_pc, "untaken branch commits PC+4");
        end
    endtask

    initial begin
        test_name = "CPU MEMORY AND PAUSE";
        memory_phase = "RESET";
        #1;
        check(re === 0 && we === 0, "no memory requests during reset");
        repeat (2) @(negedge clk);
        rst = 0; en = 1;
        memory_phase = "EXECUTE";
        #1;
        check(imem_en === 1 && pc === 32'd0 && re === 0 && we === 0,
              "ROM startup holds the PC and blocks memory requests");
        @(posedge clk); #1; // The first ROM fetch completes.

        @(negedge clk); instr = 32'h2008002A; // addi t0,zero,42
        @(posedge clk); #1;
        check(dut.u_dp.registers._rf[8] === 32'd42, "prepare store value");

        @(negedge clk); instr = 32'hAC080000; en = 0; // paused sw t0,0(zero)
        memory_phase = "PAUSED STORE";
        repeat (2) begin
            @(posedge clk); #1;
            check(re === 0 && we === 0, "paused store has no request");
        end
        @(negedge clk); en = 1; #1;
        check(we === 1 && addr === 0 && wdata === 42, "enabled store request");
        @(posedge clk); #1; // Store commits.

        @(negedge clk); instr = 32'h8C090000; en = 0; // paused lw t1,0(zero)
        memory_phase = "PAUSED LOAD";
        @(posedge clk); #1;
        check(re === 0 && we === 0, "paused load has no request");
        @(negedge clk); en = 1; #1;
        check(re === 1 && we === 0 && imem_en === 0 &&
              pc === dut.u_dp._pc_r, "load issues once while ROM and PC hold");
        @(posedge clk); #1;
        check(dut.u_dp._load_pending === 1'b1 && rdata === 42 &&
              dut.u_dp.registers._rf[9] === 32'd0 && re === 0 && imem_en === 1,
              "RAM data is ready before the load retires");

        // The real ROM keeps the LW visible until its completion edge.
        @(negedge clk); en = 0;
        repeat (3) begin
            @(posedge clk); #1;
            check(rdata === 42 && dut.u_dp._load_pending === 1'b1 &&
                  pc === dut.u_dp._pc_r && imem_en === 0 && re === 0 && we === 0 &&
                  dut.u_dp.registers._rf[9] === 32'd0,
                  "pending load and instruction survive pause");
        end
        @(negedge clk); en = 1;
        @(posedge clk); #1;
        check(dut.u_dp.registers._rf[9] === 42, "held load writes its destination");

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

        memory_phase = "BRANCH FALLTHROUGH";
        @(negedge clk); instr = 32'h200CFFFF; // addi t4,zero,-1
        @(posedge clk); #1;
        check(dut.u_dp.registers._rf[12] === 32'hFFFF_FFFF, "prepare negative branch operand");

        check_branch_fallthrough(32'h05000002, "BLTZ positive"); // bltz t0,2
        check_branch_fallthrough(32'h05810002, "BGEZ negative"); // bgez t4,2
        check_branch_fallthrough(32'h19000002, "BLEZ positive"); // blez t0,2
        check_branch_fallthrough(32'h1C000002, "BGTZ zero");     // bgtz zero,2
        memory_phase = "EXECUTE";

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

        @(negedge clk); instr = 32'h8C0A0000; #1; // lw t2,0(zero)
        check(re === 1 && imem_en === 0, "first load holds the ROM");
        @(posedge clk); #1;
        check(re === 0 && imem_en === 1, "first load can now retire");
        @(posedge clk); #1;
        check(dut.u_dp.registers._rf[10] === 32'd42, "first load writes t2");

        @(negedge clk); instr = 32'h8C0B0000; #1; // lw t3,0(zero)
        check(re === 1 && imem_en === 0, "next load issues after the first retires");
        @(posedge clk); #1;
        @(posedge clk); #1;
        check(dut.u_dp.registers._rf[11] === 32'd42 &&
              dut.u_dp._load_pending === 1'b0, "second load writes t3");

        @(negedge clk); instr = 32'h200C0001; // addi t4,zero,1
        @(posedge clk); #1;
        check(dut.u_dp.registers._rf[12] === 32'd1, "next instruction resumes after stall");

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
