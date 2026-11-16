`timescale 1ns / 1ps

// Basic ROM and RAM test. No CPU or assembly execution is involved.
module tb_memories;
    reg clk = 0;
    reg rst = 1;
    reg en = 1;
    reg [31:0] imem_addr = 0;
    wire [31:0] instr;
    reg [31:0] dmem_addr = 0;
    reg [31:0] dmem_wdata = 0;
    reg dmem_re = 0;
    reg dmem_we = 0;
    wire [31:0] dmem_rdata;
    // Labels are padded on the right with spaces for left-aligned ASCII display.
    reg [8*32-1:0] test_name;
    reg [8*16-1:0] memory_phase;
    integer errors = 0;
    integer checks = 0;

    // 50 MHz. Inputs change 1 ns after an edge, for the next edge.
    // The 1 ns delay is a stimulus assumption, not measured FPGA timing.
    always #10 clk = ~clk;

    instruction_memory #(
        .MEM_INIT_FILE("/home/igor/Documents/Vivado_Projects/G7_MIPS32/Assembly/memory_basic.mem")
    ) imem (
        .i_clk(clk), .i_rst(rst), .i_en(en),
        .i_addr(imem_addr), .o_instr(instr)
    );

    data_memory dmem (
        .i_clk(clk), .i_rst(rst), .i_en(en),
        .i_addr(dmem_addr), .i_wdata(dmem_wdata),
        .i_re(dmem_re), .i_we(dmem_we), .o_rdata(dmem_rdata)
    );

    // Count each comparison and report any failure.
    task test_memory(input condition, input [8*56-1:0] name);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL: %0s", name);
            end
        end
    endtask

    initial begin
        // 1. Reset makes both output registers zero.
        test_name = "INITIAL RESET                   ";
        memory_phase = "RESET           ";
        repeat (2) @(posedge clk);
        #1;
        test_memory(instr === 0 && dmem_rdata === 0,"reset makes ROM and RAM outputs zero");

        // 2. ROM byte address 0 selects the first line of memory_basic.mem.
        @(posedge clk); #1;
        test_name = "ROM WORD 0                      ";
        memory_phase = "ROM READ        ";
        rst = 0;
        imem_addr = 32'h00000000;
        @(posedge clk); #1;
        test_memory(instr === 32'h11111111, "ROM address 0 returns 11111111");

        // 3. Address 4 selects the second 32-bit word (four bytes per word).
        @(posedge clk); #1;
        test_name = "ROM WORD 1                      ";
        imem_addr = 32'h00000004;
        @(posedge clk); #1;
        test_memory(instr === 32'h22222222, "ROM address 4 returns 22222222");

        // 4. With enable low, changing the address must not change the output.
        @(posedge clk); #1;
        test_name = "ROM DISABLED                    ";
        memory_phase = "ROM HOLD        ";
        en = 0;
        imem_addr = 32'h00000008;
        @(posedge clk); #1;
        test_memory(instr === 32'h22222222, "disabled ROM keeps its previous output");

        // 5. Re-enable the ROM: address 8 now selects the third word.
        @(posedge clk); #1;
        test_name = "ROM ENABLED AGAIN               ";
        memory_phase = "ROM READ        ";
        en = 1;
        @(posedge clk); #1;
        test_memory(instr === 32'h33333333, "enabled ROM reads the new address");

        // 6. Write one value into RAM byte address 0.
        @(posedge clk); #1;
        test_name = "WRITE RAM WORD 0                ";
        memory_phase = "RAM WRITE       ";
        dmem_addr = 32'h00000000;
        dmem_wdata = 32'h12345678;
        dmem_we = 1;
        @(posedge clk); #1;
        dmem_we = 0;

        // Read the same address on the next edge and compare with the value written.
        test_name = "READ RAM WORD 0                 ";
        memory_phase = "RAM READ        ";
        dmem_re = 1;
        @(posedge clk); #1;
        test_memory(dmem_rdata === 32'h12345678, "RAM returns the value written");

        // 7. A disabled RAM keeps its output even with a read request at another address.
        @(posedge clk); #1;
        test_name = "RAM DISABLED                    ";
        memory_phase = "RAM HOLD        ";
        en = 0;
        dmem_addr = 32'h00000004;
        @(posedge clk); #1;
        test_memory(dmem_rdata === 32'h12345678, "disabled RAM keeps its previous output");

        // 8. Reset clears the output registers, not all stored words.
        @(posedge clk); #1;
        test_name = "FINAL RESET                     ";
        memory_phase = "RESET           ";
        dmem_re = 0;
        en = 1;
        rst = 1;
        @(posedge clk); #1;
        test_memory(instr === 0 && dmem_rdata === 0,"reset makes both outputs zero again");
        #15

        if (errors == 0) $display("PASS: %0d basic memory checks", checks);
        else $display("FAILED: %0d errors in %0d checks", errors, checks);
        $finish;
    end
endmodule
