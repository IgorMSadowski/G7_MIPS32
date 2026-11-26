`timescale 1ns / 1ps

// Feed the instruction fields directly and check the control outputs.
// Covers the 24 G7 instructions and two unsupported encodings.
module tb_control_unit;
    reg [5:0] op = 0;
    reg [5:0] funct = 0;
    reg [4:0] rs = 0;
    reg [4:0] rt = 0;
    reg [4:0] shamt = 0;
    wire reg_dst;
    wire alu_src;
    wire mem_to_reg;
    wire reg_write;
    wire mem_read;
    wire mem_write_request;
    wire branch;
    wire jump;
    wire jump_reg;
    wire link;
    wire [3:0] branch_cond;
    wire [3:0] alu_ctrl;
    integer errors = 0;
    integer checks = 0;

    reg [255:0] instruction;
    reg [63:0] alu_operation;
    reg [63:0] writeback_source;
    reg [63:0] branch_name;

    control_unit dut (
        .i_clk(1'b0),
        .i_rst(1'b1),
        .i_en(1'b0),

        .i_op(op),
        .i_rs(rs),
        .i_rt(rt),
        .i_shamt(shamt),
        .i_funct(funct),

        .i_rs_value(32'b0),
        .i_equal(1'b0),

        .o_alu_a_shamt(),
        .o_alu_src(alu_src),
        .o_alu_ctrl(alu_ctrl),

        .o_reg_dst(reg_dst),
        .o_mem_to_reg(mem_to_reg),
        .o_link(link),
        .o_link_to_ra(),
        .o_rf_we(),

        .o_pc_sel(),
        .o_commit(),
        .o_imem_en(),

        .o_load_issue(),
        .o_mem_write()
    );

    // Observe internal decoder decisions in simulation.
    assign reg_write = dut.reg_write_request;
    assign mem_read = dut.mem_read_request;
    assign mem_write_request = dut.mem_write_request;
    assign branch = dut.branch;
    assign branch_cond = dut.branch_cond;
    assign jump = dut.jump;
    assign jump_reg = dut.jump_reg;

    // Show the ALU operation, branch condition and source of the register write data.
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

    // Check the control outputs and record any failure.
    task test_controls(input condition);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL: %0s", instruction);
            end
        end
    endtask

    initial begin
        // Register arithmetic: destination rd, two register operands.
        instruction = "ADD                             ";
        op = 6'h00;
        funct = 6'h20;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(reg_dst == 1 && reg_write == 1 && alu_src == 0 && alu_ctrl == 0);
        #19;

        instruction = "SUB                             ";
        op = 6'h00;
        funct = 6'h22;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(reg_dst == 1 && reg_write == 1 && alu_ctrl == 1);
        #19;

        instruction = "AND                             ";
        op = 6'h00;
        funct = 6'h24;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(reg_dst == 1 && reg_write == 1 && alu_ctrl == 2);
        #19;

        instruction = "OR                              ";
        op = 6'h00;
        funct = 6'h25;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(reg_dst == 1 && reg_write == 1 && alu_ctrl == 3);
        #19;

        instruction = "XOR                             ";
        op = 6'h00;
        funct = 6'h26;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(reg_dst == 1 && reg_write == 1 && alu_ctrl == 7);
        #19;

        instruction = "SLT                             ";
        op = 6'h00;
        funct = 6'h2A;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(reg_dst == 1 && reg_write == 1 && alu_ctrl == 10);
        #19;

        instruction = "SLL                             ";
        op = 6'h00;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(reg_dst == 1 && reg_write == 1 && alu_ctrl == 5);
        #19;

        // Immediate arithmetic: destination rt, immediate operand.
        instruction = "ADDI                            ";
        op = 6'h08;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(reg_dst == 0 && reg_write == 1 && alu_src == 1 && alu_ctrl == 0);
        #19;

        instruction = "LUI                             ";
        op = 6'h0F;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(reg_dst == 0 && reg_write == 1 && alu_src == 1 && alu_ctrl == 4 && mem_to_reg == 0);
        #19;

        // Load writes RAM data to a register; store only writes memory.
        instruction = "LW                              ";
        op = 6'h23;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(mem_read == 1 && mem_write_request == 0 && reg_write == 1 && mem_to_reg == 1 && reg_dst == 0 && alu_src == 1 && alu_ctrl == 0);
        #19;

        instruction = "SW                              ";
        op = 6'h2B;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(mem_write_request == 1 && mem_read == 0 && reg_write == 0 && alu_src == 1 && alu_ctrl == 0);
        #19;

        // BEQ selects the equality condition. The datapath compares rs and rt.
        instruction = "BEQ                             ";
        op = 6'h04;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(branch == 1 && branch_cond == 0 && alu_ctrl == 1 && alu_src == 0 && reg_write == 0 && mem_write_request == 0 && mem_read == 0 && jump == 0);
        #19;

        instruction = "BNE                             ";
        op = 6'h05;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(branch == 1 && branch_cond == 1 && alu_ctrl == 1 && reg_write == 0 && jump == 0);
        #19;

        // REGIMM uses rt to distinguish BLTZ from BGEZ.
        instruction = "BLTZ                            ";
        op = 6'h01;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(branch == 1 && branch_cond == 2 && reg_write == 0 && jump == 0);
        #19;

        instruction = "BGEZ                            ";
        op = 6'h01;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd1;
        shamt = 5'd0;
        #1;
        test_controls(branch == 1 && branch_cond == 3 && reg_write == 0 && jump == 0);
        #19;

        instruction = "BLEZ                            ";
        op = 6'h06;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(branch == 1 && branch_cond == 4 && alu_ctrl == 1 && reg_write == 0 && jump == 0);
        #19;

        instruction = "BGTZ                            ";
        op = 6'h07;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(branch == 1 && branch_cond == 5 && alu_ctrl == 1 && reg_write == 0 && jump == 0);
        #19;

        // J/JAL use the instruction target. JR/JALR use rs.
        // JAL and JALR also set link to write PC + 4.
        instruction = "J                               ";
        op = 6'h02;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(jump == 1 && jump_reg == 0 && link == 0 && reg_write == 0 && branch == 0);
        #19;

        instruction = "JAL                             ";
        op = 6'h03;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(jump == 1 && jump_reg == 0 && link == 1 && reg_write == 1 && mem_to_reg == 0);
        #19;

        instruction = "JR                              ";
        op = 6'h00;
        funct = 6'h08;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(jump == 1 && jump_reg == 1 && link == 0 && reg_write == 0);
        #19;

        instruction = "JALR                            ";
        op = 6'h00;
        funct = 6'h09;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(jump == 1 && jump_reg == 1 && link == 1 && reg_write == 1 && reg_dst == 1);
        #19;

        // SRL and ROTR share funct=2; rs selects the operation.
        instruction = "SRL                             ";
        op = 6'h00;
        funct = 6'h02;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(alu_ctrl == 6 && reg_write == 1 && reg_dst == 1 && jump == 0 && jump_reg == 0);
        #19;

        instruction = "ROTR                            ";
        op = 6'h00;
        funct = 6'h02;
        rs = 5'd1;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(alu_ctrl == 8 && reg_write == 1);
        #19;

        // One valid WSBH encoding: opcode=1F, funct=20, shamt=2, rs=0.
        instruction = "WSBH                            ";
        op = 6'h1F;
        funct = 6'h20;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd2;
        #1;
        test_controls(alu_ctrl == 9 && reg_dst == 1 && reg_write == 1);
        #19;

        // One unsupported opcode: no writes, memory requests or control transfer.
        instruction = "UNSUPPORTED OPCODE              ";
        op = 6'h3F;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(reg_write == 0 && mem_read == 0 && mem_write_request == 0 && branch == 0 && jump == 0 && jump_reg == 0 && link == 0);
        #19;

        // Recognized R-type opcode with an unsupported funct value.
        instruction = "UNSUPPORTED R FUNCTION          ";
        op = 6'h00;
        funct = 6'h3F;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(reg_write == 0 && mem_read == 0 && mem_write_request == 0 && branch == 0 && jump == 0 && jump_reg == 0 && link == 0);
        #19;

        if (errors == 0) $display("PASS: %0d basic control-unit checks", checks);
        else $display("FAILED: %0d errors in %0d checks", errors, checks);
        $finish;
    end
endmodule
