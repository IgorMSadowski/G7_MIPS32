`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// University of Minho 
// Engineer: Igor Sadowski
// 
// Module Name: Multiplexer 2-to-1, 32-bit wide (mux2_32bit)
// Description: Multiplexer for selecting between two 32-bit inputs
//////////////////////////////////////////////////////////////////////////////////

module mux2_32bit(
    input  wire [31:0] i_a,     // Selected when i_sel = 0
    input  wire [31:0] i_b,     // Selected when i_sel = 1
    input  wire        i_sel,   // Select signal
    output wire [31:0] o_y      // Selected output
    );
    assign o_y = i_sel ? i_b : i_a;
endmodule