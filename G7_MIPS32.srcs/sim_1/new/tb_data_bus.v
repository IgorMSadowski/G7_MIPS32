`timescale 1ns / 1ps

module tb_data_bus;
    reg clk = 0;
    reg rst = 1;
    reg en = 1;
    reg [31:0] addr = 0;
    reg mem_read = 0;
    reg mem_write = 0;
    reg [31:0] mmio_rdata = 0;
    reg rsp_consume = 0;
    reg [31:0] dmem [0:63];
    reg [31:0] dmem_rdata = 0;
    wire dmem_re, dmem_we, mmio_re, mmio_we;
    wire [31:0] rdata;
    wire rsp_valid;
    reg [8*32-1:0] test_name;
    reg [8*16-1:0] bus_phase;
    integer errors = 0;
    integer checks = 0;
    integer index;

    always #5 clk = ~clk;

    always @(posedge clk)
        if (dmem_re)
            dmem_rdata <= dmem[addr[7:2]];

    data_bus dut(
        .i_clk(clk),
        .i_rst(rst),
        .i_en(en),
        .i_address(addr),
        .i_read_request(mem_read),
        .i_write_request(mem_write),
        .i_ram_read_data(dmem_rdata),
        .i_pario_read_data(mmio_rdata),
        .i_load_complete(rsp_consume),
        .o_ram_read_enable(dmem_re),
        .o_ram_write_enable(dmem_we),
        .o_pario_read_enable(mmio_re),
        .o_pario_write_enable(mmio_we),
        .o_read_data(rdata),
        .o_read_response_valid(rsp_valid)
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
        for (index = 0; index < 64; index = index + 1)
            dmem[index] = 32'hA500_0000 + index;

        test_name = "DATA BUS ADDRESS DECODE";
        bus_phase = "RESET";
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 0;
        addr = 32'h0000_0004;
        mem_write = 1;
        #1;
        check(dmem_we && !dmem_re && !mmio_we && !mmio_re,
              "low aligned address selects only DMEM write");
        @(negedge clk);
        mem_write = 0;
        addr = 32'h8000_0000;
        mem_write = 1;
        #1;
        check(mmio_we && !dmem_we && !mmio_re,
              "MMIO address selects only peripheral write");
        @(negedge clk);
        mem_write = 0;
        addr = 32'h8000_0002;
        mem_write = 1;
        #1;
        check(!dmem_we && !mmio_we, "misaligned MMIO word write is rejected");
        @(negedge clk);
        mem_write = 0;
        addr = 32'h8000_0100;
        mem_read = 1;
        #1;
        check(!dmem_re && !mmio_re && !rsp_valid,
              "unmapped MMIO read is not routed");
        @(posedge clk);
        #1;
        check(!rsp_valid && rdata === 32'b0, "unmapped read creates no response");

        @(negedge clk);
        mem_read = 0;
        mem_write = 1;
        addr = 32'h8000_1000;
        #1;
        check(!mmio_we && !dmem_we, "former high-bit alias cannot write ParIO");
        addr = 32'h8000_0004;
        #1;
        check(!mmio_we && !dmem_we, "unused ParIO offset cannot write either target");
        mem_write = 0;

        bus_phase = "DMEM READ RESPONSE";
        addr = 32'h0000_0008;
        mem_read = 1;
        #1;
        check(dmem_re && !mmio_re, "aligned low address selects DMEM read");
        @(posedge clk);
        #1;
        check(rsp_valid && rdata === 32'hA500_0002,
              "DMEM response is visible after synchronous read");
        @(negedge clk);
        mem_read = 0;
        en = 0;
        #1;
        check(rsp_valid && rdata === 32'hA500_0002,
              "DMEM response remains available while CPU is paused");
        en = 1;
        rsp_consume = 1;
        @(posedge clk);
        #1;
        check(!rsp_valid && rdata === 32'b0, "consumed DMEM response clears");

        @(negedge clk);
        rsp_consume = 0;
        addr = 32'h8000_0000;
        mmio_rdata = 32'h0000_005A;
        mem_read = 1;
        #1;
        check(mmio_re && !dmem_re, "MMIO read selects peripheral path only");
        @(posedge clk);
        #1;
        check(rsp_valid && rdata === 32'h0000_005A,
              "MMIO read data is captured with its request");
        @(negedge clk);
        mem_read = 0;
        mmio_rdata = 32'hFFFF_FFFF;
        en = 0;
        #1;
        check(rsp_valid && rdata === 32'h0000_005A,
              "captured MMIO response survives input changes and pause");
        en = 1;
        rsp_consume = 1;
        @(posedge clk);
        #1;
        check(!rsp_valid, "consumed MMIO response clears");

        @(negedge clk);
        rsp_consume = 0;
        addr = 32'h0000_0002;
        mem_read = 1;
        #1;
        check(!dmem_re && !mmio_re, "misaligned word access is rejected");
        @(negedge clk);
        mem_read = 0;
        addr = 32'h0000_0100;
        mem_write = 1;
        #1;
        check(!dmem_we && !mmio_we, "address outside DMEM is rejected");

        @(negedge clk);
        mem_write = 0;
        mem_read = 1;
        addr = 32'h0000_0008;
        @(posedge clk);
        #1;
        check(rsp_valid, "read response pending before reset");
        @(negedge clk);
        rst = 1;
        #1;
        check(!dmem_re && !dmem_we && !mmio_re && !mmio_we,
              "reset blocks all bus requests");
        @(posedge clk);
        #1;
        check(!rsp_valid && rdata === 32'b0, "reset clears pending response");

        if (errors == 0) $display("PASS: %0d data-bus checks", checks);
        else $display("FAILED: %0d of %0d data-bus checks", errors, checks);
        $finish;
    end
endmodule
