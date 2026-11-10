`timescale 1ns / 1ps

module tb_regfile;

    reg         clk, rst, we;
    reg  [4:0]  ra1, ra2, wa;
    reg  [31:0] wdata;
    wire [31:0] rd1, rd2;

    // Simulation-only labels: display these signals with ASCII radix.
    reg [8*32-1:0] test_name;
    reg [8*16-1:0] write_action;
    always @(*) begin
        case (rst)
            1'b1: write_action = "RESET";
            1'b0: begin
                case (we)
                    1'b0: write_action = "DISABLED";
                    1'b1: begin
                        case (wa == 5'd0)
                            1'b1: write_action = "R0 BLOCKED";
                            1'b0: write_action = "WRITE ENABLED";
                            default: write_action = "UNKNOWN";
                        endcase
                    end
                    default: write_action = "UNKNOWN";
                endcase
            end
            default: write_action = "UNKNOWN";
        endcase
    end

    register_file dut(
        .i_clk(clk), .i_rst(rst), .i_we(we),
        .i_ra1(ra1), .i_ra2(ra2), .i_wa(wa),
        .i_wdata(wdata), .o_rd1(rd1), .o_rd2(rd2)
    );

    always #5 clk = ~clk;

    integer errors = 0;

    task write_reg(input [4:0] r, input [31:0] v);
        begin
            wa=r; wdata=v; we=1;
            @(posedge clk); #1;
            we=0;
        end
    endtask

    task check(input [4:0] r, input [31:0] expected, input [8*28-1:0] name);
        begin
            ra1=r; #1;
            if (rd1 !== expected) begin
                $display("FAIL %0s: r%0d = %h, expected %h", name, r, rd1, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        test_name = "RESET REGISTERS";
        clk=0; rst=1; we=0; ra1=0; ra2=0; wa=0; wdata=0;
        @(negedge clk); @(negedge clk);
        rst=0;

        // $zero reads 0 immediately
        test_name = "CHECK R0 AFTER RESET";
        check(0, 32'd0, "r0 is zero after reset");

        // Write r5, read back
        test_name = "WRITE AND READ R5";
        write_reg(5, 32'h1234_5678);
        check(5, 32'h1234_5678, "r5 write/read");

        // Try to write r0 — must be ignored
        test_name = "CHECK R0 WRITE PROTECTION";
        write_reg(0, 32'hFFFF_FFFF);
        check(0, 32'd0, "r0 write ignored ($zero protection)");

        // Two consecutive writes — second wins
        test_name = "WRITE R7 FIRST VALUE";
        write_reg(7, 32'h1111_1111);
        test_name = "WRITE R7 SECOND VALUE";
        write_reg(7, 32'h2222_2222);
        check(7, 32'h2222_2222, "consecutive writes");

        // The two asynchronous read ports can read different registers together.
        test_name = "READ R5 AND R7 TOGETHER";
        ra1 = 5'd5; ra2 = 5'd7;
        #1;
        if (rd1 !== 32'h1234_5678 || rd2 !== 32'h2222_2222) begin
            $display("FAIL simultaneous reads: rd1=%h rd2=%h", rd1, rd2);
            errors = errors + 1;
        end

        test_name = "SWAP READ ADDRESSES";
        ra1 = 5'd7; ra2 = 5'd5;
        #1;
        if (rd1 !== 32'h2222_2222 || rd2 !== 32'h1234_5678) begin
            $display("FAIL swapped reads: rd1=%h rd2=%h", rd1, rd2);
            errors = errors + 1;
        end

        // we=0 — no write happens
        test_name = "CHECK WRITE DISABLED";
        wa=8; wdata=32'hAAAA_AAAA; we=0;
        @(posedge clk); #1;
        check(8, 32'd0, "we=0 no write");

        $display("--- %0d errors ---", errors);
        if (errors==0) $display("PASS"); else $display("FAILED");
        $finish;
    end
endmodule
