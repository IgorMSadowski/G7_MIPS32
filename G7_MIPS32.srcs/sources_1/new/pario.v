`timescale 1ns / 1ps

// The data bus selects the ParIO address. This module only handles the pins.
module pario(
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_write_enable,
    input  wire [7:0]  i_pins,
    input  wire [31:0] i_write_data,
    output wire [31:0] o_read_data,
    output reg  [2:0]  o_led
    );

    assign o_read_data = {24'b0, i_pins};

    always @(posedge i_clk) begin
        if (i_rst)
            o_led <= 3'b000;
        else if (i_write_enable)
            o_led <= i_write_data[2:0];
    end
endmodule
