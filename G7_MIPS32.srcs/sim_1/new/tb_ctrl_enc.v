`timescale 1ns / 1ps

module tb_ctrl_enc;
    reg clk = 0;
    reg rst = 0;
    reg io = 0;
    reg [31:0] addr = 0;
    reg lw = 0, lb = 0, sw = 0, sb = 0;
    wire [31:0] ctrl;
    wire [7:0] sel;
    wire dec_clk, dec_rst;
    wire [3:0] oe, we;
    wire [11:0] dec_addr;
    reg [8*24-1:0] test_name;
    reg [8*16-1:0] decode_phase;
    integer errors = 0;
    integer checks = 0;

    ctrl_enc encoder(
        .clk(clk), .rst(rst), .io(io), .io_ad(addr),
        .lw(lw), .lb(lb), .sw(sw), .sb(sb), .ctrl(ctrl), .sel(sel)
    );

    ctrl_dec decoder(
        .ctrl(ctrl), .sel(sel[0]), .clk(dec_clk), .rst(dec_rst),
        .oe(oe), .we(we), .ad(dec_addr)
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
        test_name = "MMIO CONTROL ENCODING";
        decode_phase = "DMEM ADDRESS";
        clk = 0;
        rst = 1;
        io = 0;
        addr = 32'h0000_0000;
        lw = 1;
        #1;
        check(sel === 8'b0 && oe === 0 && we === 0,
              "ordinary memory read cannot select a peripheral");
        check(dec_clk === clk && dec_rst === rst,
              "clock and reset survive control-bus encoding");

        decode_phase = "PARIO READ";
        io = 1;
        addr = 32'h8000_0000;
        #1;
        check(sel === 8'b0000_0001, "base MMIO region selects PARIO");
        check(oe === 4'b0011 && we === 4'b0000,
              "lw decodes as a word peripheral read");
        check(dec_addr === 12'h000, "peripheral address is preserved");

        decode_phase = "PARIO WRITE";
        lw = 0;
        sw = 1;
        #1;
        check(oe === 4'b0000 && we === 4'b0011,
              "sw decodes as a word peripheral write");

        decode_phase = "OTHER REGIONS";
        sw = 0;
        addr = 32'h8000_0100;
        #1;
        check(sel === 8'b0000_0010 && oe === 0 && we === 0,
              "second MMIO region has independent chip select");
        addr = 32'h8000_0400;
        #1;
        check(sel === 8'b0, "unmapped MMIO region selects no peripheral");

        decode_phase = "BYTE CONTROL";
        addr = 32'h8000_0000;
        lb = 1;
        sb = 1;
        #1;
        check(oe === 4'b0001 && we === 4'b0001,
              "byte requests use byte-enable lanes");

        if (errors == 0) $display("PASS: %0d control-encoder checks", checks);
        else $display("FAILED: %0d of %0d control-encoder checks", errors, checks);
        $finish;
    end
endmodule
