`timescale 1ns / 1ps

// ALU - arithmetic and logic
module alu(
    input  wire [31:0] i_a,     // Operand A
    input  wire [31:0] i_b,     // Operand B
    input  wire [3:0]  i_ctrl,  // Operation select
    output reg  [31:0] o_y,     // Result
    output wire        o_zero   // 1 when result == 0
    );
    always @(*) begin
        case (i_ctrl)
            4'b0000: o_y = i_a & i_b;       // and
            4'b0001: o_y = i_a | i_b;       // or
            4'b0010: o_y = i_a + i_b;       // add
            4'b0110: o_y = i_a - i_b;       // sub
            4'b0111: o_y = ($signed(i_a) < $signed(i_b)) ? 32'd1 : 32'd0;   // set if less than (SIGNED)
            default: o_y = 32'b0;
        endcase
    end
    assign o_zero = (o_y == 32'b0);
endmodule