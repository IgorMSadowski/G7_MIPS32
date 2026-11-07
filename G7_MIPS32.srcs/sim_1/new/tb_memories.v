`timescale 1ns / 1ps

module tb_memories;
    reg clk = 0;
    reg rst = 1;
    reg en = 1;
    reg [31:0] imem_addr = 0;
    wire [31:0] instr;
    reg [31:0] dmem_addr = 0;
    reg [31:0] dmem_wdata = 0;
    reg dmem_re = 0, dmem_we = 0;
    wire [31:0] dmem_rdata;
    reg [8*24-1:0] test_name;
    reg [8*16-1:0] memory_phase;
    integer errors = 0;
    integer checks = 0;

    always #5 clk = ~clk;

    instruction_memory #(
        .MEM_INIT_FILE("/home/igor/Documents/Vivado_Projects/G7_MIPS32/Assembly/soc_mmio.mem")
    ) imem(
        .i_clk(clk), .i_rst(rst), .i_en(en),
        .i_addr(imem_addr), .o_instr(instr)
    );

    data_memory dmem(
        .i_clk(clk), .i_rst(rst), .i_en(en), .i_addr(dmem_addr),
        .i_wdata(dmem_wdata), .i_re(dmem_re), .i_we(dmem_we),
        .o_rdata(dmem_rdata)
    );

    task check(input condition, input [8*56-1:0] name);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) begin
                $display("FAIL %0s", name);
                errors = errors + 1;
            end
        end
    endtask

    initial begin

        test_name = "SYNCHRONOUS INSTRUCTION ROM";
        memory_phase = "RESET";
        repeat (2) @(posedge clk);
        #1;
        check(instr === 32'b0 && dmem_rdata === 32'b0,
              "reset clears both memory output registers");

        memory_phase = "ROM READ";
        @(negedge clk);
        rst = 0;
        imem_addr = 0;
        @(posedge clk);
        #1;
        check(instr === 32'h3C09_8000, "ROM returns first instruction after one edge");
        @(negedge clk);
        imem_addr = 4;
        en = 0;
        @(posedge clk);
        #1;
        check(instr === 32'h3C09_8000, "disabled ROM holds its output");
        @(negedge clk);
        en = 1;
        @(posedge clk);
        #1;
        check(instr === 32'h2008_0005, "ROM advances when enabled");

        memory_phase = "RAM WRITE AND READ";
        @(negedge clk);
        dmem_addr = 32'h0000_0008;
        dmem_wdata = 32'hCAFE_BABE;
        dmem_we = 1;
        @(posedge clk);
        #1;
        check(dmem_rdata === 32'b0, "read-first write returns previous word");
        @(negedge clk);
        dmem_we = 0;
        dmem_re = 1;
        @(posedge clk);
        #1;
        check(dmem_rdata === 32'hCAFE_BABE, "RAM read returns stored word");
        @(negedge clk);
        dmem_re = 0;
        en = 0;
        dmem_addr = 32'h0000_000C;
        @(posedge clk);
        #1;
        check(dmem_rdata === 32'hCAFE_BABE, "disabled RAM holds its output");

        @(negedge clk);
        en = 1;
        rst = 1;
        @(posedge clk);
        #1;
        check(instr === 32'b0 && dmem_rdata === 32'b0,
              "reset clears outputs without requiring an access");

        if (errors == 0) $display("PASS: %0d memory checks", checks);
        else $display("FAILED: %0d of %0d memory checks", errors, checks);
        $finish;
    end
endmodule
