`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: Parallel I/O (PARIO)
// Address 0x80000000 reads buttons/switches and writes the three user LEDs.
//////////////////////////////////////////////////////////////////////////////////

module pario(
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_sel,
    input  wire        i_re,
    input  wire        i_we,
    input  wire [31:0] i_ctrl,
    input  wire [7:0]  i,
    input  wire [31:0] i_wdata,
    output reg  [31:0] o_rdata,
    output wire [2:0]  o_led
    );

    wire [3:0]  oe;
    wire [3:0]  we;
    wire [11:0] ad;
    reg  [2:0]  _led_reg;

    ctrl_dec u_ctrl_dec (
        .ctrl(i_ctrl),
        .sel(i_sel),
        .clk(),
        .rst(),
        .oe(oe),
        .we(we),
        .ad(ad)
    );

    always @(posedge i_clk) begin
        if (i_rst)
            _led_reg <= 3'b000;
        else if (i_we && we[1] && ad[7:0] == 8'h00)
            _led_reg <= i_wdata[2:0];
    end

    always @(*) begin
        o_rdata = 32'b0;
        if (i_re && oe[1] && ad[7:0] == 8'h00)
            o_rdata = {24'b0, i};
    end

    assign o_led = _led_reg;

endmodule
