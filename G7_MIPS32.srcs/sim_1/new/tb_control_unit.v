`timescale 1ns / 1ps

// 24 instructions and two unsupported encodings.
// The control unit is combinational, so no clock is needed.
module tb_control_unit;
    reg [5:0] op = 0, funct = 0;
    reg [4:0] rs = 0, rt = 0, shamt = 0;
    wire reg_dst, alu_src, mem_to_reg, reg_write, mem_read, mem_write;
    wire branch, jump, jump_reg, link;
    wire [3:0] branch_cond, alu_ctrl;
    integer errors = 0;
    integer checks = 0;

    reg [8*32-1:0] test_name;
    reg [8*8-1:0] alu_operation, writeback_source, branch_name;

    control_unit dut (
        .i_op(op), .i_funct(funct), .i_rs(rs), .i_rt(rt), .i_shamt(shamt),
        .o_reg_dst(reg_dst), .o_alu_src(alu_src),
        .o_mem_to_reg(mem_to_reg), .o_reg_write(reg_write),
        .o_mem_read(mem_read), .o_mem_write(mem_write),
        .o_branch(branch), .o_branch_cond(branch_cond),
        .o_jump(jump), .o_jump_reg(jump_reg), .o_link(link),
        .o_alu_ctrl(alu_ctrl)
    );

    // Waveform labels.
    always @(*) begin
        case (alu_ctrl)
            0: alu_operation = "ADD     ";
            1: alu_operation = "SUB     ";
            2: alu_operation = "AND     ";
            3: alu_operation = "OR      ";
            4: alu_operation = "LUI     ";
            5: alu_operation = "SLL     ";
            6: alu_operation = "SRL     ";
            7: alu_operation = "XOR     ";
            8: alu_operation = "ROTR    ";
            9: alu_operation = "WSBH    ";
            10: alu_operation = "SLT     ";
            default: alu_operation = "UNKNOWN ";
        endcase
        if (!branch) branch_name = "NONE    ";
        else begin
            case (branch_cond)
                0: branch_name = "BEQ     ";
                1: branch_name = "BNE     ";
                2: branch_name = "BLTZ    ";
                3: branch_name = "BGEZ    ";
                4: branch_name = "BLEZ    ";
                5: branch_name = "BGTZ    ";
                default: branch_name = "UNKNOWN ";
            endcase
        end
        if (!reg_write) writeback_source = "NONE    ";
        else if (link) writeback_source = "PC+4    ";
        else if (mem_to_reg) writeback_source = "RAM     ";
        else writeback_source = "ALU     ";
    end

    task test_controls(input condition);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL: %0s", test_name);
            end
            #9;
        end
    endtask

    initial begin
        // Register arithmetic: destination rd, two register operands.
        test_name = "ADD                             ";
        op=6'h00; funct=6'h20;
        #1;
        test_controls(reg_dst == 1 && reg_write == 1 && alu_src == 0 && alu_ctrl == 0);

        test_name = "SUB                             ";
        funct=6'h22;
        #1;
        test_controls(reg_dst == 1 && reg_write == 1 && alu_ctrl == 1);

        test_name = "AND                             ";
        funct=6'h24;
        #1;
        test_controls(reg_dst == 1 && reg_write == 1 && alu_ctrl == 2);

        test_name = "OR                              ";
        funct=6'h25;
        #1;
        test_controls(reg_dst == 1 && reg_write == 1 && alu_ctrl == 3);

        test_name = "XOR                             ";
        funct=6'h26;
        #1;
        test_controls(reg_dst == 1 && reg_write == 1 && alu_ctrl == 7);

        test_name = "SLT                             ";
        funct=6'h2A;
        #1;
        test_controls(reg_dst == 1 && reg_write == 1 && alu_ctrl == 10);

        test_name = "SLL                             ";
        funct=6'h00; shamt=3;
        #1;
        test_controls(reg_dst == 1 && reg_write == 1 && alu_ctrl == 5);

        // Immediate arithmetic: destination rt, immediate operand.
        test_name = "ADDI                            ";
        op=6'h08; funct=0; shamt=0;
        #1;
        test_controls(reg_dst == 0 && reg_write == 1 && alu_src == 1 && alu_ctrl == 0);

        test_name = "LUI                             ";
        op=6'h0F;
        #1;
        test_controls(reg_dst == 0 && reg_write == 1 && alu_src == 1 && alu_ctrl == 4 && mem_to_reg == 0);

        // Load writes RAM data to a register; store only writes memory.
        test_name = "LW                              ";
        op=6'h23;
        #1;
        test_controls(mem_read == 1 && mem_write == 0 && reg_write == 1 && mem_to_reg == 1 && reg_dst == 0 && alu_src == 1 && alu_ctrl == 0);

        test_name = "SW                              ";
        op=6'h2B;
        #1;
        test_controls(mem_write == 1 && mem_read == 0 && reg_write == 0 && alu_src == 1 && alu_ctrl == 0);

        // BEQ selects the equality condition. The datapath compares rs and rt.
        test_name = "BEQ                             ";
        op=6'h04;
        #1;
        test_controls(branch == 1 && branch_cond == 0 && alu_ctrl == 1 && alu_src == 0 && reg_write == 0 && mem_write == 0 && mem_read == 0 && jump == 0);

        test_name = "BNE                             ";
        op=6'h05;
        #1;
        test_controls(branch == 1 && branch_cond == 1 && alu_ctrl == 1 && reg_write == 0 && jump == 0);

        // REGIMM uses rt to distinguish BLTZ from BGEZ.
        test_name = "BLTZ                            ";
        op=6'h01; rt=0;
        #1;
        test_controls(branch == 1 && branch_cond == 2 && reg_write == 0 && jump == 0);

        test_name = "BGEZ                            ";
        rt=1;
        #1;
        test_controls(branch == 1 && branch_cond == 3 && reg_write == 0 && jump == 0);

        test_name = "BLEZ                            ";
        op=6'h06; rt=0;
        #1;
        test_controls(branch == 1 && branch_cond == 4 && alu_ctrl == 1 && reg_write == 0 && jump == 0);

        test_name = "BGTZ                            ";
        op=6'h07;
        #1;
        test_controls(branch == 1 && branch_cond == 5 && alu_ctrl == 1 && reg_write == 0 && jump == 0);

        // Jump, jump-and-link, and jump through a register.
        test_name = "J                               ";
        op=6'h02;
        #1;
        test_controls(jump == 1 && jump_reg == 0 && link == 0 && reg_write == 0 && branch == 0);

        test_name = "JAL                             ";
        op=6'h03;
        #1;
        test_controls(jump == 1 && jump_reg == 0 && link == 1 && reg_write == 1 && mem_to_reg == 0);

        test_name = "JR                              ";
        op=6'h00; funct=6'h08;
        #1;
        test_controls(jump == 1 && jump_reg == 1 && link == 0 && reg_write == 0);

        test_name = "JALR                            ";
        funct=6'h09;
        #1;
        test_controls(jump == 1 && jump_reg == 1 && link == 1 && reg_write == 1 && reg_dst == 1);

        // SRL and ROTR share funct=2; rs selects the operation.
        test_name = "SRL                             ";
        funct=6'h02; rs=0;
        #1;
        test_controls(alu_ctrl == 6 && reg_write == 1 && reg_dst == 1 && jump == 0 && jump_reg == 0);

        test_name = "ROTR                            ";
        rs=1;
        #1;
        test_controls(alu_ctrl == 8 && reg_write == 1);

        // One valid WSBH encoding: opcode=1F, funct=20, shamt=2, rs=0.
        test_name = "WSBH                            ";
        op=6'h1F; funct=6'h20; shamt=2; rs=0;
        #1;
        test_controls(alu_ctrl == 9 && reg_dst == 1 && reg_write == 1);

        // One unsupported opcode: no writes, memory requests or control transfer.
        test_name = "UNSUPPORTED OPCODE              ";
        op=6'h3F; funct=0; shamt=0;
        #1;
        test_controls(reg_write == 0 && mem_read == 0 && mem_write == 0 && branch == 0 && jump == 0 && jump_reg == 0 && link == 0);

        test_name = "UNSUPPORTED R FUNCTION          ";
        op=6'h00; funct=6'h3F;
        #1;
        test_controls(reg_write == 0 && mem_read == 0 && mem_write == 0 && branch == 0 && jump == 0 && jump_reg == 0 && link == 0);

        if (errors == 0) $display("PASS: %0d basic control-unit checks", checks);
        else $display("FAILED: %0d errors in %0d checks", errors, checks);
        $finish;
    end
endmodule
