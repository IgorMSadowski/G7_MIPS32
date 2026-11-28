`timescale 1ns / 1ps

// Feed the instruction fields directly and check the control outputs.
// Covers the 24 G7 instructions and two unsupported encodings.
module tb_control_unit;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg en = 1'b0;
    reg [31:0] rs_value = 32'b0;
    reg equal = 1'b0;
    reg [5:0] op = 0, funct = 0;
    reg [4:0] rs = 0, rt = 0, shamt = 0;
    wire reg_dst, alu_src, mem_to_reg, reg_write, mem_read, mem_write;
    wire branch, jump, jump_reg, link;
    wire [3:0] branch_cond, alu_ctrl;
    wire alu_a_shamt, link_to_ra;
    wire [1:0] pc_sel;
    wire rf_we, load_issue, store_commit, imem_en, commit;
    integer errors = 0;
    integer checks = 0;

    reg [255:0] instruction;
    reg [63:0] alu_operation, writeback_source, branch_name;

    // 50 MHz test clock. Inputs are changed between active clock edges.
    always #10 clk = ~clk;

    control_unit dut (
        .i_clk(clk), .i_rst(rst), .i_en(en),
        .i_rs_value(rs_value), .i_equal(equal),
        .i_op(op), .i_funct(funct), .i_rs(rs), .i_rt(rt), .i_shamt(shamt),
        .o_reg_dst(reg_dst), .o_alu_src(alu_src),
        .o_mem_to_reg(mem_to_reg), .o_reg_write(reg_write),
        .o_mem_read(mem_read), .o_mem_write(mem_write),
        .o_branch(branch), .o_branch_cond(branch_cond),
        .o_jump(jump), .o_jump_reg(jump_reg), .o_link(link),
        .o_alu_ctrl(alu_ctrl), .o_alu_a_shamt(alu_a_shamt),
        .o_link_to_ra(link_to_ra), .o_pc_sel(pc_sel),
        .o_rf_we(rf_we), .o_load_issue(load_issue),
        .o_store_commit(store_commit), .o_imem_en(imem_en), .o_commit(commit)
    );

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
        reg failed;
        begin
            checks = checks + 1;
            failed = 1'b0;
            if (condition !== 1'b1) begin
                failed = 1'b1;
                $display("FAIL: %0s", instruction);
            end

            // LW verification
            if (en && !rst && dut._rom_ready) begin
                if (mem_read && !dut._load_pending) begin
                    if (!(load_issue && !commit && !rf_we && !imem_en && !store_commit)) begin
                        failed = 1'b1;
                        $display("FAIL: %0s - LW issue/stall controls", instruction);
                    end
                end else if (!(commit && !load_issue && imem_en && rf_we == reg_write && store_commit == mem_write)) begin
                    failed = 1'b1;
                    $display("FAIL: %0s - instruction commit controls", instruction);
                end
            end

            if (failed)
                errors = errors + 1;
        end
    endtask

    initial begin
        // One reset edge, then enable execution. Prime the synchronous fetch
        // before treating the first presented instruction as executable.
        @(posedge clk);
        #1;
        rst = 1'b0;
        en = 1'b1;
        @(negedge clk);

        // Register arithmetic: destination rd, two register operands.
        instruction = "ADD                             ";
        op = 6'h00;
        funct = 6'h20;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(imem_en == 1 && commit == 0 && load_issue == 0);
        @(posedge clk); #1;
        test_controls(reg_dst == 1 && reg_write == 1 && alu_src == 0 && alu_ctrl == 0 && alu_a_shamt == 0);
        @(posedge clk); #1;

        instruction = "SUB                             ";
        op = 6'h00;
        funct = 6'h22;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(reg_dst == 1 && reg_write == 1 && alu_ctrl == 1);
        @(posedge clk); #1;

        instruction = "AND                             ";
        op = 6'h00;
        funct = 6'h24;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(reg_dst == 1 && reg_write == 1 && alu_ctrl == 2);
        @(posedge clk); #1;

        instruction = "OR                              ";
        op = 6'h00;
        funct = 6'h25;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(reg_dst == 1 && reg_write == 1 && alu_ctrl == 3);
        @(posedge clk); #1;

        instruction = "XOR                             ";
        op = 6'h00;
        funct = 6'h26;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(reg_dst == 1 && reg_write == 1 && alu_ctrl == 7);
        @(posedge clk); #1;

        instruction = "SLT                             ";
        op = 6'h00;
        funct = 6'h2A;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(reg_dst == 1 && reg_write == 1 && alu_ctrl == 10);
        @(posedge clk); #1;

        instruction = "SLL                             ";
        op = 6'h00;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(reg_dst == 1 && reg_write == 1 && alu_ctrl == 5 && alu_a_shamt == 1);
        @(posedge clk); #1;

        // Immediate arithmetic: destination rt, immediate operand.
        instruction = "ADDI                            ";
        op = 6'h08;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(reg_dst == 0 && reg_write == 1 && alu_src == 1 && alu_ctrl == 0);
        @(posedge clk); #1;

        instruction = "LUI                             ";
        op = 6'h0F;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(reg_dst == 0 && reg_write == 1 && alu_src == 1 && alu_ctrl == 4 && mem_to_reg == 0);
        @(posedge clk); #1;

        // Load writes RAM data to a register; store only writes memory.
        instruction = "LW                              ";
        op = 6'h23;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(mem_read == 1 && mem_write == 0 && reg_write == 1 && mem_to_reg == 1 && reg_dst == 0 && alu_src == 1 && alu_ctrl == 0);
        @(posedge clk); #1;
        test_controls(load_issue == 0 && commit == 1 && imem_en == 1 && rf_we == 1 && store_commit == 0);
        @(posedge clk); #1;

        instruction = "SW                              ";
        op = 6'h2B;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(mem_write == 1 && mem_read == 0 && reg_write == 0 && alu_src == 1 && alu_ctrl == 0);
        @(posedge clk); #1;

        // BEQ selects the equality condition. The datapath compares rs and rt.
        instruction = "BEQ                             ";
        op = 6'h04; funct = 6'h00; rs = 5'd0; rt = 5'd0; shamt = 5'd0;
        equal = 1'b1;
        #1;
        test_controls(branch == 1 && branch_cond == 0 && alu_ctrl == 1 && alu_src == 0 && reg_write == 0 && mem_write == 0 && mem_read == 0 && jump == 0);
        // Check only that the CU's PC-select output receives a taken result.
        // Detailed condition behavior remains covered by tb_bdu.
        test_controls(pc_sel == 2'd1);
        equal = 1'b0;
        #1;
        test_controls(pc_sel == 2'd0);
        @(posedge clk); #1;

        instruction = "BNE                             ";
        op = 6'h05;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(branch == 1 && branch_cond == 1 && alu_ctrl == 1 && reg_write == 0 && jump == 0);
        @(posedge clk); #1;

        // REGIMM uses rt to distinguish BLTZ from BGEZ.
        instruction = "BLTZ                            ";
        op = 6'h01;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(branch == 1 && branch_cond == 2 && reg_write == 0 && jump == 0);
        @(posedge clk); #1;

        instruction = "BGEZ                            ";
        op = 6'h01;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd1;
        shamt = 5'd0;
        #1;
        test_controls(branch == 1 && branch_cond == 3 && reg_write == 0 && jump == 0);
        @(posedge clk); #1;

        instruction = "BLEZ                            ";
        op = 6'h06;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(branch == 1 && branch_cond == 4 && alu_ctrl == 1 && reg_write == 0 && jump == 0);
        @(posedge clk); #1;

        instruction = "BGTZ                            ";
        op = 6'h07;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(branch == 1 && branch_cond == 5 && alu_ctrl == 1 && reg_write == 0 && jump == 0);
        @(posedge clk); #1;

        // J/JAL use the instruction target. JR/JALR use rs.
        // JAL and JALR also set link to write PC + 4.
        instruction = "J                               ";
        op = 6'h02;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(jump == 1 && jump_reg == 0 && link == 0 && reg_write == 0 && branch == 0 && pc_sel == 2'd2 && link_to_ra == 0);
        @(posedge clk); #1;

        instruction = "JAL                             ";
        op = 6'h03;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(jump == 1 && jump_reg == 0 && link == 1 && reg_write == 1 && mem_to_reg == 0 && pc_sel == 2'd2 && link_to_ra == 1);
        @(posedge clk); #1;

        instruction = "JR                              ";
        op = 6'h00;
        funct = 6'h08;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(jump == 1 && jump_reg == 1 && link == 0 && reg_write == 0 && pc_sel == 2'd3 && link_to_ra == 0);
        @(posedge clk); #1;

        instruction = "JALR                            ";
        op = 6'h00;
        funct = 6'h09;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(jump == 1 && jump_reg == 1 && link == 1 && reg_write == 1 && reg_dst == 1 && pc_sel == 2'd3 && link_to_ra == 0);
        @(posedge clk); #1;

        // SRL and ROTR share funct=2; rs selects the operation.
        instruction = "SRL                             ";
        op = 6'h00;
        funct = 6'h02;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(alu_ctrl == 6 && reg_write == 1 && reg_dst == 1 && jump == 0 && jump_reg == 0 && alu_a_shamt == 1);
        @(posedge clk); #1;

        instruction = "ROTR                            ";
        op = 6'h00;
        funct = 6'h02;
        rs = 5'd1;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(alu_ctrl == 8 && reg_write == 1 && alu_a_shamt == 1);
        @(posedge clk); #1;

        // One valid WSBH encoding: opcode=1F, funct=20, shamt=2, rs=0.
        instruction = "WSBH                            ";
        op = 6'h1F;
        funct = 6'h20;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd2;
        #1;
        test_controls(alu_ctrl == 9 && reg_dst == 1 && reg_write == 1 && alu_a_shamt == 0);
        @(posedge clk); #1;

        // One unsupported opcode: no writes, memory requests or control transfer.
        instruction = "UNSUPPORTED OPCODE              ";
        op = 6'h3F;
        funct = 6'h00;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(reg_write == 0 && mem_read == 0 && mem_write == 0 && branch == 0 && jump == 0 && jump_reg == 0 && link == 0);
        @(posedge clk); #1;

        // Recognized R-type opcode with an unsupported funct value.
        instruction = "UNSUPPORTED R FUNCTION          ";
        op = 6'h00;
        funct = 6'h3F;
        rs = 5'd0;
        rt = 5'd0;
        shamt = 5'd0;
        #1;
        test_controls(reg_write == 0 && mem_read == 0 && mem_write == 0 && branch == 0 && jump == 0 && jump_reg == 0 && link == 0);
        @(posedge clk); #1;

        en = 1'b0;

        if (errors == 0) $display("PASS: %0d control-unit checks", checks);
        else $display("FAILED: %0d errors in %0d checks", errors, checks);
        $finish;
    end
endmodule
