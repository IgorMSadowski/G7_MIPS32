`timescale 1ns / 1ps

// Test the datapath independently by driving its control inputs manually.
// The Control Unit and its load-stall sequencing are tested separately.
module tb_datapath;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg [31:0] instr = 32'b0;
    reg [31:0] rdata = 32'b0;

    // Manually driven control signals from a hypothetical Control Unit.
    reg        reg_dst = 1'b0;
    reg        alu_src = 1'b0;
    reg        mem_to_reg = 1'b0;
    reg        alu_a_shamt = 1'b0;
    reg        rf_we = 1'b0;
    reg        link = 1'b0;
    reg        link_to_ra = 1'b0;
    reg [3:0]  alu_ctrl = 4'b0000;
    reg [1:0]  pc_sel = 2'b00;
    reg        commit = 1'b0;

    wire [31:0] alu_out;
    wire [31:0] rs_value;
    wire        equal;
    wire [31:0] pc;
    wire [31:0] wdata;

    reg [255:0] execution_step;
    integer checks = 0;
    integer errors = 0;

    // 50 MHz clock.
    always #10 clk = ~clk;

    datapath dut (
        .i_clk(clk),
        .i_rst(rst),

        .i_instr(instr),
        .i_rdata(rdata),

        .i_alu_a_shamt(alu_a_shamt),
        .i_alu_src(alu_src),
        .i_alu_ctrl(alu_ctrl),

        .i_reg_dst(reg_dst),
        .i_mem_to_reg(mem_to_reg),
        .i_link(link),
        .i_link_to_ra(link_to_ra),
        .i_rf_we(rf_we),

        .i_pc_sel(pc_sel),
        .i_commit(commit),

        .i_irq_request(1'b0),
        .i_irq_vector(32'b0),

        .o_pc(pc),

        .o_alu_out(alu_out),
        .o_wdata(wdata),

        .o_rs_value(rs_value),
        .o_equal(equal),

        .o_irq_ack(),
        .o_irq_return(),
        .o_return_pc()
    );

    // Read the registers used in the test for checks and the waveform.
    wire [31:0] t0_value = dut.registers._rf[8];
    wire [31:0] t1_value = dut.registers._rf[9];
    wire [31:0] t2_value = dut.registers._rf[10];

    task test_result(input condition, input [383:0] description);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL at %0s: %0s", execution_step, description);
            end
        end
    endtask

    task set_execution_step(input [255:0] name);
        begin
            execution_step = name;
            $display("T=%0t | EXECUTION STEP: %0s", $time, execution_step);
        end
    endtask

    initial begin
        // Reset the datapath and its register file.
        set_execution_step("RESET");
        @(posedge clk);
        #1;
        test_result(dut._pc_r == 0 && t0_value == 0 &&
                    t1_value == 0 && t2_value == 0,
                    "reset clears PC and registers");

        // Drive controls just after a rising edge. The DUT samples them at
        // the next rising edge; the testbench does not use the falling edge.
        // ADDI t0, zero, 5 -> t0 = 5, PC = 0x04.
        set_execution_step("ADDI - commit");
        rst = 1'b0;
        instr = 32'h2008_0005;
        reg_dst = 1'b0;
        alu_src = 1'b1;
        mem_to_reg = 1'b0;
        alu_a_shamt = 1'b0;
        rf_we = 1'b1;
        link = 1'b0;
        link_to_ra = 1'b0;
        alu_ctrl = 4'b0000; // ADD
        pc_sel = 2'b00;     // sequential PC + 4
        commit = 1'b1;
        @(posedge clk);
        #1;
        test_result(t0_value == 5 && dut._pc_r == 4,"ADDI writes 5 to t0 and advances PC");

        // ADD t1, t0, t0 -> t1 = 10, PC = 0x08.
        set_execution_step("ADD - commit");
        instr = 32'h0108_4820;
        reg_dst = 1'b1;
        alu_src = 1'b0;
        mem_to_reg = 1'b0;
        rf_we = 1'b1;
        alu_ctrl = 4'b0000; // ADD
        pc_sel = 2'b00;     // sequential PC + 4
        commit = 1'b1;
        @(posedge clk);
        #1;
        test_result(t1_value == 10 && dut._pc_r == 8, "ADD writes 10 to t1 and advances PC");

        // LW t2, 0(zero) -> issue the read and hold PC = 0x08.
        set_execution_step("LW - request and wait");
        instr = 32'h8C0A_0000;
        reg_dst = 1'b0;
        alu_src = 1'b1;
        mem_to_reg = 1'b1;
        rf_we = 1'b0;
        alu_ctrl = 4'b0000; // ADD address = rs + sign-extended immediate
        pc_sel = 2'b00;
        commit = 1'b0;
        #1;
        test_result(pc == 8 && t2_value == 0,"commit low holds PC and prevents register write");

        // Let the DUT sample the load-wait controls before driving write-back.
        @(posedge clk);
        #1;
        test_result(dut._pc_r == 8 && t2_value == 0,"datapath remains held during the load wait");
        rdata = 32'd20;
        rf_we = 1'b1;
        commit = 1'b1;

        // Write back in the register file
        set_execution_step("LW - write-back and commit");
        @(posedge clk);
        #1;
        test_result(t2_value == 20 && dut._pc_r == 12,"load write-back and PC advance occur on commit edge");

        set_execution_step("DONE");
        rf_we = 1'b0;
        commit = 1'b0;
        #20;

        if (errors == 0)
            $display("PASS: %0d datapath checks", checks);
        else
            $display("FAILED: %0d errors out of %0d checks", errors, checks);
        $finish;
    end
endmodule
