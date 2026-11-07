`timescale 1ns / 1ps

module tb_primitives;
    reg [31:0] a32, b32;
    reg sel;
    wire [31:0] mux32_out, sign_out, shift_out;
    reg [4:0] a5, b5;
    wire [4:0] mux5_out;
    reg [15:0] imm;
    reg [31:0] shift_in;
    reg [8*24-1:0] test_name;
    reg [8*16-1:0] primitive_phase;
    integer errors = 0;
    integer checks = 0;

    mux2_32bit mux32(.i_a(a32), .i_b(b32), .i_sel(sel), .o_y(mux32_out));
    mux2_5bit mux5(.i_a(a5), .i_b(b5), .i_sel(sel), .o_y(mux5_out));
    sign_extend sign_ext(.i_imm(imm), .o_ext(sign_out));
    shift_left_two shift(.i_in(shift_in), .o_out(shift_out));

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

        test_name = "COMBINATIONAL PRIMITIVES";
        primitive_phase = "MUX LOW";
        a32 = 32'h1234_5678;
        b32 = 32'h89AB_CDEF;
        a5 = 5'd3;
        b5 = 5'd17;
        sel = 0;
        imm = 16'h7FFF;
        shift_in = 32'h0000_0003;
        #1;
        check(mux32_out === a32 && mux5_out === a5, "muxes select input A");
        check(sign_out === 32'h0000_7FFF, "sign extension preserves positive value");
        check(shift_out === 32'h0000_000C, "branch offset shifts left by two");

        primitive_phase = "MUX HIGH";
        sel = 1;
        imm = 16'h8001;
        shift_in = 32'h4000_0001;
        #1;
        check(mux32_out === b32 && mux5_out === b5, "muxes select input B");
        check(sign_out === 32'hFFFF_8001, "sign extension propagates sign bit");
        check(shift_out === 32'h0000_0004, "left shift drops the upper two bits");

        if (errors == 0) $display("PASS: %0d primitive checks", checks);
        else $display("FAILED: %0d of %0d primitive checks", errors, checks);
        $finish;
    end
endmodule
