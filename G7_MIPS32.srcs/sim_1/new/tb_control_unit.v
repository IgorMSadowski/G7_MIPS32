`timescale 1ns / 1ps

module tb_control_unit;

    reg  [5:0] op, funct;
    reg  [4:0] rs, rt, shamt;
    wire       reg_dst, alu_src, mem_to_reg, reg_write, mem_read, mem_write;
    wire       branch, jump, jump_reg, link;
    wire [3:0] branch_cond, alu_ctrl;

    // Simulation-only labels: display these signals with ASCII radix.
    // test_name identifies the stimulus; the other labels describe DUT outputs.
    reg [8*16-1:0] test_name;
    reg [8*8-1:0] branch_name, alu_operation, jump_name;
    reg [8*8-1:0] memory_action, writeback_source;
    always @(*) begin
        case (alu_ctrl)
            4'd0:  alu_operation = "ADD";
            4'd1:  alu_operation = "SUB";
            4'd2:  alu_operation = "AND";
            4'd3:  alu_operation = "OR";
            4'd4:  alu_operation = "LUI";
            4'd5:  alu_operation = "SLL";
            4'd6:  alu_operation = "SRL";
            4'd7:  alu_operation = "XOR";
            4'd8:  alu_operation = "ROTR";
            4'd9:  alu_operation = "WSBH";
            4'd10: alu_operation = "SLT";
            default: alu_operation = "UNKNOWN";
        endcase

        case (branch)
            1'b0: branch_name = "DISABLED";
            1'b1: begin
                case (branch_cond)
                    4'd0: branch_name = "BEQ";
                    4'd1: branch_name = "BNE";
                    4'd2: branch_name = "BLTZ";
                    4'd3: branch_name = "BGEZ";
                    4'd4: branch_name = "BLEZ";
                    4'd5: branch_name = "BGTZ";
                    default: branch_name = "UNKNOWN";
                endcase
            end
            default: branch_name = "UNKNOWN";
        endcase

        case ({jump, jump_reg, link})
            3'b000: jump_name = "DISABLED";
            3'b100: jump_name = "J";
            3'b101: jump_name = "JAL";
            3'b110: jump_name = "JR";
            3'b111: jump_name = "JALR";
            default: jump_name = "UNKNOWN";
        endcase

        case ({mem_read, mem_write})
            2'b00: memory_action = "NONE";
            2'b10: memory_action = "READ";
            2'b01: memory_action = "WRITE";
            2'b11: memory_action = "INVALID";
            default: memory_action = "UNKNOWN";
        endcase

        case (reg_write)
            1'b0: writeback_source = "DISABLED";
            1'b1: begin
                case (link)
                    1'b1: writeback_source = "PC+4";
                    1'b0: begin
                        case (mem_to_reg)
                            1'b0: writeback_source = "ALU";
                            1'b1: writeback_source = "MEMORY";
                            default: writeback_source = "UNKNOWN";
                        endcase
                    end
                    default: writeback_source = "UNKNOWN";
                endcase
            end
            default: writeback_source = "UNKNOWN";
        endcase
    end

    control_unit dut(
        .i_op(op), .i_rs(rs), .i_shamt(shamt), .i_rt(rt), .i_funct(funct),
        .o_reg_dst(reg_dst), .o_alu_src(alu_src),
        .o_mem_to_reg(mem_to_reg), .o_reg_write(reg_write),
        .o_mem_read(mem_read), .o_mem_write(mem_write),
        .o_branch(branch), .o_jump(jump), .o_jump_reg(jump_reg), .o_link(link),
        .o_branch_cond(branch_cond), .o_alu_ctrl(alu_ctrl)
    );

    integer errors = 0;
    integer selector;

    task test_controls;
        input [8*16-1:0] name;
        input exp_reg_dst, exp_alu_src, exp_mem_to_reg, exp_reg_write;
        input exp_mem_read, exp_mem_write, exp_branch, exp_jump, exp_jump_reg, exp_link;
        input [3:0] exp_branch_cond;
        input [3:0] exp_alu_ctrl;
        begin
            test_name = name;
            #1;
            if (reg_dst    !== exp_reg_dst    || alu_src   !== exp_alu_src   ||
                mem_to_reg !== exp_mem_to_reg || reg_write !== exp_reg_write ||
                mem_read   !== exp_mem_read   || mem_write !== exp_mem_write ||
                branch     !== exp_branch     || jump      !== exp_jump      ||
                jump_reg   !== exp_jump_reg   ||
                link       !== exp_link       || branch_cond !== exp_branch_cond ||
                alu_ctrl  !== exp_alu_ctrl) begin
                $display("FAIL %0s", name);
                $display("  got  rdst=%b asrc=%b m2r=%b rw=%b mr=%b mw=%b br=%b j=%b jr=%b lk=%b bc=%b alu=%b",
                          reg_dst, alu_src, mem_to_reg, reg_write,
                          mem_read, mem_write, branch, jump, jump_reg, link, branch_cond, alu_ctrl);
                $display("  exp  rdst=%b asrc=%b m2r=%b rw=%b mr=%b mw=%b br=%b j=%b jr=%b lk=%b bc=%b alu=%b",
                          exp_reg_dst, exp_alu_src, exp_mem_to_reg, exp_reg_write,
                          exp_mem_read, exp_mem_write, exp_branch, exp_jump, exp_jump_reg, exp_link, exp_branch_cond, exp_alu_ctrl);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        // ---- R-type (op=0), all five currently implemented ----
        op=6'h00; rs=0; rt=0; shamt=0;
        funct=6'h20; test_controls("add",  1,0,0,1, 0,0,0,0,0,0, 4'b0000, 4'b0000);
        funct=6'h22; test_controls("sub",  1,0,0,1, 0,0,0,0,0,0, 4'b0000, 4'b0001);
        funct=6'h24; test_controls("and",  1,0,0,1, 0,0,0,0,0,0, 4'b0000, 4'b0010);
        funct=6'h25; test_controls("or",   1,0,0,1, 0,0,0,0,0,0, 4'b0000, 4'b0011);
        funct=6'h2A; test_controls("slt",  1,0,0,1, 0,0,0,0,0,0, 4'b0000, 4'b1010);
        funct=6'h26; test_controls("xor",  1,0,0,1, 0,0,0,0,0,0, 4'b0000, 4'b0111);
        funct=6'h08; test_controls("jr",   1,0,0,0, 0,0,0,1,1,0, 4'b0000, 4'b0000);
        funct=6'h09; test_controls("jalr", 1,0,0,1, 0,0,0,1,1,1, 4'b0000, 4'b0000);
        funct=6'h00; test_controls("sll",  1,0,0,1, 0,0,0,0,0,0, 4'b0000, 4'b0101);
        funct=6'h02; test_controls("srl",  1,0,0,1, 0,0,0,0,0,0, 4'b0000, 4'b0110);
        rs=1; funct=6'h02; test_controls("rotr", 1,0,0,1, 0,0,0,0,0,0, 4'b0000, 4'b1000);

        // Reject every encoding with nonzero bits 25:22.
        // Only rs=0/1 match the documented SRL/ROTR encodings.
        for (selector=2; selector<32; selector=selector+1) begin
            rs=selector[4:0];
            test_controls("bad shift code", 1,0,0,0, 0,0,0,0,0,0, 4'b0000, 4'b0000);
        end

        // Unimplemented R-type functions must not write an ADD result.
        rs=0;
        for (selector=0; selector<64; selector=selector+1) begin
            funct=selector[5:0];
            case (funct)
                6'h00, 6'h02, 6'h08, 6'h09, 6'h20, 6'h22,
                6'h24, 6'h25, 6'h26, 6'h2A: begin end
                default:
                    test_controls("unknown R funct", 1,0,0,0, 0,0,0,0,0,0, 4'b0000, 4'b0000);
            endcase
        end

        // ---- I-type ----
        funct=0; rs=0; rt=0;
        op=6'h08; test_controls("addi", 0,1,0,1, 0,0,0,0,0,0, 4'b0000, 4'b0000);
        op=6'h0F; test_controls("lui",  0,1,0,1, 0,0,0,0,0,0, 4'b0000, 4'b0100);
        op=6'h23; test_controls("lw",   0,1,1,1, 1,0,0,0,0,0, 4'b0000, 4'b0000);
        op=6'h2B; test_controls("sw",   0,1,0,0, 0,1,0,0,0,0, 4'b0000, 4'b0000);
        op=6'h04; test_controls("beq",  0,0,0,0, 0,0,1,0,0,0, 4'b0000, 4'b0001);
        op=6'h05; test_controls("bne",  0,0,0,0, 0,0,1,0,0,0, 4'b0001, 4'b0001);

        // bltz / bgez: op=1, rt selects variant
        op=6'h01;
        rt=5'b00000; test_controls("bltz", 0,0,0,0, 0,0,1,0,0,0, 4'b0010, 4'b0000);
        rt=5'b00001; test_controls("bgez", 0,0,0,0, 0,0,1,0,0,0, 4'b0011, 4'b0000);
        for (selector=2; selector<32; selector=selector+1) begin
            rt=selector[4:0];
            test_controls("REGIMM no branch", 0,0,0,0, 0,0,0,0,0,0, 4'b0000, 4'b0000);
        end
        rt=0;
        op=6'h07; test_controls("bgtz", 0,0,0,0, 0,0,1,0,0,0, 4'b0101, 4'b0001);
        op=6'h06; test_controls("blez", 0,0,0,0, 0,0,1,0,0,0, 4'b0100, 4'b0001);

        // ---- J-type ----
        rs=0; rt=0;
        op=6'h02; test_controls("j",   0,0,0,0, 0,0,0,1,0,0, 4'b0000, 4'b0000);
        op=6'h03; test_controls("jal", 0,0,0,1, 0,0,0,1,0,1, 4'b0000, 4'b0000);

        // ---- SPECIAL3 ----
        op=6'h1F; funct=6'h20; shamt=2;
        test_controls("wsbh", 1,0,0,1, 0,0,0,0,0,0, 4'b0000, 4'b1001);

        // Fixed WSBH fields must match its MIPS32 encoding.
        shamt=0;
        test_controls("wsbh bad shamt", 0,0,0,0, 0,0,0,0,0,0, 4'b0000, 4'b0000);
        shamt=2; rs=1;
        test_controls("wsbh bad rs", 0,0,0,0, 0,0,0,0,0,0, 4'b0000, 4'b0000);
        rs=0; funct=6'h21;
        test_controls("wsbh bad funct", 0,0,0,0, 0,0,0,0,0,0, 4'b0000, 4'b0000);

        $display("--- %0d errors ---", errors);
        if (errors==0) $display("PASS"); else $display("FAILED");
        $finish;
    end
endmodule
