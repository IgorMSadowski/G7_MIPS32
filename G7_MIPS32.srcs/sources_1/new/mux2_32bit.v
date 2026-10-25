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

module mux2_32bit(
    input  wire [31:0] i_a,     // Selected when i_sel = 0
    input  wire [31:0] i_b,     // Selected when i_sel = 1
    input  wire        i_sel,   // Select signal
    output wire [31:0] o_y      // Selected output
    );
    assign o_y = i_sel ? i_b : i_a;
endmodule