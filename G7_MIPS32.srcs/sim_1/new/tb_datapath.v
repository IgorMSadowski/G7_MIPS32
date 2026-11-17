`timescale 1ns / 1ps

// Three examples: ADDI, ADD and LW with one stall cycle.
// This bench supplies controls directly; there is no control unit or ROM here.
// For LW, the bench returns a fixed value (20) after one rising clock edge.
module tb_datapath;
    reg clk = 0;
    reg rst = 1;
    reg en = 0;
    reg [31:0] instr = 0;
    reg [31:0] rdata = 0;
    reg reg_dst = 0;
    reg alu_src = 0;
    reg mem_to_reg = 0;
    reg reg_write = 0;
    reg mem_read = 0;

    wire [31:0] alu_out;
    wire imem_en, load_issue, commit;
    reg [8*32-1:0] test_name;
    integer checks = 0;
    integer errors = 0;

    always #10 clk = ~clk; // 50 MHz: 20 ns per cycle.

    datapath dut (
        .i_clk(clk), .i_rst(rst), .i_en(en),
        .i_instr(instr), .i_rdata(rdata),
        .i_reg_dst(reg_dst), .i_alu_src(alu_src),
        .i_mem_to_reg(mem_to_reg), .i_reg_write(reg_write),
        .i_mem_read(mem_read),
        .i_alu_ctrl(4'd0), // All three examples use ALU ADD.
        .i_branch(1'b0), .i_branch_cond(4'd0),
        .i_jump(1'b0), .i_jump_reg(1'b0), .i_link(1'b0),
        .o_pc(), .o_wdata(), .o_alu_out(alu_out),
        .o_imem_en(imem_en), .o_load_issue(load_issue), .o_commit(commit)
    );

    // Observe the three registers used in this demonstration.
    wire [31:0] t0_value = dut.registers._rf[8];
    wire [31:0] t1_value = dut.registers._rf[9];
    wire [31:0] t2_value = dut.registers._rf[10];

    // A simple one-cycle memory response, not a complete RAM model.
    always @(posedge clk) begin
        if (rst) rdata <= 0;
        else if (load_issue) rdata <= 32'd20;
    end

    task test_result(input condition, input [8*48-1:0] description);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL: %0s", description);
            end
        end
    endtask

    initial begin
        test_name = "RESET                           ";
        repeat (2) begin @(posedge clk); #1; end
        test_result(dut._pc_r === 0 && t0_value === 0 &&
                    t1_value === 0 && t2_value === 0 && commit === 0,
                    "reset clears PC and registers");

        test_name = "FIRST FETCH                     ";
        rst = 0;
        en = 1;
        @(posedge clk); #1;
        test_result(dut._pc_r === 0 && commit === 1 && imem_en === 1,
                    "datapath is ready for its first instruction");

        // ADDI t0, zero, 5: select immediate B and destination rt.
        test_name = "ADDI: t0 = 0 + 5                ";
        instr = 32'h2008_0005;
        alu_src = 1;
        reg_write = 1;
        @(posedge clk); #1;
        test_result(t0_value === 5 && dut._pc_r === 4,
                    "ADDI writes 5 to t0 and advances PC");

        // ADD t1, t0, t0: select register B and destination rd.
        test_name = "ADD: t1 = t0 + t0               ";
        instr = 32'h0108_4820;
        alu_src = 0;
        reg_dst = 1;
        @(posedge clk); #1;
        test_result(t1_value === 10 && dut._pc_r === 8,
                    "ADD writes 10 to t1 and advances PC");

        // LW t2, 0(zero): hold the same fields until write-back.
        test_name = "LW: REQUEST - PC HOLDS          ";
        instr = 32'h8C0A_0000;
        alu_src = 1;
        reg_dst = 0;
        mem_to_reg = 1;
        mem_read = 1;
        #1;
        test_result(load_issue === 1 && commit === 0 &&
                    imem_en === 0 && dut._pc_r === 8 && t2_value === 0,
                    "LW requests a read and holds PC and ROM");

        @(posedge clk); #1;
        test_name = "LW: WRITEBACK                   ";
        test_result(rdata === 20 && load_issue === 0 && commit === 1 &&
                    imem_en === 1 && dut._pc_r === 8 && t2_value === 0,
                    "memory data is ready; t2 and PC still hold");

        @(posedge clk);
        // Drop the LW control after this edge captures the result.
        // This prevents the held fields from issuing a second read.
        mem_read <= 0;
        #1;
        test_result(t2_value === 20 && dut._pc_r === 12,
                    "LW writes 20 to t2 and advances PC");

        en = 0;
        reg_write = 0;
        mem_read = 0;
        test_name = "DONE: t0=5 t1=10 t2=20          ";
        #20;
        if (errors == 0) $display("PASS: %0d simple datapath checks", checks);
        else $display("FAILED: %0d errors", errors);
        $finish;
    end

    // #1 above allows RTL updates to settle; it is not an FPGA delay model.
    initial begin
        #1000;
        errors = errors + 1;
        $display("FAIL: datapath test timeout");
        $finish;
    end
endmodule
