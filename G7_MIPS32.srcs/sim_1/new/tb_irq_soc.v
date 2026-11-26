`timescale 1ns/1ps

module tb_irq_soc;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg btn1 = 1'b0;

    integer checks = 0;
    integer errors = 0;
    integer irq_ack_count = 0;

    // The Clock Wizard derives 50 MHz from the 125 MHz board clock.
    always #4 clk = ~clk;

    soc #(
        .MEM_INIT_FILE("irq_program.mem")
    ) dut (
        .i_clk(clk),
        .i_rst(rst),
        .i_sw(2'b00),
        .i_btn1(btn1),
        .o_led()
    );

    always @(posedge dut.clk_50mhz) begin
        if (dut.soc_reset)
            irq_ack_count <= 0;
        else if (dut.irq_ack)
            irq_ack_count <= irq_ack_count + 1;
    end

    task check(input condition, input [8*96-1:0] description);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL: %0s", description);
            end
        end
    endtask

    initial begin
        repeat (25) @(posedge clk);
        @(negedge clk);
        rst = 1'b0;

        // Allow three core clocks for BTN1 synchronization and pending capture.
        // The IRQ becomes visible when the LW at 0x38 reaches its read cycle.
        wait (!dut.soc_reset && dut.u_cpu.u_dp._pc_r == 32'h2c);
        @(negedge dut.clk_50mhz);
        btn1 = 1'b1;

        wait (dut.irq_request === 1'b1);
        #1;
        check(dut.u_cpu.u_dp._pc_r == 32'h38 && dut._mem_read,
              "IRQ0 becomes pending during the LW read cycle");
        check(!dut.irq_ack && !dut._imem_en,
              "LW read holds instruction fetch and delays IRQ acknowledgement");

        @(posedge dut.clk_50mhz);
        #1;
        check(dut.irq_ack && dut._imem_en && dut.u_cpu._rf_we && dut._pc == 32'h04,
              "LW write-back can commit while the ROM fetches vector 0x04");

        @(posedge dut.clk_50mhz);
        #1;
        check(dut.u_cpu.u_dp._pc_r == 32'h04 && dut.u_cpu.u_dp.irq_active,
              "The core enters IRQ0");
        check(dut.irq_return_pc == 32'h3c,
              "IRQ entry saves the main program's next PC");

        // The handler stores the PC and pending bits it read through MMIO.
        wait (dut.ram_write && dut._alu_out == 32'h08);
        @(posedge dut.clk_50mhz);
        check(dut._wdata == 32'h3c, "MMIO offset 0x08 returns the saved PC");

        wait (dut.ram_write && dut._alu_out == 32'h0c);
        @(posedge dut.clk_50mhz);
        check(dut._wdata == 32'b0, "ACK clears the IRQ0 pending bit");

        wait (dut.u_cpu.u_dp.return_irq);
        @(posedge dut.clk_50mhz);
        check(dut._pc == 32'h3c && !dut.irq_ack,
              "JR $k1 fetches the saved resume address");
        #1;
        check(!dut.u_cpu.u_dp.irq_active, "JR $k1 clears IRQ active");

        wait (dut.ram_write && dut._alu_out == 32'h04);
        @(posedge dut.clk_50mhz);
        check(dut._wdata == 32'd42, "The resumed program retains the LW result");

        // BTN1 is still held. Only its rising edge can generate an event.
        repeat (20) @(negedge dut.clk_50mhz);
        check(irq_ack_count == 1 && dut.u_cpu.u_dp._pc_r == 32'h40,
              "Holding BTN1 produces one IRQ and the main loop resumes");

        if (errors == 0)
            $display("PASS: %0d IRQ checks", checks);
        else
            $display("FAIL: %0d errors out of %0d IRQ checks", errors, checks);
        $finish;
    end

    initial begin
        #20000;
        errors = errors + 1;
        $display("FAIL: IRQ test timed out at PC %h", dut._pc);
        $finish;
    end
endmodule
