`timescale 1ns / 1ps

module tb_soc_mmio;
    reg clk = 0;
    reg rst = 1;
    reg [3:0] switches = 4'b1010;
    reg [3:1] buttons = 3'b101;
    wire [3:0] leds;
    reg [8*28-1:0] test_name;
    reg [8*20-1:0] system_phase;
    integer errors = 0;
    integer cycles = 0;
    integer dmem_reads = 0;
    integer dmem_writes = 0;
    integer mmio_reads = 0;
    integer mmio_writes = 0;

    always #4 clk = ~clk; // Zybo board clock: 125 MHz

    soc #(
        .IMEM_INIT_FILE("/home/igor/Documents/Vivado_Projects/G7_MIPS32/Assembly/soc_mmio.mem")
    ) dut(
        .i_clk(clk), .i_rst(rst), .i_sw(switches), .i_btn(buttons), .o_led(leds)
    );

    always @(posedge dut.clk_50mhz) begin
        if (dut.ram_read_enable) dmem_reads = dmem_reads + 1;
        if (dut.ram_write_enable) dmem_writes = dmem_writes + 1;
        if (dut.pario_read_enable) mmio_reads = mmio_reads + 1;
        if (dut.pario_write_enable) mmio_writes = mmio_writes + 1;
    end

    task check_reg(input [4:0] index, input [31:0] expected,
                   input [8*40-1:0] name);
        begin
            if (dut.u_cpu.u_dp.registers._rf[index] !== expected) begin
                $display("FAIL %0s: r%0d got %h expected %h",
                         name, index, dut.u_cpu.u_dp.registers._rf[index], expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin

        test_name = "END-TO-END DMEM AND MMIO";
        system_phase = "RESET";
        repeat (3) @(negedge clk);
        rst = 0;
        wait (dut.soc_reset === 1'b0);
        system_phase = "RUN PROGRAM";

        while (dut._pc !== 32'h0000_001C) begin
            @(posedge dut.clk_50mhz);
            #1;
            cycles = cycles + 1;
            if (cycles > 100) begin
                errors = errors + 1;
                $display("FAIL timeout waiting for program loop; PC=%h", dut._pc);
                $finish;
            end
        end
        repeat (3) @(posedge dut.clk_50mhz);
        #1;
        system_phase = "CHECK RESULTS";

        check_reg(10, 32'h0000_005A, "MMIO load returns buttons and switches");
        check_reg(12, 32'h0000_002A, "DMEM load returns preceding store");
        if (leds !== 4'b1010) begin
            $display("FAIL LED output: got %b expected 1010", leds);
            errors = errors + 1;
        end
        if (dmem_reads != 1 || dmem_writes != 1 ||
            mmio_reads != 1 || mmio_writes != 1) begin
            $display("FAIL bus counts: DMEM r/w=%0d/%0d MMIO r/w=%0d/%0d",
                     dmem_reads, dmem_writes, mmio_reads, mmio_writes);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: end-to-end SoC MMIO/DMEM, %0d cycles", cycles);
        else
            $display("FAILED: %0d SoC checks", errors);
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
