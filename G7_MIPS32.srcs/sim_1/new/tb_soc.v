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
        // test.asm ends with "j end" (jump to itself) -> PC stops advancing.
        cycles  = 0;
        pc_prev = 32'hFFFFFFFF;   // impossible value, forces first iteration
        while (dut._pc !== pc_prev) begin
            @(posedge clk);
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
        // Each check covers one instruction family from test.asm.

        // addiu: $t0 = 5
        if (dut.u_cpu.u_dp.registers._rf[8] !== 32'h5) begin
            $display("FAIL: $t0 = %h, expected 5 (addiu)",
                     dut.u_cpu.u_dp.registers._rf[8]);
            errors = errors + 1;
        end
        // addiu: $t1 = 3
        if (dut.u_cpu.u_dp.registers._rf[9] !== 32'h3) begin
            $display("FAIL: $t1 = %h, expected 3 (addiu)",
                     dut.u_cpu.u_dp.registers._rf[9]);
            errors = errors + 1;
        end
        // add: $t2 = 8
        if (dut.u_cpu.u_dp.registers._rf[10] !== 32'h8) begin
            $display("FAIL: $t2 = %h, expected 8 (add)",
                     dut.u_cpu.u_dp.registers._rf[10]);
            errors = errors + 1;
        end
        // slt: $s4 = 1 (3 < 5)
        if (dut.u_cpu.u_dp.registers._rf[20] !== 32'h1) begin
            $display("FAIL: $s4 = %h, expected 1 (slt)",
                     dut.u_cpu.u_dp.registers._rf[20]);
            errors = errors + 1;
        end
        // lw/sw roundtrip: $s5 = 8 (Mem[0] written by sw, read by lw)
        if (dut.u_cpu.u_dp.registers._rf[21] !== 32'h8) begin
            $display("FAIL: $s5 = %h, expected 8 (lw after sw)",
                     dut.u_cpu.u_dp.registers._rf[21]);
            errors = errors + 1;
        end
        // blez not taken + addiu executed: $s6 = 100
        if (dut.u_cpu.u_dp.registers._rf[22] !== 32'h64) begin
            $display("FAIL: $s6 = %h, expected 0x64 (blez fallthrough)",
                     dut.u_cpu.u_dp.registers._rf[22]);
            errors = errors + 1;
        end
        // jal + jr: $s7 = 42 (runs only if jal jumped and jr returned)
        if (dut.u_cpu.u_dp.registers._rf[23] !== 32'h2A) begin
            $display("FAIL: $s7 = %h, expected 0x2A (jal/jr)",
                     dut.u_cpu.u_dp.registers._rf[23]);
            errors = errors + 1;
        end
        // function body executed: $a0 = 7 (written inside func)
        if (dut.u_cpu.u_dp.registers._rf[4] !== 32'h7) begin
            $display("FAIL: $a0 = %h, expected 7 (function body)",
                     dut.u_cpu.u_dp.registers._rf[4]);
            errors = errors + 1;
        end

        $display("\n--- %0d errors ---", errors);
        if (errors == 0) $display("PASS"); else $display("FAILED");
        $finish;
    end

endmodule