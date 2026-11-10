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

    task check_reg;
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

        check_reg(8,  32'h1234_0000, "lui");
        check_reg(9,  32'h0000_0005, "addi positive");
        check_reg(10, 32'hFFFF_FFFD, "addi negative");
        check_reg(11, 32'h0000_0002, "add");
        check_reg(12, 32'h0000_0008, "sub");
        check_reg(13, 32'h0000_0005, "and");
        check_reg(14, 32'hFFFF_FFFD, "or");
        check_reg(15, 32'hFFFF_FFF8, "xor");
        check_reg(16, 32'h0000_0001, "slt");
        check_reg(17, 32'h0000_0014, "sll");
        check_reg(18, 32'h0000_000A, "srl");
        check_reg(19, 32'h0000_0002, "lw");
        check_reg(20, 32'h3412_0000, "wsbh");
        check_reg(21, 32'h0012_3400, "rotr");
        check_reg(22, 32'h0000_0001, "conditional branches");
        check_reg(26, 32'h0000_0000, "branch fall-through guard");
        check_reg(23, 32'h0000_002A, "jalr return");
        check_reg(4,  32'h0000_0007, "jalr function");
        check_reg(5,  32'h0000_0008, "jal function");
        check_reg(24, 32'h0000_008C, "jalr source");
        check_reg(25, 32'h0000_004D, "jal return");
        check_reg(31, 32'h0000_0080, "jal link address");

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
