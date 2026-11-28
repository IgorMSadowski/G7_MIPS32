`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Igor Sadowski
// 
// Create Date:
// Design Name: 
// Module Name: Data Bus
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Data Bus for MIPS processor
//
//////////////////////////////////////////////////////////////////////////////////

module data_bus (
    // Clock and reset
    input  wire        i_clk,
    input  wire        i_rst,

    // CPU access request
    input  wire [31:0] i_addr,
    input  wire        i_re,
    input  wire        i_we,

    // Read data from RAM and MMIO devices
    input  wire [31:0] i_ram_rdata,
    input  wire [31:0] i_irq_rdata,
    input  wire [31:0] i_i2s_rdata,
    input  wire [31:0] i_extra_rdata,

    // Read data to the CPU
    output reg  [31:0] o_rdata,

    // RAM access control
    output wire        o_ram_re,
    output wire        o_ram_we,

    // MMIO offset and device access control
    output wire [7:0]  o_mmio_offset,
    output wire        o_irq_re,
    output wire        o_irq_we,
    output wire        o_i2s_re,
    output wire        o_i2s_we,
    output wire        o_extra_re,
    output wire        o_extra_we
    );

    // The CPU supplies a 32-bit byte address.
    // RAM  [31:10] | [9:0]                  region | byte position in RAM
    //      00_0000_0000_0000_0000_0000 | 11_1111_1100  (0x000003FC)
    // MMIO [31:12] | [11:8] | [7:0]         region | device page | byte offset
    //      0001_0000_0000_0000_0000 | 0000 | 0000_0100  (IRQ at offset 0x04)
    //      0001_0000_0000_0000_0000 | 0011 | 0000_1000  (I2S at offset 0x08)
    // The RAM module uses [9:2] to select one of its 256 words.

    // 0x00000000 to 0x000003FF: RAM, with address bits [31:10] equal to zero.
    wire ram_selected = (i_addr[31:10] == 22'h000000);
    // 0x10000000 to 0x10000FFF: MMIO, with address bits [31:12] equal to 0x10000.
    wire mmio_selected = (i_addr[31:12] == 20'h10000);
    // 0x10000000 to 0x100000FF: interrupt controller page 0x0.
    wire irq_selected = mmio_selected && (i_addr[11:8] == 4'h0);
    // 0x10000300 to 0x100003FF: I2S page 0x3.
    wire i2s_selected = mmio_selected && (i_addr[11:8] == 4'h3);

    // 0x10000100 to 0x100001FF: board demo I/O page 0x1.
    wire extra_selected = mmio_selected && (i_addr[11:8] == 4'h1);

    // A decoded destination gets a read or write enable only when
    // the CPU asserts i_re or i_we. This decode is combinational.
    assign o_ram_re = ram_selected && i_re;
    assign o_ram_we = ram_selected && i_we;
    assign o_i2s_re = i2s_selected && i_re;
    assign o_i2s_we = i2s_selected && i_we;
    assign o_irq_re = irq_selected && i_re;
    assign o_irq_we = irq_selected && i_we;
    
    assign o_extra_re = extra_selected && i_re;
    assign o_extra_we = extra_selected && i_we;
    // The low byte is always available. A peripheral uses it to
    // select an internal register when its own enable is asserted.
    assign o_mmio_offset = i_addr[7:0];

    reg read_from_ram;
    reg read_from_i2s;
    reg read_from_irq;
    reg read_from_extra;

    // Save the read destination at the rising edge while i_re is high.
    // With i_re low, keep that destination selected during CPU write-back.
    always @(posedge i_clk) begin
        if (i_rst) begin
            read_from_ram <= 1'b0;
            read_from_i2s <= 1'b0;
            read_from_irq <= 1'b0;
            read_from_extra <= 1'b0;
        end else if (i_re) begin
            read_from_ram <= ram_selected;
            read_from_i2s <= i2s_selected;
            read_from_irq <= irq_selected;
            read_from_extra <= extra_selected;
        end
    end

    // The read mux uses the saved destination. An unmapped read
    // saves all zeros, so the mux returns zero after the rising edge.
    always @(*) begin
        if (read_from_ram)
            o_rdata = i_ram_rdata;
        else if (read_from_i2s)
            o_rdata = i_i2s_rdata;
        else if (read_from_irq)
            o_rdata = i_irq_rdata;
        else if (read_from_extra)
            o_rdata = i_extra_rdata;
        else
            o_rdata = 32'b0;
    end
endmodule
