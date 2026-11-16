`timescale 1ns / 1ps

// Basic CPU + RAM test. The testbench supplies four instructions directly.
// There is no ROM here: hold LW until the CPU finishes its load.
module tb_cpu_memory;
    reg clk = 0;
    reg rst = 1;
    reg en = 0;
    reg [31:0] instr = 0;
    wire [31:0] rdata, wdata, pc, addr;
    wire re, we, imem_en;
    integer errors = 0;
    integer checks = 0;
    reg [8*32-1:0] test_name;
    reg [8*20-1:0] memory_phase;

    // 50 MHz. Drive and inspect signals 1 ns after rising edges.
    // This is a testbench scheduling delay, not measured FPGA timing.
    always #10 clk = ~clk;

    cpu dut (
        .i_clk(clk), .i_rst(rst), .i_en(en),
        .i_instr(instr), .i_rdata(rdata),
        .o_wdata(wdata), .o_pc(pc), .o_imem_en(imem_en),
        .o_alu_out(addr), .o_mem_read(re), .o_mem_write(we)
    );

    data_memory dm (
        .i_clk(clk), .i_rst(rst), .i_en(en),
        .i_addr(addr), .i_wdata(wdata),
        .i_re(re), .i_we(we), .o_rdata(rdata)
    );

    // Readable waveform signals for the three registers used by this test.
    wire [31:0] t0_value = dut.u_dp.registers._rf[8];
    wire [31:0] t1_value = dut.u_dp.registers._rf[9];
    wire [31:0] t2_value = dut.u_dp.registers._rf[10];

    task test_cpu_state(input condition, input [8*64-1:0] name);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL: %0s", name);
            end
        end
    endtask

    initial begin
        test_name = "RESET                           ";
        memory_phase = "RESET               ";
        repeat (2) @(posedge clk); #1;
        test_cpu_state(dut.u_dp._pc_r === 0 && re === 0 && we === 0 &&
                       t0_value === 0 && t1_value === 0 && t2_value === 0,
                       "reset clears PC/registers and blocks memory requests");

        // Allow the CPU's initial fetch-preparation cycle.
        rst = 0;
        en = 1;
        test_name = "STARTUP                         ";
        memory_phase = "STARTUP             ";
        @(posedge clk); #1;
        test_cpu_state(dut.u_dp._pc_r === 0 && dut.u_dp._rom_ready === 1,
                       "startup prepares the CPU without advancing current PC");

        // PC 0x00: addi $t0, $zero, 5 -> t0 = 5.
        instr = 32'h20080005;
        test_name = "ADDI t0, zero, 5                ";
        memory_phase = "PREPARE VALUE       ";
        @(posedge clk); #1;
        test_cpu_state(t0_value === 5 && dut.u_dp._pc_r === 4,
                       "ADDI prepares t0 = 5 and advances PC to 4");

        // PC 0x04: sw $t0, 0($zero) -> RAM[0] = 5.
        instr = 32'hAC080000;
        test_name = "SW t0, 0(zero)                  ";
        memory_phase = "STORE               ";
        #1;
        test_cpu_state(we === 1 && re === 0 && addr === 0 && wdata === 5,
                       "SW requests a write of 5 at RAM address zero");
        @(posedge clk); #1;

        // PC 0x08: lw $t1, 0($zero). Keep this instruction for BOTH edges.
        instr = 32'h8C090000;
        test_name = "LW t1, 0(zero)                  ";
        memory_phase = "LOAD WAIT           ";
        #1;
        test_cpu_state(dut.u_dp._stall === 1 && dut._commit === 0 &&
                       imem_en === 0 && re === 1 && we === 0 && addr === 0 &&
                       dut.u_dp._pc_r === 8 && pc === 8,
                       "LW stalls, holds PC/ROM and issues the RAM read");

        // First edge: RAM returns data, but the CPU has not written t1 yet.
        @(posedge clk); #1;
        memory_phase = "LOAD WRITEBACK      ";
        test_cpu_state(rdata === 5 && t1_value === 0 &&
                       dut.u_dp._pc_r === 8 && dut.u_dp._load_pending === 1 &&
                       re === 0 && dut._commit === 1 && imem_en === 1,
                       "RAM data is ready while current PC and t1 still hold");

        // Second edge: the same LW writes t1 and advances current PC.
        @(posedge clk); #1;
        test_cpu_state(t1_value === 5 && dut.u_dp._pc_r === 12 &&
                       dut.u_dp._load_pending === 0,
                       "LW writes t1 = 5 and advances PC to 12");

        // PC 0x0C: addi $t2, $t1, 1 -> t2 = 6, using the loaded value.
        instr = 32'h212A0001;
        test_name = "ADDI t2, t1, 1                  ";
        memory_phase = "RESUME              ";
        @(posedge clk); #1;
        test_cpu_state(t2_value === 6 && dut.u_dp._pc_r === 16,
                       "execution resumes and uses the loaded value: t2 = 6");

        // Stop execution so the last values remain visible on the waveform.
        en = 0;
        test_name = "FINISHED                        ";
        memory_phase = "DONE                ";
        #20;
        if (errors == 0) $display("PASS: %0d basic CPU/memory checks", checks);
        else $display("FAILED: %0d errors in %0d checks", errors, checks);
        $finish;
    end

    initial begin
        #1000;
        errors = errors + 1;
        $display("FAIL: CPU/memory test timeout");
        $finish;
    end
endmodule
