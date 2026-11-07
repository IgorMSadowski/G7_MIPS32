`timescale 1ns / 1ps

module tb_pario;
    reg clk = 0;
    reg rst = 1;
    reg io = 1;
    reg [31:0] addr = 32'h8000_0000;
    reg lw = 0, sw = 0;
    reg [7:0] inputs = 0;
    reg [31:0] wdata = 0;
    wire [31:0] ctrl, rdata;
    wire [7:0] sel;
    wire per_re, per_we;
    wire [2:0] led;
    reg [8*24-1:0] test_name;
    reg [8*16-1:0] pario_phase;
    integer errors = 0;
    integer checks = 0;

    always #5 clk = ~clk;

    ctrl_enc encoder(
        .clk(clk), .rst(rst), .io(io), .io_ad(addr),
        .lw(lw), .lb(1'b0), .sw(sw), .sb(1'b0),
        .ctrl(ctrl), .sel(sel)
    );

    assign per_re = lw && sel[0];
    assign per_we = sw && sel[0];

    pario dut(
        .i_clk(clk), .i_rst(rst),
        .i_sel(sel[0]), .i_re(per_re), .i_we(per_we),
        .i_ctrl(ctrl), .i(inputs), .i_wdata(wdata),
        .o_rdata(rdata), .o_led(led)
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

        test_name = "PARIO RESET AND LED OUTPUT";
        pario_phase = "RESET";
        repeat (2) @(posedge clk);
        #1;
        check(led === 3'b000, "reset clears LED output");

        pario_phase = "WRITE LED";
        @(negedge clk);
        rst = 0;
        sw = 1;
        wdata = 32'h0000_0005;
        #1;
        check(sel[0] && dut.we[1], "selected word store enables PARIO write");
        @(posedge clk);
        #1;
        check(led === 3'b101, "store updates all user LED bits");

        pario_phase = "READ SWITCHES";
        @(negedge clk);
        sw = 0;
        lw = 1;
        inputs = 8'h5A;
        #1;
        check(dut.oe[1] && rdata === 32'h0000_005A,
              "word load returns button/switch input");

        pario_phase = "UNSUPPORTED OFFSET";
        @(negedge clk);
        addr = 32'h8000_0004;
        #1;
        check(rdata === 32'b0, "unimplemented register offset reads as zero");
        lw = 0;
        sw = 1;
        wdata = 32'h0000_0002;
        @(posedge clk);
        #1;
        check(led === 3'b101, "unimplemented register offset cannot write LEDs");

        pario_phase = "UNSELECTED";
        @(negedge clk);
        addr = 32'h8000_0100;
        #1;
        check(!sel[0] && !dut.we[1] && rdata === 32'b0,
              "other peripheral region cannot affect PARIO");

        if (errors == 0) $display("PASS: %0d PARIO checks", checks);
        else $display("FAILED: %0d of %0d PARIO checks", errors, checks);
        $finish;
    end
endmodule
