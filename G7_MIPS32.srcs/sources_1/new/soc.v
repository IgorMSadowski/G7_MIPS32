`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// University of Minho 
// Engineer: Igor Sadowski
// 
// Module Name: System on Chip (SoC)
// Description: SoC for MIPS processor
//              Connects the CPU directly to instruction and data memories.
//////////////////////////////////////////////////////////////////////////////////

module soc #(
    parameter IMEM_INIT_FILE = "/home/igor/Documents/Vivado_Projects/G7_MIPS32/Assembly/test.mem"
)(
    input  wire        i_clk,       // 125 MHz board clock on K17
    input  wire        i_rst,       // Reset button on the Zybo (Btn_0)
    output wire [0:0]  o_led        // LD0 shows the last CPU write to RAM word zero
    );

    wire clk_50mhz;
    wire clock_locked;

    clk_wiz_0 u_clock (
        .clk_in1(i_clk),
        .clk_out1(clk_50mhz),
        .reset(i_rst),
        .locked(clock_locked)
    );

    // Direct reset while the button is pressed or the clock is not locked.
    wire soc_reset = i_rst | ~clock_locked;

    // CPU memory bus wires
    wire        _imem_en;       // CPU-controlled ROM advance
    wire [31:0] _instr;         // Instruction word returned from IMEM
    wire [31:0] _pc;            // Program counter / IMEM address from CPU
    wire [31:0] _alu_out;       // ALU result - doubles as DMEM address
    wire [31:0] _wdata;         // Write data for DMEM (rt register value for sw)
    wire [31:0] _rdata;         // Read data returned by DMEM
    wire        _mem_read;      // CPU requests DMEM read (1 = lw)
    wire        _mem_write;     // CPU requests DMEM write (1 = sw)
    wire        _en;            // Global CPU enable (active-high, derived from reset)

    assign _en = ~soc_reset;        // CPU runs while reset is deasserted

    instruction_memory #(
        .MEM_INIT_FILE(IMEM_INIT_FILE)
    ) u_imem(
        .i_clk(clk_50mhz),
        .i_rst(soc_reset),
        .i_en(_imem_en),
        .i_addr(_pc),           // Instruction Memory address (current PC)
        .o_instr(_instr)        // Instruction word returned (valid one cycle later)
    );

    data_memory u_dmem(
        .i_clk(clk_50mhz),
        .i_rst(soc_reset),
        .i_en(_en),
        .i_addr(_alu_out),
        .i_wdata(_wdata),
        .i_re(_mem_read),
        .i_we(_mem_write),
        .o_rdata(_rdata)
    );

    cpu u_cpu(
        .i_clk(clk_50mhz),
        .i_rst(soc_reset),
        .i_en(_en),
        .i_instr(_instr),
        .i_rdata(_rdata),
        .o_pc(_pc),
        .o_imem_en(_imem_en),
        .o_alu_out(_alu_out),
        .o_wdata(_wdata),
        .o_mem_read(_mem_read),
        .o_mem_write(_mem_write)
    );

    // Diagnostic output: observe a normal RAM write without changing the RAM.
    // RAM byte address 0 is still ordinary memory, not an MMIO register.
    // A nonzero word lights LD0; writing zero turns it off.
    // All 32 data bits contribute to the visible result.
    localparam [31:0] LED_RAM_ADDRESS = 32'h0000_0000;
    reg led_value;

    always @(posedge clk_50mhz or posedge soc_reset) begin
        if (soc_reset)
            led_value <= 1'b0;
        else if (_mem_write && (_alu_out == LED_RAM_ADDRESS))
            led_value <= | _wdata;
    end

    assign o_led[0] = led_value;

endmodule
