`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// University of Minho 
// Engineer: Igor Sadowski
// 
// Module Name: Sign Extend (sign_extend)
// Description: Extends a 16-bit signed immediate to 32-bit
//////////////////////////////////////////////////////////////////////////////////

module sign_extend(
    input  wire [15:0] i_imm,   // 16-bit signed immediate
    output wire [31:0] o_ext    // 32-bit sign-extended value
    );
    assign o_ext = {{16{i_imm[15]}}, i_imm};   // replicate sign bit 16 times
endmodule