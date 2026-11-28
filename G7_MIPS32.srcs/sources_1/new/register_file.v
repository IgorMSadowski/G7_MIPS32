`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// University of Minho 
// Engineer: Igor Sadowski
// 
// Module Name: Register File (RF)
// Description: 32-register × 32-bit register file with 2 read ports and 1 write port
//////////////////////////////////////////////////////////////////////////////////

module register_file(
    // Clock and reset
    input  wire        i_clk,
    input  wire        i_rst,

    // Read addresses
    input  wire [4:0]  i_ra1,         // Read address 1
    input  wire [4:0]  i_ra2,         // Read address 2

    // Write port
    input  wire        i_we,          // Write enable
    input  wire [4:0]  i_wa,          // Write address
    input  wire [31:0] i_wdata,       // Write data

    // Read data
    output wire [31:0] o_rd1,         // Read data 1
    output wire [31:0] o_rd2          // Read data 2
    );

    reg [31:0] _rf [0:31];          // 32 registers × 32 bits
    integer    _index;              // Reset loop counter

    always @(posedge i_clk) begin
        if (i_rst) 
        begin
            for (_index = 0; _index < 32; _index = _index + 1)
                _rf[_index] <= 32'b0;
        end 
        else if (i_we && (i_wa != 5'b00000)) // $zero (r0) is hardwired: writes ignored
            begin
            _rf[i_wa] <= i_wdata;   
        end
    end

    assign o_rd1 = _rf[i_ra1];
    assign o_rd2 = _rf[i_ra2];
endmodule