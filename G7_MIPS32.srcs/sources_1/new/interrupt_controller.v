`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Igor Sadowski
// 
// Create Date:
// Design Name: 
// Module Name: Interrupt Controller
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Interrupt Controller for MIPS processor
//////////////////////////////////////////////////////////////////////////////////

module interrupt_controller(
    // Clock and reset
    input  wire        i_clk,
    input  wire        i_rst,

    // Interrupt events
    input  wire [3:0]  i_events,

    // CPU interrupt entry, return and saved address
    input  wire        i_irq_ack,
    input  wire        i_irq_return,
    input  wire [31:0] i_return_pc,

    // MMIO request and write data
    input  wire [7:0]  i_offset,
    input  wire        i_re,
    input  wire        i_we,
    input  wire [31:0] i_wdata,

    // CPU interrupt request and vector
    output wire        o_irq_request,
    output reg  [31:0] o_irq_vector,

    // MMIO read data
    output reg  [31:0] o_rdata
);

    reg       global_enable;
    reg [3:0] source_enable;
    reg [3:0] pending;
    reg [3:0] selected;

    wire [3:0] eligible = pending & source_enable;
    wire write_enable_register = i_we && (i_offset == 8'h00);

    // Apply a mask write before accepting another interrupt.
    assign o_irq_request = global_enable && !write_enable_register && (|eligible);

    always @(*) begin
        selected = 4'b0000;
        o_irq_vector = 32'b0;

        if (o_irq_request) begin
            if (eligible[0]) begin
                selected = 4'b0001;
                o_irq_vector = 32'h00000004;
            end else if (eligible[1]) begin
                selected = 4'b0010;
                o_irq_vector = 32'h00000008;
            end else if (eligible[2]) begin
                selected = 4'b0100;
                o_irq_vector = 32'h0000000C;
            end else begin
                selected = 4'b1000;
                o_irq_vector = 32'h00000010;
            end
        end
    end

    always @(posedge i_clk) begin
        if (i_rst) begin
            global_enable <= 1'b0;
            source_enable <= 4'b0000;
            pending       <= 4'b0000;
            o_rdata       <= 32'b0;
        end else begin
            // Protect the ISR until it saves its return address.
            if (i_irq_ack)
                global_enable <= 1'b0;
            // Each accepted IRQ interrupted a context with global enable set.
            else if (i_irq_return)
                global_enable <= 1'b1;
            else if (write_enable_register)
                global_enable <= i_wdata[4];

            if (write_enable_register)
                source_enable <= i_wdata[3:0];

            // Clear the accepted source. A new event on this edge stays pending.
            if (i_irq_ack)
                pending <= (pending & ~selected) | i_events;
            else
                pending <= pending | i_events;

            // Capture the reply on the read edge and hold it for LW write-back.
            if (i_re) begin
                case (i_offset)
                    8'h00:   o_rdata <= {27'b0, global_enable, source_enable};
                    8'h04:   o_rdata <= {28'b0, pending};
                    8'h08:   o_rdata <= i_return_pc;  // Read-only saved PC
                    default: o_rdata <= 32'b0;
                endcase
            end
        end
    end
endmodule
