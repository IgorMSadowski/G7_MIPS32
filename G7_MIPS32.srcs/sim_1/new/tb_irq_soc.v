`timescale 1ns/1ps

module tb_irq_soc;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg btn3 = 1'b0;

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
        .i_btn1(1'b0),
        .i_btn3(btn3),

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

        // Allow three core clocks for BTN3 synchronization and pending capture.
        // The IRQ becomes visible when the LW at 0x38 reaches its read cycle.
        wait (!dut.soc_reset && dut.u_cpu.u_dp._pc_r == 32'h2c);
        @(negedge dut.clk_50mhz);
        btn3 = 1'b1;

        wait (dut.irq_request === 1'b1);
        #1;
        check(dut.u_cpu.u_dp._pc_r == 32'h38 && dut._mem_read,
              "IRQ3 becomes pending during the LW read cycle");
        check(!dut.irq_ack && !dut._imem_en,
              "LW read holds instruction fetch and delays IRQ acknowledgement");

        @(posedge dut.clk_50mhz);
        #1;
        check(dut.irq_ack && dut._imem_en && dut.u_cpu._rf_we && dut._pc == 32'h10,
              "LW write-back can commit while the ROM fetches vector 0x10");

        @(posedge dut.clk_50mhz);
        #1;
        check(dut.u_cpu.u_dp._pc_r == 32'h10 && dut.u_cpu.u_dp.irq_depth == 1 &&
              !dut.u_irq.global_enable && irq_ack_count == 1,
              "First IRQ enters with further interrupts masked");
        check(dut.u_cpu.u_dp.saved_pc == 32'h3c,
              "First IRQ saves the main program's continuation");

        // A second BTN3 edge arrives before the first ISR has saved its return PC.
        @(negedge dut.clk_50mhz);
        btn3 = 1'b0;
        repeat (2) @(negedge dut.clk_50mhz);
        btn3 = 1'b1;

        wait (dut.u_irq.pending[3] === 1'b1);
        #1;
        check(!dut.irq_ack && !dut.u_irq.global_enable && dut.u_cpu.u_dp.irq_depth == 1,
              "Second IRQ waits while the first ISR saves its context");

        wait (dut.ram_write && dut._alu_out == 32'h3fc);
        @(posedge dut.clk_50mhz);
        check(dut._wdata == 32'h3c,
              "Outer ISR reads read-only RETURN_PC and pushes 0x3C at 0x3FC");

        wait (irq_ack_count == 2);
        #1;
        check(dut.u_cpu.u_dp.irq_depth == 2 && dut.u_cpu.u_dp._pc_r == 32'h10 &&
              !dut.u_irq.global_enable && dut.u_irq.pending == 0,
              "Inner IRQ enters after the push and masks further entries");
        check(dut.u_cpu.u_dp.saved_pc == 32'h5c,
              "Inner IRQ captures the first ISR's continuation");

        wait (dut.ram_write && dut._alu_out == 32'h3f8);
        @(posedge dut.clk_50mhz);
        check(dut._wdata == 32'h5c, "Inner ISR pushes 0x5C at 0x3F8");

        wait (dut.irq_return);
        @(posedge dut.clk_50mhz);
        check(dut._pc == 32'h5c && !dut.irq_ack,
              "Inner JR k1 returns to the address popped from the stack");
        #1;
        check(dut.u_cpu.u_dp.irq_depth == 1 && dut.u_cpu.u_dp._pc_r == 32'h5c &&
              dut.u_irq.global_enable && dut.u_cpu.u_dp.registers._rf[29] == 32'h3fc,
              "First ISR resumes with its stack frame and interrupts enabled");

        wait (dut.irq_return);
        @(posedge dut.clk_50mhz);
        check(dut._pc == 32'h3c && dut.u_cpu.u_dp.saved_pc == 32'h5c,
              "Outer JR k1 uses popped 0x3C even though saved_pc still holds 0x5C");
        #1;
        check(dut.u_cpu.u_dp.irq_depth == 0 && dut.u_irq.global_enable &&
              dut.u_cpu.u_dp.registers._rf[29] == 32'h400,
              "Outer return restores the main context and stack pointer");

        wait (dut.ram_write && dut._alu_out == 32'h04);
        @(posedge dut.clk_50mhz);
        check(dut._wdata == 32'd42, "The resumed program retains the LW result");

        repeat (20) @(negedge dut.clk_50mhz);
        check(irq_ack_count == 2 && dut.u_cpu.u_dp._pc_r == 32'h40,
              "Two BTN3 edges yield exactly two services and the main loop resumes");

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
