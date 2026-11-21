`timescale 1ns / 1ps

// Check which device gets each read or write and which data reaches the CPU.
module tb_data_bus;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg [31:0] addr = 32'b0;
    reg read_enable = 1'b0, write_enable = 1'b0;
    reg [31:0] ram_rdata = 0;
    reg [31:0] irq_rdata = 0;
    reg [31:0] i2s_rdata = 0;
    wire ram_read, ram_write;
    // These enables route CPU reads and writes to each MMIO page.
    wire irq_read, irq_write;  // Interrupt controller at 0x100000xx.
    wire i2s_read, i2s_write;  // I2S peripheral at 0x100003xx.
    wire [7:0] offset;
    wire [31:0] read_data;
    integer errors = 0;
    integer checks = 0;

    // 50 MHz clock.
    always #10 clk = ~clk;

    data_bus dut (
        .i_clk(clk), .i_rst(rst),
        .i_addr(addr), .i_re(read_enable), .i_we(write_enable),
        .i_ram_rdata(ram_rdata), .i_irq_rdata(irq_rdata),
        .i_i2s_rdata(i2s_rdata),
        .o_ram_re(ram_read), .o_ram_we(ram_write),
        .o_irq_re(irq_read), .o_irq_we(irq_write),
        .o_i2s_re(i2s_read), .o_i2s_we(i2s_write),
        .o_mmio_offset(offset), .o_rdata(read_data)
    );

    task test_bus(input condition, input [255:0] description);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                $display("FAIL %0s at address %h", description, addr);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        // Reset clears the registered read selection.
        @(posedge clk);
        #1;
        test_bus(read_data == 0 && ram_read == 0 && irq_read == 0 && i2s_read == 0 && ram_write == 0 && irq_write == 0 && i2s_write == 0, "reset clears read selection");
        rst = 0;

        // Read the first RAM word at byte address 0x00000000.
        // Address = 0x00000000
        // Region [31:10] = 0x000000 (RAM), low bits [9:0] = 0x000
        addr = 32'h0000_0000; read_enable = 1; write_enable = 0;
        ram_rdata = 32'h1111_1111;
        @(posedge clk);
        #1;
        test_bus(ram_read == 1 && irq_read == 0 && i2s_read == 0 && ram_write == 0 && irq_write == 0 && i2s_write == 0 && read_data == 32'h1111_1111 && offset == 8'h00, "first RAM word");

        // The last aligned word of the 1 KiB RAM is at 0x000003FC.
        // Address = 0x000003FC
        // Region [31:10] = 0x000000 (RAM), low bits [9:0] = 0x3FC
        addr = 32'h0000_03FC; read_enable = 1; write_enable = 0;
        ram_rdata = 32'h1111_1111;
        @(posedge clk);
        #1;
        test_bus(ram_read == 1 && irq_read == 0 && i2s_read == 0 && ram_write == 0 && irq_write == 0 && i2s_write == 0 && read_data == 32'h1111_1111 && offset == 8'hFC, "last RAM word");

        // IRQ read at offset 0x04. The enable changes before the read mux does.
        // Address = 0x10000004
        // MMIO [31:12] = 0x10000, page [11:8] = 0x0 (IRQ), byte offset [7:0] = 0x04
        addr = 32'h1000_0004; read_enable = 1; write_enable = 0;
        irq_rdata = 32'h2222_2222;
        #1;
        test_bus(ram_read == 0 && irq_read == 1 && i2s_read == 0 && offset == 8'h04 && read_data == 32'h1111_1111, "before edge: RAM data holds");
        @(posedge clk);
        #1;
        test_bus(ram_read == 0 && irq_read == 1 && i2s_read == 0 && ram_write == 0 && irq_write == 0 && i2s_write == 0 && read_data == 32'h2222_2222, "after edge: IRQ data selected");

        // With both enables low, the old read data stays selected for write-back.
        // Address = 0x10000004
        // MMIO [31:12] = 0x10000, page [11:8] = 0x0 (IRQ), byte offset [7:0] = 0x04
        addr = 32'h1000_0004; read_enable = 0; write_enable = 0;
        @(posedge clk);
        #1;
        test_bus(ram_read == 0 && irq_read == 0 && i2s_read == 0 && ram_write == 0 && irq_write == 0 && i2s_write == 0 && read_data == 32'h2222_2222, "read data held for write-back");

        // A write selects RAM but leaves the registered read selection alone.
        // Address = 0x00000000
        // Region [31:10] = 0x000000 (RAM), low bits [9:0] = 0x000
        addr = 32'h0000_0000; read_enable = 0; write_enable = 1;
        @(posedge clk);
        #1;
        test_bus(ram_read == 0 && irq_read == 0 && i2s_read == 0 && ram_write == 1 && irq_write == 0 && i2s_write == 0 && read_data == 32'h2222_2222, "RAM write keeps last read");

        // Route a write to the interrupt controller page.
        // Address = 0x10000004
        // MMIO [31:12] = 0x10000, page [11:8] = 0x0 (IRQ), byte offset [7:0] = 0x04
        addr = 32'h1000_0004; read_enable = 0; write_enable = 1;
        @(posedge clk);
        #1;
        test_bus(ram_read == 0 && irq_read == 0 && i2s_read == 0 && ram_write == 0 && irq_write == 1 && i2s_write == 0 && offset == 8'h04, "IRQ write");

        // Read and then write the I2S page at byte offset 0x08.
        // Address = 0x10000308
        // MMIO [31:12] = 0x10000, page [11:8] = 0x3 (I2S), byte offset [7:0] = 0x08
        addr = 32'h1000_0308; read_enable = 1; write_enable = 0;
        i2s_rdata = 32'h3333_3333;
        @(posedge clk);
        #1;
        test_bus(ram_read == 0 && irq_read == 0 && i2s_read == 1 && ram_write == 0 && irq_write == 0 && i2s_write == 0 && read_data == 32'h3333_3333 && offset == 8'h08, "I2S read");

        // Address = 0x10000308
        // MMIO [31:12] = 0x10000, page [11:8] = 0x3 (I2S), byte offset [7:0] = 0x08
        addr = 32'h1000_0308; read_enable = 0; write_enable = 1;
        @(posedge clk);
        #1;
        test_bus(ram_read == 0 && irq_read == 0 && i2s_read == 0 && ram_write == 0 && irq_write == 0 && i2s_write == 1, "I2S write");

        // An address just outside RAM selects no device.
        // Address = 0x00000400
        // Region [31:10] = 0x000001 (outside RAM), low bits [9:0] = 0x000
        addr = 32'h0000_0400; read_enable = 1; write_enable = 0;
        @(posedge clk);
        #1;
        test_bus(ram_read == 0 && irq_read == 0 && i2s_read == 0 && ram_write == 0 && irq_write == 0 && i2s_write == 0 && read_data == 0, "address outside RAM");

        // An unmapped MMIO page returns zero on a read and ignores a write.
        // Address = 0x10000200
        // MMIO [31:12] = 0x10000, page [11:8] = 0x2 (unmapped), byte offset [7:0] = 0x00
        addr = 32'h1000_0200; read_enable = 1; write_enable = 0;
        @(posedge clk);
        #1;
        test_bus(ram_read == 0 && irq_read == 0 && i2s_read == 0 && ram_write == 0 && irq_write == 0 && i2s_write == 0 && read_data == 0, "unmapped MMIO read");

        // Address = 0x10000200
        // MMIO [31:12] = 0x10000, page [11:8] = 0x2 (unmapped), byte offset [7:0] = 0x00
        addr = 32'h1000_0200; read_enable = 0; write_enable = 1;
        @(posedge clk);
        #1;
        test_bus(ram_read == 0 && irq_read == 0 && i2s_read == 0 && ram_write == 0 && irq_write == 0 && i2s_write == 0, "unmapped MMIO write");

        read_enable = 0;
        write_enable = 0;
        #19;
        if (errors == 0) $display("PASS: %0d data bus checks", checks);
        else $display("FAILED: %0d errors in %0d checks", errors, checks);
        $finish;
    end
endmodule
