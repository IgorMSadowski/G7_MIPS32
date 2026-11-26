`timescale 1ns / 1ps

// Check reset, writes, and the two register read ports.
module tb_regfile;

    reg clk;
    reg rst;
    reg we;
    reg [4:0] ra1;
    reg [4:0] ra2;
    reg [4:0] wa;
    reg [31:0] wdata;
    wire [31:0] rd1;
    wire [31:0] rd2;

    // Show the state of the write port in the waveform.
    reg [127:0] write_action;
    always @(*) begin
        case (rst)
            1'b1: write_action = "RESET           ";
            1'b0: begin
                case (we)
                    1'b0: write_action = "DISABLED        ";
                    1'b1: begin
                        case (wa == 5'd0)
                            1'b1: write_action = "R0 BLOCKED      ";
                            1'b0: write_action = "WRITE ENABLED   ";
                            default: write_action = "UNKNOWN         ";
                        endcase
                    end
                    default: write_action = "UNKNOWN         ";
                endcase
            end
            default: write_action = "UNKNOWN         ";
        endcase
    end

    register_file dut(
        .i_clk(clk),
        .i_rst(rst),

        .i_ra1(ra1),
        .i_ra2(ra2),

        .i_we(we),
        .i_wa(wa),
        .i_wdata(wdata),

        .o_rd1(rd1),
        .o_rd2(rd2)
    );

    always #10 clk = ~clk;

    integer errors = 0;

    // Change ra1 and check rd1 after 1 ns. The read port is asynchronous.
    task test_register(input [4:0] address, input [31:0] expected_value, input [223:0] description);
        begin
            ra1 = address;
            #1;
            if (rd1 !== expected_value) begin
                $display("FAIL %0s: r%0d = %h, expected %h", description, address, rd1, expected_value);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        // rst = 1, we = 0
        // Rising edge clears all registers.
        clk=0;
        rst=1;
        we=0;
        ra1=0;
        ra2=0;
        wa=0;
        wdata=0;
        // Release reset 1 ns after the first rising edge.
        @(posedge clk);
        #1;
        rst = 0;

        // $zero reads 0 immediately
        // rst = 0, we = 0
        // ra1 = 0 -> rd1 = 0x00000000
        test_register(0, 32'd0, "r0 is zero after reset");

        // Write r5, read back
        // we = 1, wa = 5, wdata = 0x12345678
        // ra1 = 5 -> rd1 = 0x12345678
        wa = 5'd5;
        wdata = 32'h1234_5678;
        we = 1;
        @(posedge clk);
        #1;
        we = 0;
        test_register(5, 32'h1234_5678, "r5 write/read");

        // Try writing all ones to r0. It should still read zero.
        // we = 1, wa = 0, wdata = 0xFFFFFFFF
        // ra1 = 0 -> rd1 = 0x00000000
        wa = 5'd0;
        wdata = 32'hFFFF_FFFF;
        we = 1;
        @(posedge clk);
        #1;
        we = 0;
        test_register(0, 32'd0, "r0 write ignored ($zero protection)");

        // Write r7 twice. Its final value should be the second one.
        // we = 1, wa = 7, wdata = 0x11111111
        // Rising edge stores 0x11111111 in R7.
        wa = 5'd7;
        wdata = 32'h1111_1111;
        we = 1;
        @(posedge clk);
        #1;
        we = 0;
        // we = 1, wa = 7, wdata = 0x22222222
        // ra1 = 7 -> rd1 = 0x22222222
        wa = 5'd7;
        wdata = 32'h2222_2222;
        we = 1;
        @(posedge clk);
        #1;
        we = 0;
        test_register(7, 32'h2222_2222, "consecutive writes");

        // The two asynchronous read ports can read different registers together.
        // we = 0
        // ra1 = 5 -> rd1 = 0x12345678
        // ra2 = 7 -> rd2 = 0x22222222
        ra1 = 5'd5;
        ra2 = 5'd7;
        #1;
        if (rd1 !== 32'h1234_5678 || rd2 !== 32'h2222_2222) begin
            $display("FAIL simultaneous reads: rd1=%h rd2=%h", rd1, rd2);
            errors = errors + 1;
        end

        // Swap the addresses and check that the outputs swap too.
        // we = 0
        // ra1 = 7 -> rd1 = 0x22222222
        // ra2 = 5 -> rd2 = 0x12345678
        ra1 = 5'd7;
        ra2 = 5'd5;
        #1;
        if (rd1 !== 32'h2222_2222 || rd2 !== 32'h1234_5678) begin
            $display("FAIL swapped reads: rd1=%h rd2=%h", rd1, rd2);
            errors = errors + 1;
        end

        // Present a value with we = 0. R8 should stay zero.
        // we = 0, wa = 8, wdata = 0xAAAAAAAA
        // ra1 = 8 -> rd1 = 0x00000000
        wa=8;
        wdata=32'hAAAA_AAAA;
        we=0;
        @(posedge clk);
        #1;
        test_register(8, 32'd0, "we=0 no write");

        $display("--- %0d errors ---", errors);
        if (errors==0)
            $display("PASS");
        else
            $display("FAILED");
        $finish;
    end
endmodule
