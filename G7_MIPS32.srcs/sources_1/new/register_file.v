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

// 32-register × 32-bit register file with 2 read ports and 1 write port
module register_file(
    input  wire        i_clk,       
    input  wire        i_rst,       
    input  wire        i_we,        // Write enable
    input  wire [4:0]  i_ra1,       // Read address 1 (rs)
    input  wire [4:0]  i_ra2,       // Read address 2 (rt)
    input  wire [4:0]  i_wa,        // Write address
    input  wire [31:0] i_wdata,     // Write data
    output wire [31:0] o_rd1,       // Read data 1
    output wire [31:0] o_rd2        // Read data 2
    );

    reg [31:0] _rf [0:31];          // 32 registers × 32 bits
    integer    _index;              // Reset loop counter

    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            for (_index = 0; _index < 32; _index = _index + 1)
                _rf[_index] <= 32'b0;
        end else if (i_we && (i_wa != 5'b00000)) begin
            _rf[i_wa] <= i_wdata;   // $zero (r0) is hardwired: writes ignored
        end
    end

    assign o_rd1 = _rf[i_ra1];
    assign o_rd2 = _rf[i_ra2];
endmodule