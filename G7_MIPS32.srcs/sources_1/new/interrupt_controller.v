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

// Interrupt conventions
//
// i_events[n] sets pending[n]. The lowest numbered enabled source wins.
// Each source has one pending bit, so repeated events can merge. ACK clears
// the accepted bit and retains any new events on the same clock edge.
//
// IRQ0, IRQ1, IRQ2 and IRQ3 enter at ROM byte addresses 0x04, 0x08, 0x0C and
// 0x10. Each slot holds a jump to its ISR. The SoC connects BTN3 to IRQ3.
//
// MMIO registers
// 0x10000000  ENABLE     R/W   Bit 4 is global enable, bits [3:0] enable sources.
// 0x10000004  PENDING    R/O   Bits [3:0] show the pending sources.
// 0x10000008  RETURN_PC  R/O   The saved_pc register in the CPU datapath.
// For example, writing 0x18 enables IRQ3 and sets the global enable bit.
//
// On entry, the CPU finishes the current instruction, saves its normal next
// PC and sends ACK. ACK clears global enable so the ISR can save that address
// before a nested IRQ can overwrite saved_pc. The controller exposes the
// address over MMIO. The ISR saves and restores it using the RAM stack.
//
// With $t0 holding 0x10000000 and $sp pointing to the current stack top:
//     lw   $k1, 8($t0)      Read RETURN_PC while interrupts are masked.
//     addi $sp, $sp, -4    Allocate one word on the stack.
//     sw   $k1, 0($sp)     Push this ISR's return address.
//
// Save any other registers the ISR modifies before re-enabling interrupts.
// The CPU allows two active ISR levels. At depth 2, further requests wait
// in pending until a level is available.
//
// Before returning, mask new IRQs and restore the registers saved by the ISR.
//     lw   $k1, 0($sp)     Pop this ISR's return address into $k1.
//     addi $sp, $sp, 4     Free the stack word.
//     jr   $k1             Jump to $k1 and finish the current IRQ level.
//
// On that JR's commit edge, the CPU decrements irq_depth and sends
// i_irq_return to the controller. The controller restores global enable
// without changing the individual source enables.

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
