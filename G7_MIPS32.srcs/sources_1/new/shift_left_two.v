`timescale 1ns / 1ps

module shift_left_two(
    input  wire [31:0] i_in,    // Input value
    output wire [31:0] o_out    // Input << 2
    );
    assign o_out = {i_in[29:0], 2'b00};
endmodule