`timescale 1ns / 1ps

// Test clocked reads from ROM and a write/read at RAM address 0.
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
    reg [127:0] memory_phase;
    integer errors = 0;
    integer checks = 0;

    // 50 MHz; inputs change 1 ns after the rising edge.
    always #10 clk = ~clk;

    // Load known words from memory_basic.mem at byte addresses 0, 4 and 8.
    instruction_memory #(
        .MEM_INIT_FILE("/home/igor/Documents/Vivado_Projects/G7_MIPS32/Assembly/memory_basic.mem")
    ) imem (
        .i_clk(clk),
        .i_rst(rst),

        .i_en(en),
        .i_addr(imem_addr),

        .o_instr(instr)
    );

    data_memory dmem (
        .i_clk(clk),
        .i_rst(rst),
        .i_en(en),

        .i_addr(dmem_addr),
        .i_re(dmem_re),
        .i_we(dmem_we),
        .i_wdata(dmem_wdata),

        .o_rdata(dmem_rdata)
    );

    // Count the checks and report the one that failed.
    task test_memory(input condition, input [447:0] description);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                errors = errors + 1;
                $display("FAIL: %0s", description);
            end
        end
    endtask

    initial begin
        // rst = 1, en = 1 -> both outputs are zero after the rising edge.
        memory_phase = "RESET           ";
        @(posedge clk);
        #1;
        test_memory(instr == 0 && dmem_rdata == 0, "reset clears both outputs");
        rst = 0;

        // en = 1, imem_addr = 0x00 -> instr = 0x11111111
        memory_phase = "ROM READ 0      ";
        imem_addr = 32'h0000_0000;
        @(posedge clk);
        #1;
        test_memory(instr == 32'h1111_1111, "ROM read at 0x00");

        // en = 1, imem_addr = 0x04 -> instr = 0x22222222
        memory_phase = "ROM READ 4      ";
        imem_addr = 32'h0000_0004;
        @(posedge clk);
        #1;
        test_memory(instr == 32'h2222_2222, "ROM read at 0x04");

        // en = 0, imem_addr = 0x08 -> instr holds 0x22222222
        memory_phase = "ROM HOLD        ";
        en = 0;
        imem_addr = 32'h0000_0008;
        @(posedge clk);
        #1;
        test_memory(instr == 32'h2222_2222, "ROM holds when disabled");

        // en = 1, imem_addr = 0x08 -> instr = 0x33333333
        memory_phase = "ROM READ 8      ";
        en = 1;
        @(posedge clk);
        #1;
        test_memory(instr == 32'h3333_3333, "ROM reads after enable");

        // en = 1, dmem_we = 1, dmem_re = 0, dmem_addr = 0x00
        // Write 0x12345678 at the next rising edge.
        memory_phase = "RAM WRITE       ";
        dmem_addr = 32'h0000_0000;
        dmem_wdata = 32'h1234_5678;
        dmem_we = 1;
        @(posedge clk);
        #1;

        // dmem_we = 0, dmem_re = 1, dmem_addr = 0x00 -> dmem_rdata = 0x12345678
        memory_phase = "RAM READ        ";
        dmem_we = 0;
        dmem_re = 1;
        @(posedge clk);
        #1;
        test_memory(dmem_rdata == 32'h1234_5678, "RAM reads back the written word");

        // en = 0, dmem_addr = 0x04 -> dmem_rdata holds 0x12345678
        memory_phase = "RAM HOLD        ";
        en = 0;
        dmem_addr = 32'h0000_0004;
        @(posedge clk);
        #1;
        test_memory(dmem_rdata == 32'h1234_5678, "RAM holds when disabled");

        // rst = 1, en = 1 -> both output registers clear on the rising edge.
        memory_phase = "RESET TEST      ";
        dmem_re = 0;
        en = 1;
        rst = 1;
        @(posedge clk);
        #1;
        test_memory(instr == 0 && dmem_rdata == 0, "final reset clears both outputs");
        #19;

        if (errors == 0) $display("PASS: %0d basic memory checks", checks);
        else $display("FAILED: %0d errors in %0d checks", errors, checks);
        $finish;
    end
endmodule
