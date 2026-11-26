`timescale 1ns / 1ps

// Test ADDI, ADD and LW with the control unit driving the datapath.
module tb_datapath;
    reg clk = 0;
    reg rst = 1;
    reg en = 0;
    reg [31:0] instr = 0;
    reg [31:0] rdata = 0;
    wire reg_dst, alu_src, mem_to_reg, reg_write, mem_read;
    wire rf_we, link, link_to_ra, alu_a_shamt, equal;
    wire [1:0] pc_sel;
    wire [3:0] alu_ctrl;
    wire [31:0] alu_out, rs_value;
    wire imem_en, load_issue, commit;
    reg [255:0] step;
    integer checks = 0;
    integer errors = 0;

    // 50 MHz clock.
    always #10 clk = ~clk;

    control_unit control (
        .i_clk(clk), .i_rst(rst), .i_en(en),
        .i_rs_value(rs_value), .i_equal(equal),
        .i_op(instr[31:26]), .i_rs(instr[25:21]), .i_rt(instr[20:16]),
        .i_shamt(instr[10:6]), .i_funct(instr[5:0]),
        .o_reg_dst(reg_dst), .o_alu_src(alu_src), .o_mem_to_reg(mem_to_reg),
        .o_reg_write(reg_write), .o_mem_read(mem_read), .o_mem_write(),
        .o_branch(), .o_branch_cond(), .o_jump(), .o_jump_reg(),
        .o_link(link), .o_alu_ctrl(alu_ctrl),
        .o_alu_a_shamt(alu_a_shamt), .o_link_to_ra(link_to_ra),
        .o_pc_sel(pc_sel), .o_rf_we(rf_we), .o_commit(commit),
        .o_imem_en(imem_en), .o_load_issue(load_issue), .o_store_commit()
    );

    datapath dut (
        .i_clk(clk), .i_rst(rst), .i_instr(instr), .i_rdata(rdata),
        .i_reg_dst(reg_dst), .i_alu_src(alu_src), .i_mem_to_reg(mem_to_reg),
        .i_link(link), .i_alu_ctrl(alu_ctrl),
        .i_alu_a_shamt(alu_a_shamt), .i_link_to_ra(link_to_ra),
        .i_pc_sel(pc_sel), .i_rf_we(rf_we), .i_commit(commit),
        .o_rs_value(rs_value), .o_equal(equal),
        .o_pc(), .o_wdata(), .o_alu_out(alu_out)
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
        @(posedge clk);
        #1;
        test_result(t0_value == 5 && dut._pc_r == 4, "ADDI writes 5 to t0 and advances PC");

        // ADD t1, t0, t0 -> t1 = 10, PC = 0x08
        step = "ADD                             ";
        instr = 32'h0108_4820;
        @(posedge clk);
        #1;
        test_result(t1_value == 10 && dut._pc_r == 8, "ADD writes 10 to t1 and advances PC");

        // LW t2, 0(zero) -> issue the read and hold PC = 0x08.
        step = "LW REQUEST                      ";
        instr = 32'h8C0A_0000;
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
        // Present the next instruction after the write-back edge.
        instr <= 32'b0;
        #1;
        test_result(t2_value == 20 && dut._pc_r == 12, "LW writes 20 to t2 and advances PC");

        en = 0;
        step = "DONE                            ";
        #20;
        if (errors == 0) $display("PASS: %0d simple datapath checks", checks);
        else $display("FAILED: %0d errors", errors);
        $finish;
    end
endmodule
