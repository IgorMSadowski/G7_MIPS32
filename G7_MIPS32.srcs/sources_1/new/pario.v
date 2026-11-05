`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Igor Sadowski
// 
// Create Date:
// Design Name: 
// Module Name: Parallel I/O (PARIO)
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Parallel I/O for MIPS processor
//////////////////////////////////////////////////////////////////////////////////

module pario(
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire [31:0] i_addr,   // Endereço vindo da CPU
    input  wire [31:0] i_wdata,  // Dado vindo da CPU (sw)
    input  wire        i_we,     // Write enable
    input  wire        i_re,     // Read enable
    output reg  [31:0] o_rdata,  // Dado a devolver para a CPU (lw)
    output wire [2:0] o_led,    // Ligação física aos LEDs da Zybo
    input  wire [3:0] i_switch  // Ligação física aos switches da Zybo
    );

    // Registo do LED (mapeado no endereço 0x80000000)
    reg [3:0] _led_reg;

    always @(posedge i_clk) begin
        if (i_rst) begin
            _led_reg <= 4'b0;
        end else if (i_we && (i_addr[7:0] == 8'h00)) begin
            // Se o CPU fez um sw e o endereço é o base (00), grava o LED
            _led_reg <= i_wdata[3:0];
        end
    end

    assign o_led = _led_reg;

    // Lógica de Leitura (lw)
    always @(*) begin
        if (i_re) begin
            






            
        end
    end
endmodule