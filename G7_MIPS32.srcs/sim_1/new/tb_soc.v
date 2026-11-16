`timescale 1ns / 1ps

module tb_soc;

    reg         clk, rst;
    wire [0:0]  led;
    reg [8*24-1:0] test_name;
    reg [8*16-1:0] cpu_phase;

    soc #(
        .IMEM_INIT_FILE("/home/igor/Documents/Vivado_Projects/G7_MIPS32/Assembly/test.mem")
    ) dut(
        .i_clk(clk), .i_rst(rst), .o_led(led)
    );

    always #4 clk = ~clk; // Zybo board clock: 125 MHz

    integer cycles;
    integer errors = 0;

    always @(posedge dut.clk_50mhz) begin : check_rom_hold
        reg [31:0] held_instr, held_pc;
        if (dut._mem_read) begin
            held_instr = dut._instr;
            held_pc = dut.u_cpu.u_dp._pc_r;
            #1;
            if (dut._instr !== held_instr || dut.u_cpu.u_dp._pc_r !== held_pc) begin
                $display("FAIL: PC or ROM advanced before LW write-back");
                errors = errors + 1;
            end
        end
    end

    task test_register;
        input [4:0] index;
        input [31:0] expected;
        input [8*32-1:0] name;
        begin
            if (dut.u_cpu.u_dp.registers._rf[index] !== expected) begin
                $display("FAIL %0s: r%0d = %h, expected %h",
                         name, index, dut.u_cpu.u_dp.registers._rf[index], expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        clk = 0;
        rst = 1;
        test_name = "RUN ROM REGRESSION";
        cpu_phase = "RESET";
        repeat (3) @(negedge clk);
        rst = 0;
        wait (dut.soc_reset === 1'b0);
        cpu_phase = "EXECUTE";

        // The assembled test program ends in the self-loop at address 0x9C.
        cycles = 0;
        while (dut._pc !== 32'h0000_009C) begin
            @(posedge dut.clk_50mhz);
            #1;
            cycles = cycles + 1;
            if (cycles > 500) begin
                errors = errors + 1;
                $display("TIMEOUT: program did not reach halt loop (PC=%h)", dut._pc);
                $finish;
            end
        end
        repeat (4) @(posedge dut.clk_50mhz);
        #1;
        cpu_phase = "CHECK RESULTS";

        test_register(8,  32'h1234_0000, "lui");
        test_register(9,  32'h0000_0005, "addi positive");
        test_register(10, 32'hFFFF_FFFD, "addi negative");
        test_register(11, 32'h0000_0002, "add");
        test_register(12, 32'h0000_0008, "sub");
        test_register(13, 32'h0000_0005, "and");
        test_register(14, 32'hFFFF_FFFD, "or");
        test_register(15, 32'hFFFF_FFF8, "xor");
        test_register(16, 32'h0000_0001, "slt");
        test_register(17, 32'h0000_0014, "sll");
        test_register(18, 32'h0000_000A, "srl");
        test_register(19, 32'h0000_0002, "lw");
        test_register(20, 32'h3412_0000, "wsbh");
        test_register(21, 32'h0012_3400, "rotr");
        test_register(22, 32'h0000_0001, "conditional branches");
        test_register(26, 32'h0000_0000, "branch fall-through guard");
        test_register(23, 32'h0000_002A, "jalr return");
        test_register(4,  32'h0000_0007, "jalr function");
        test_register(5,  32'h0000_0008, "jal function");
        test_register(24, 32'h0000_008C, "jalr source");
        test_register(25, 32'h0000_004D, "jal return");
        test_register(31, 32'h0000_0080, "jal link address");

        if (errors != 0) begin
            $display("FAILED: %0d register checks failed", errors);
            $finish;
        end
        $display("PASS: all assembled instructions reached the halt loop with expected results");
        $finish;
    end

    // Catch a clock that never locks or stops running.
    initial begin
        #100_000;
        errors = errors + 1;
        $display("FAIL: SoC simulation timeout (clock_locked=%b, soc_reset=%b)",
                 dut.clock_locked, dut.soc_reset);
        $finish;
    end
endmodule
