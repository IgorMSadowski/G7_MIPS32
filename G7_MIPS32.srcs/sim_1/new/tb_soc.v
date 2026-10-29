`timescale 1ns / 1ps

module tb_soc;

    reg         clk, rst;
    wire [0:0]  led;

    soc dut(.i_clk(clk), .i_rst(rst), .o_led(led));

    always #5 clk = ~clk;

    integer    cycles;
    integer    errors = 0;
    integer    i;
    reg [31:0] pc_prev;

    initial begin : wait_for_halt
        rst = 1;
        #20;
        rst = 0;

        // ---- run until PC stabilizes (halt) ----
        // test.asm ends with "end: j end" -> PC stays put.
        cycles  = 0;
        pc_prev = 32'hFFFFFFFF;   // impossible value, forces first iteration
        while (dut._pc !== pc_prev) begin
            @(posedge clk);
            #1;                  
            cycles  = cycles + 1;
            pc_prev = dut._pc;

            if (cycles > 10000) begin
                $display("TIMEOUT after %0d cycles (PC=%h) - program did not halt",
                         cycles, dut._pc);
                $finish;
            end
        end
        $display("Halt detected at cycle %0d (PC=%h)", cycles, dut._pc);

        // ---- dump the register file ----
        $display("\n=== Register File ===");
        for (i = 0; i < 32; i = i + 1)
            $display("r%0d = %h", i, dut.u_cpu.u_dp.registers._rf[i]);

        // ---- automated checks ----
        // One check per instruction family, matches test.asm.

        // addiu: $t0 = 5
        if (dut.u_cpu.u_dp.registers._rf[8] !== 32'h5) begin
            $display("FAIL: $t0 = %h, expected 5 (addiu)", dut.u_cpu.u_dp.registers._rf[8]);
            errors = errors + 1;
        end
        // addiu: $t1 = 3
        if (dut.u_cpu.u_dp.registers._rf[9] !== 32'h3) begin
            $display("FAIL: $t1 = %h, expected 3 (addiu)", dut.u_cpu.u_dp.registers._rf[9]);
            errors = errors + 1;
        end
        // add: $t2 = 8
        if (dut.u_cpu.u_dp.registers._rf[10] !== 32'h8) begin
            $display("FAIL: $t2 = %h, expected 8 (add)", dut.u_cpu.u_dp.registers._rf[10]);
            errors = errors + 1;
        end
        // addu: $t3 = 8
        if (dut.u_cpu.u_dp.registers._rf[11] !== 32'h8) begin
            $display("FAIL: $t3 = %h, expected 8 (addu)", dut.u_cpu.u_dp.registers._rf[11]);
            errors = errors + 1;
        end
        // sub: $t4 = 5
        if (dut.u_cpu.u_dp.registers._rf[12] !== 32'h5) begin
            $display("FAIL: $t4 = %h, expected 5 (sub)", dut.u_cpu.u_dp.registers._rf[12]);
            errors = errors + 1;
        end
        // subu: $t5 = 5
        if (dut.u_cpu.u_dp.registers._rf[13] !== 32'h5) begin
            $display("FAIL: $t5 = %h, expected 5 (subu)", dut.u_cpu.u_dp.registers._rf[13]);
            errors = errors + 1;
        end
        // and: $t6 = 1
        if (dut.u_cpu.u_dp.registers._rf[14] !== 32'h1) begin
            $display("FAIL: $t6 = %h, expected 1 (and)", dut.u_cpu.u_dp.registers._rf[14]);
            errors = errors + 1;
        end
        // or: $t7 = 7
        if (dut.u_cpu.u_dp.registers._rf[15] !== 32'h7) begin
            $display("FAIL: $t7 = %h, expected 7 (or)", dut.u_cpu.u_dp.registers._rf[15]);
            errors = errors + 1;
        end
        // xor: $s0 = 6 (5 ^ 3)
        if (dut.u_cpu.u_dp.registers._rf[16] !== 32'h6) begin
            $display("FAIL: $s0 = %h, expected 6 (xor)", dut.u_cpu.u_dp.registers._rf[16]);
            errors = errors + 1;
        end
        // nor: $s1 = 0xFFFFFFF8
        if (dut.u_cpu.u_dp.registers._rf[17] !== 32'hFFFFFFF8) begin
            $display("FAIL: $s1 = %h, expected 0xFFFFFFF8 (nor)", dut.u_cpu.u_dp.registers._rf[17]);
            errors = errors + 1;
        end
        // sll: $s2 = 20 (5 << 2)
        if (dut.u_cpu.u_dp.registers._rf[18] !== 32'h14) begin
            $display("FAIL: $s2 = %h, expected 0x14=20 (sll)", dut.u_cpu.u_dp.registers._rf[18]);
            errors = errors + 1;
        end
        // srl: $s3 = 10 (20 >> 1) — kept untouched by save_test now
        if (dut.u_cpu.u_dp.registers._rf[19] !== 32'hA) begin
            $display("FAIL: $s3 = %h, expected 0xA=10 (srl)", dut.u_cpu.u_dp.registers._rf[19]);
            errors = errors + 1;
        end
        // slt: $s4 = 1 (3 < 5)
        if (dut.u_cpu.u_dp.registers._rf[20] !== 32'h1) begin
            $display("FAIL: $s4 = %h, expected 1 (slt)", dut.u_cpu.u_dp.registers._rf[20]);
            errors = errors + 1;
        end
        // lw/sw roundtrip: $s5 = 8
        if (dut.u_cpu.u_dp.registers._rf[21] !== 32'h8) begin
            $display("FAIL: $s5 = %h, expected 8 (lw after sw)", dut.u_cpu.u_dp.registers._rf[21]);
            errors = errors + 1;
        end
        // blez not taken + addiu executed: $s6 = 100 (0x64)
        if (dut.u_cpu.u_dp.registers._rf[22] !== 32'h64) begin
            $display("FAIL: $s6 = %h, expected 0x64=100 (blez fallthrough)", dut.u_cpu.u_dp.registers._rf[22]);
            errors = errors + 1;
        end
        // jal + jr: $s7 = 42 (0x2A)
        if (dut.u_cpu.u_dp.registers._rf[23] !== 32'h2A) begin
            $display("FAIL: $s7 = %h, expected 0x2A=42 (jal/jr)", dut.u_cpu.u_dp.registers._rf[23]);
            errors = errors + 1;
        end
        // function body executed: $a0 = 7
        if (dut.u_cpu.u_dp.registers._rf[4] !== 32'h7) begin
            $display("FAIL: $a0 = %h, expected 7 (function body)", dut.u_cpu.u_dp.registers._rf[4]);
            errors = errors + 1;
        end
        // save/restore: $t8 = 77 (0x4D) — preserved by save_test through the stack
        if (dut.u_cpu.u_dp.registers._rf[24] !== 32'h4D) begin
            $display("FAIL: $t8 = %h, expected 0x4D=77 (save/restore)", dut.u_cpu.u_dp.registers._rf[24]);
            errors = errors + 1;
        end

        $display("\n--- %0d errors ---", errors);
        if (errors == 0) $display("PASS"); else $display("FAILED");
        $finish;
    end

endmodule