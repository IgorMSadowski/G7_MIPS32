`timescale 1ns / 1ps
// Module: ctrl_dec
// Description: Extracts individual signals from the compressed control bus.
module ctrl_dec( 
    input  wire [31:0] ctrl, 
    input  wire        sel, 
    output wire        clk, 
    output wire        rst, 
    output wire [3:0]  oe, 
    output wire [3:0]  we, 
    output wire [11:0] ad 
);
    wire [3:0] oe_, we_;
    
    // Unpack the control bus
    assign {oe_, we_, ad, rst, clk} = ctrl;

    // Only activate signals if this specific peripheral is selected
    assign oe = sel ? oe_ : 4'b0;
    assign we = sel ? we_ : 4'b0;
endmodule