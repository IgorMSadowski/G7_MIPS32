`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Igor Sadowski
// 
// Create Date:
// Design Name: 
// Module Name: control_unit
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description:
// 
// Dependencies: 
// 
//////////////////////////////////////////////////////////////////////////////////

module sign_extend(
    input  wire [15:0] i_imm,   // 16-bit signed immediate
    output wire [31:0] o_ext    // 32-bit sign-extended value
    );
    assign o_ext = {{16{i_imm[15]}}, i_imm};   // replicate sign bit 16 times
endmodule