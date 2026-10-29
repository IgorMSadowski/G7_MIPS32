`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Igor Sadowski
// 
// Create Date:
// Design Name: 
// Module Name: Branch Decision Unit (BDU)
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Branch Decision Unit for MIPS processor
// 
// Dependencies: 
// 
//////////////////////////////////////////////////////////////////////////////////

module bdu(
    input wire        i_branch,         // 1 = branch instruction
    input wire [3:0]  i_branch_cond,    // Condition code from CU
    input wire [31:0] i_rs,             // rs value (for sign test in bltz/bgez)
    input wire        i_zero,           // ALU zero flag
    output reg        o_branch_taken    // 1 = take the branch
    );
    always @(*) begin
        if (i_branch) begin
            case (i_branch_cond)
                4'b0000: o_branch_taken = i_zero;       // beq, branch if equal
                4'b0001: o_branch_taken = ~i_zero;      // bne, branch if not equal
                4'b0010: o_branch_taken = i_rs[31];     // bltz, branch if less than zero
                4'b0011: o_branch_taken = ~i_rs[31];    // bgez, branch if greater than or equal to zero
                4'b0110: o_branch_taken = i_rs[31] == 1'b1; // blez, branch if less than or equal to zero
                4'b0111: o_branch_taken = i_rs[31] == 1'b0 && i_rs != 32'b0; // bgtz, branch if greater than zero: rs > 0
                default: o_branch_taken = 1'b0;         // default: not a branch instruction
            endcase
        end else begin
            o_branch_taken = 1'b0;
        end
    end
endmodule