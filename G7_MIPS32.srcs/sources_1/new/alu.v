`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Igor Sadowski
// 
// Create Date:
// Design Name: 
// Module Name: Arithmetic Logic Unit (ALU)
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Arithmetic Logic Unit for MIPS processor
//////////////////////////////////////////////////////////////////////////////////

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
            4'b0111: o_y = ($signed(i_a) < $signed(i_b)) ? 32'd1 : 32'd0;   // slt: set if less than (SIGNED)
            4'b0011: o_y = i_a ^ i_b;       // xor
            4'b1001: o_y = i_b << i_a;      // sll: shift left logical
            4'b1010: o_y = i_b >> i_a;      // srl: shift right logical
            4'b1100: o_y = {i_b[7:0], i_b[15:8], i_b[23:16], i_b[31:24]}; // wsbh: word swap byte halfword
            4'b1101: o_y = (i_a >> i_b) | (i_a << (32 - i_b)); // rotr: rotate right
            4'b1000: o_y = {i_b[15:0], 16'b0}; // lui: immediate in upper 16 bits
            default: o_y = 32'b0;
        endcase
    end
    assign o_zero = (o_y == 32'b0);
endmodule