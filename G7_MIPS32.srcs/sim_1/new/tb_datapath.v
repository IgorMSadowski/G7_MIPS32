`timescale 1ns / 1ps

// Behavioral test of the datapath alone: controls are supplied by this bench.
// Instruction words provide register indices, shamt, immediates and jump targets.
// A small response model returns 42 one clock edge after a load request.
module tb_datapath;
    reg clk = 0;
    reg rst = 1;
    reg en = 0;
    reg [31:0] instr = 0;
    reg [31:0] rdata = 0;
    reg reg_dst, alu_src, mem_to_reg, reg_write;
    reg branch, jump, jump_reg, link, mem_read;
    reg [3:0] branch_cond, alu_ctrl;
    wire [31:0] pc, alu_out, wdata;
    wire imem_en, load_issue, commit;

    integer checks = 0;
    integer errors = 0;
    reg [8*32-1:0] test_name;
    reg [8*8-1:0] alu_operation;

    // 50 MHz. The #1 after each edge allows RTL updates to settle;
    // it is a scheduling delay, not a model of FPGA propagation delay.
    always #10 clk = ~clk;

    datapath dut (
        .i_clk(clk), .i_rst(rst), .i_en(en),
        .i_instr(instr), .i_rdata(rdata),
        .i_reg_dst(reg_dst), .i_alu_src(alu_src),
        .i_mem_to_reg(mem_to_reg), .i_reg_write(reg_write),
        .i_branch(branch), .i_jump(jump), .i_jump_reg(jump_reg),
        .i_link(link), .i_branch_cond(branch_cond),
        .i_alu_ctrl(alu_ctrl), .i_mem_read(mem_read),
        .o_pc(pc), .o_alu_out(alu_out), .o_wdata(wdata),
        .o_imem_en(imem_en), .o_load_issue(load_issue), .o_commit(commit)
    );

    // This is only a one-cycle read response, not a RAM implementation.
    always @(posedge clk) begin
        if (rst) rdata <= 0;
        else if (load_issue) rdata <= 32'd42;
    end

    always @(*) begin
        case (alu_ctrl)
            4'd0: alu_operation = "ADD     ";
            4'd1: alu_operation = "SUB     ";
            4'd5: alu_operation = "SLL     ";
            default: alu_operation = "OTHER   ";
        endcase
    end

    // Named aliases make the register results easy to find in the waveform.
    wire [31:0] t0_value = dut.registers._rf[8];
    wire [31:0] t1_value = dut.registers._rf[9];
    wire [31:0] t2_value = dut.registers._rf[10];
    wire [31:0] t3_value = dut.registers._rf[11];
    wire [31:0] t4_value = dut.registers._rf[12];
    wire [31:0] t5_value = dut.registers._rf[13];
    wire [31:0] ra_value = dut.registers._rf[31];

    task clear_controls;
        begin
            reg_dst = 0; alu_src = 0; mem_to_reg = 0; reg_write = 0;
            branch = 0; jump = 0; jump_reg = 0; link = 0; mem_read = 0;
            branch_cond = 0; alu_ctrl = 0;
        end
    endtask

    task next_cycle;
        begin @(posedge clk); #1; end
    endtask

    task test_datapath_state(input condition, input [8*64-1:0] name);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL: %0s", name);
            end
        end
    endtask

    initial begin
        clear_controls;
        test_name = "RESET                           ";
        repeat (2) next_cycle;
        test_datapath_state(dut._pc_r === 0 && t0_value === 0 &&
                            t5_value === 0 && ra_value === 0 && commit === 0,
                            "reset clears PC/registers and blocks commit");

        test_name = "FIRST FETCH                     ";
        rst = 0; en = 1;
        #1;
        test_datapath_state(imem_en === 1 && commit === 0 && pc === 0,
                            "first fetch enables ROM without completing an instruction");
        next_cycle;
        test_datapath_state(dut._pc_r === 0 && commit === 1,
                            "fetch preparation keeps current PC at zero");

        // ADDI t0, zero, 5: immediate operand and rt destination.
        test_name = "IMMEDIATE TO t0                 ";
        instr = 32'h20080005;
        alu_src = 1; reg_write = 1;
        next_cycle;
        test_datapath_state(t0_value === 5 && dut._pc_r === 4,
                            "immediate result is written to rt and PC advances by four");

        // ADDI t1, t0, -2: sign extension and register operand A.
        test_name = "SIGNED IMMEDIATE TO t1          ";
        instr = 32'h2109FFFE;
        next_cycle;
        test_datapath_state(t1_value === 3 && dut._pc_r === 8,
                            "sign-extended minus two added to t0 gives t1 = 3");

        // ADD t2, t0, t1: register operand B and rd destination.
        test_name = "REGISTER ADD TO t2              ";
        clear_controls;
        instr = 32'h01095020;
        reg_dst = 1; reg_write = 1;
        next_cycle;
        test_datapath_state(t2_value === 8 && wdata === 3 && dut._pc_r === 12,
                            "register operands give t2 = 8; store-data path carries rt = 3");

        // SLL t3, t1, 2: operand A comes from shamt instead of rs.
        test_name = "SHIFT AMOUNT TO ALU A           ";
        instr = 32'h00095880;
        alu_ctrl = 4'd5;
        next_cycle;
        test_datapath_state(t3_value === 12 && dut._pc_r === 16,
                            "shamt = 2 selects ALU operand A; t1 << 2 gives t3 = 12");

        // A computed result must not change a register with reg_write = 0.
        test_name = "REGISTER WRITE DISABLED         ";
        clear_controls;
        instr = 32'h20080063; // ADDI t0, zero, 99 fields.
        alu_src = 1;
        next_cycle;
        test_datapath_state(t0_value === 5 && dut._pc_r === 20,
                            "disabled register write preserves t0 but PC advances");

        // Hold the datapath while a write would otherwise be requested.
        test_name = "GLOBAL ENABLE HOLD              ";
        en = 0; reg_write = 1;
        repeat (2) next_cycle;
        test_datapath_state(t0_value === 5 && dut._pc_r === 20 &&
                            commit === 0 && imem_en === 0 && load_issue === 0,
                            "global disable holds PC/registers and blocks transactions");

        // BEQ t0, t0, +1: PC 0x14 -> 0x1C, skipping one word.
        test_name = "BRANCH TAKEN                    ";
        clear_controls;
        en = 1; instr = 32'h11080001;
        branch = 1; alu_ctrl = 4'd1;
        next_cycle;
        test_datapath_state(dut._pc_r === 28,
                            "taken branch selects PC+4 plus immediate shifted left two");

        // BEQ t0, t1, +1: different values select sequential PC 0x20.
        test_name = "BRANCH NOT TAKEN                ";
        instr = 32'h11090001;
        next_cycle;
        test_datapath_state(dut._pc_r === 32,
                            "not-taken branch selects sequential PC+4");

        // JAL 0x40: target26 = 0x10; save PC+4 = 0x24 in r31.
        test_name = "JAL TARGET AND LINK             ";
        clear_controls;
        instr = 32'h0C000010;
        jump = 1; link = 1; reg_write = 1;
        next_cycle;
        test_datapath_state(dut._pc_r === 64 && ra_value === 36,
                            "JAL selects immediate jump target and writes PC+4 to r31");

        // JR ra: select the register target, returning to 0x24.
        test_name = "REGISTER JUMP                   ";
        clear_controls;
        instr = 32'h03E00008;
        jump = 1; jump_reg = 1;
        next_cycle;
        test_datapath_state(dut._pc_r === 36 && ra_value === 36,
                            "JR selects the rs target without overwriting the link");

        // JALR t4, t3: target = 0x0C; save PC+4 = 0x28 in rd (t4).
        test_name = "JALR LINK TO rd                 ";
        instr = 32'h01606009;
        reg_dst = 1; reg_write = 1; link = 1;
        next_cycle;
        test_datapath_state(dut._pc_r === 12 && t4_value === 40 && ra_value === 36,
                            "JALR saves the link in rd, keeps r31 and selects rs target");

        // LW t5, 4(zero): hold this instruction through read and write-back.
        test_name = "LOAD REQUEST - PC HOLDS         ";
        clear_controls;
        instr = 32'h8C0D0004;
        alu_src = 1; mem_to_reg = 1; reg_write = 1; mem_read = 1;
        #1;
        test_datapath_state(alu_out === 4 && load_issue === 1 && commit === 0 &&
                            imem_en === 0 && pc === 12,
                            "load issues one read while PC/ROM and write-back hold");
        next_cycle;
        test_name = "LOAD DATA READY                 ";
        test_datapath_state(rdata === 42 && t5_value === 0 && dut._pc_r === 12 &&
                            load_issue === 0 && commit === 1 && imem_en === 1,
                            "data arrives after the read edge; register/PC still hold");
        next_cycle;
        test_name = "LOAD WRITEBACK                  ";
        test_datapath_state(t5_value === 42 && dut._pc_r === 16,
                            "memory write-back selects 42 and advances PC on completion");

        en = 0;
        clear_controls;
        test_name = "FINISHED                        ";
        #20;
        if (errors == 0) $display("PASS: %0d basic datapath checks", checks);
        else $display("FAILED: %0d errors in %0d checks", errors, checks);
        $finish;
    end

    initial begin
        #2000;
        errors = errors + 1;
        $display("FAIL: datapath test timeout");
        $finish;
    end
endmodule
