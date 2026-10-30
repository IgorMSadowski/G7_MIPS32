`timescale 1ns / 1ps

module tb_control_unit;

    reg  [5:0] op, funct;
    reg  [4:0] rs, rt;
    wire       reg_dst, alu_src, mem_to_reg, reg_write, mem_read, mem_write;
    wire       branch, jump, jump_reg, link;
    wire [3:0] branch_cond, alu_ctrl;

    control_unit dut(
        .i_op(op), .i_rs(rs), .i_rt(rt), .i_funct(funct),
        .o_reg_dst(reg_dst), .o_alu_src(alu_src),
        .o_mem_to_reg(mem_to_reg), .o_reg_write(reg_write),
        .o_mem_read(mem_read), .o_mem_write(mem_write),
        .o_branch(branch), .o_jump(jump), .o_jump_reg(jump_reg), .o_link(link),
        .o_branch_cond(branch_cond), .o_alu_ctrl(alu_ctrl)
    );

    integer errors = 0;

    task expect;
        input [8*16-1:0] name;
        input exp_reg_dst, exp_alu_src, exp_mem_to_reg, exp_reg_write;
        input exp_mem_read, exp_mem_write, exp_branch, exp_jump, exp_jump_reg, exp_link;
        input [3:0] exp_branch_cond;
        input [3:0] exp_alu_ctrl;
        begin
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
        op=6'h00; rs=0; rt=0;
        funct=6'h20; expect("add",  1,0,0,1, 0,0,0,0,0,0, 4'b0000, 4'b0010);
        funct=6'h22; expect("sub",  1,0,0,1, 0,0,0,0,0,0, 4'b0000, 4'b0110);
        funct=6'h24; expect("and",  1,0,0,1, 0,0,0,0,0,0, 4'b0000, 4'b0000);
        funct=6'h25; expect("or",   1,0,0,1, 0,0,0,0,0,0, 4'b0000, 4'b0001);
        funct=6'h2A; expect("slt",  1,0,0,1, 0,0,0,0,0,0, 4'b0000, 4'b0111);
        funct=6'h08; expect("jr",   1,0,0,0, 0,0,0,1,1,0, 4'b0000, 4'b0010);
        funct=6'h09; expect("jalr", 1,0,0,1, 0,0,0,1,1,1, 4'b0000, 4'b0010);
        funct=6'h00; expect("sll",  1,0,0,1, 0,0,0,0,0,0, 4'b0000, 4'b1001);
        funct=6'h02; expect("srl",  1,0,0,1, 0,0,0,0,0,0, 4'b0000, 4'b1010);
        rs=1; funct=6'h02; expect("rotr", 1,0,0,1, 0,0,0,0,0,0, 4'b0000, 4'b1101);

        // ---- I-type ----
        funct=0; rs=0; rt=0;
        op=6'h08; expect("addi", 0,1,0,1, 0,0,0,0,0,0, 4'b0000, 4'b0010);
        op=6'h0F; expect("lui",  0,1,0,1, 0,0,0,0,0,0, 4'b0000, 4'b1000);
        op=6'h23; expect("lw",   0,1,1,1, 1,0,0,0,0,0, 4'b0000, 4'b0010);
        op=6'h2B; expect("sw",   0,1,0,0, 0,1,0,0,0,0, 4'b0000, 4'b0010);
        op=6'h04; expect("beq",  0,0,0,0, 0,0,1,0,0,0, 4'b0000, 4'b0110);
        op=6'h05; expect("bne",  0,0,0,0, 0,0,1,0,0,0, 4'b0001, 4'b0110);

        // bltz / bgez: op=1, rt selects variant
        op=6'h01;
        rt=5'b00000; expect("bltz", 0,0,0,0, 0,0,1,0,0,0, 4'b0010, 4'b0010);
        rt=5'b00001; expect("bgez", 0,0,0,0, 0,0,1,0,0,0, 4'b0011, 4'b0010);
        op=6'h07; expect("bgtz", 0,0,0,0, 0,0,1,0,0,0, 4'b0111, 4'b0110);
        op=6'h06; expect("blez", 0,0,0,0, 0,0,1,0,0,0, 4'b0110, 4'b0110);

        // ---- J-type ----
        rs=0; rt=0;
        op=6'h02; expect("j",   0,0,0,0, 0,0,0,1,0,0, 4'b0000, 4'b0010);
        op=6'h03; expect("jal", 0,0,0,1, 0,0,0,1,0,1, 4'b0000, 4'b0010);

        // ---- SPECIAL3 ----
        op=6'h1F; funct=6'h20;
        expect("wsbh", 1,0,0,1, 0,0,0,0,0,0, 4'b0000, 4'b1100);

        $display("--- %0d errors ---", errors);
        if (errors==0) $display("PASS"); else $display("FAILED");
        $finish;
    end
endmodule