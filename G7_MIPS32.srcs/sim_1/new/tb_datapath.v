`timescale 1ns / 1ps

// Test ADDI, ADD and LW by driving the datapath control signals directly.
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
    reg [255:0] step;
    integer checks = 0;
    integer errors = 0;

    // 50 MHz clock.
    always #10 clk = ~clk;

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

    // Read the three registers used in the test for checks and the waveform.
    wire [31:0] t0_value = dut.registers._rf[8];
    wire [31:0] t1_value = dut.registers._rf[9];
    wire [31:0] t2_value = dut.registers._rf[10];

    // Count each check and print the description if it fails.
    task test_result(input condition, input [383:0] description);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL: %0s", description);
            end
        end
    endtask

    initial begin
        // rst = 1 -> PC and registers clear at the rising edge.
        step = "RESET                           ";
        @(posedge clk);
        #1;
        test_result(dut._pc_r == 0 && t0_value == 0 && t1_value == 0 && t2_value == 0 && commit == 0, "reset clears PC and registers");

        // rst = 0, en = 1 -> the first fetch leaves the current PC at 0.
        step = "FIRST FETCH                     ";
        rst = 0;
        en = 1;
        @(posedge clk);
        #1;
        test_result(dut._pc_r == 0 && commit == 1 && imem_en == 1, "datapath is ready for its first instruction");

        // ADDI t0, zero, 5 -> t0 = 5, PC = 0x04
        step = "ADDI                            ";
        instr = 32'h2008_0005;
        reg_dst = 0; alu_src = 1; mem_to_reg = 0; reg_write = 1; mem_read = 0;
        @(posedge clk);
        #1;
        test_result(t0_value == 5 && dut._pc_r == 4, "ADDI writes 5 to t0 and advances PC");

        // ADD t1, t0, t0 -> t1 = 10, PC = 0x08
        step = "ADD                             ";
        instr = 32'h0108_4820;
        reg_dst = 1; alu_src = 0; mem_to_reg = 0; reg_write = 1; mem_read = 0;
        @(posedge clk);
        #1;
        test_result(t1_value == 10 && dut._pc_r == 8, "ADD writes 10 to t1 and advances PC");

        // LW t2, 0(zero) -> issue the read and hold PC = 0x08.
        step = "LW REQUEST                      ";
        instr = 32'h8C0A_0000;
        reg_dst = 0; alu_src = 1; mem_to_reg = 1; reg_write = 1; mem_read = 1;
        #1;
        test_result(load_issue == 1 && commit == 0 && imem_en == 0 && dut._pc_r == 8 && t2_value == 0, "LW requests a read and holds PC and ROM");

        // The simulated RAM returns 20 on the first rising edge of LW.
        @(posedge clk);
        rdata <= 32'd20;
        #1;
        step = "LW WRITEBACK                    ";
        test_result(rdata == 20 && load_issue == 0 && commit == 1 && imem_en == 1 && dut._pc_r == 8 && t2_value == 0, "memory data is ready; t2 and PC still hold");

        // Second rising edge -> t2 = 20, PC = 0x0C.
        @(posedge clk);
        // Clear the load control after the datapath samples it on this edge.
        mem_read <= 0;
        #1;
        test_result(t2_value == 20 && dut._pc_r == 12, "LW writes 20 to t2 and advances PC");

        en = 0;
        reg_write = 0;
        step = "DONE                            ";
        #20;
        if (errors == 0) $display("PASS: %0d simple datapath checks", checks);
        else $display("FAILED: %0d errors", errors);
        $finish;
    end
endmodule
