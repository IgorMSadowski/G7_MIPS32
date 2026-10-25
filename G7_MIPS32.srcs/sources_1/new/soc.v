`timescale 1ns / 1ps

module soc(
    input  wire        i_clk,      
    input  wire        i_rst,       
    output wire [0:0]  o_led       
    );

    // -------------------------------------------------------------------------
    // CPU memory bus wires
    // -------------------------------------------------------------------------
    wire [31:0] _instr;         // Instruction word returned from IMEM
    wire [31:0] _pc;            // Program counter / IMEM address from CPU
    wire [31:0] _alu_out;       // ALU result - doubles as DMEM address
    wire [31:0] _wdata;         // Write data for DMEM (rt register value for sw)
    wire [31:0] _rdata;         // Read data returned from DMEM (lw result)
    wire        _zero;          // ALU zero flag (used by branch unit)
    wire        _mem_read;      // CPU requests DMEM read (1 = lw)
    wire        _mem_write;     // CPU requests DMEM write (1 = sw)
    wire        _en;            // Global CPU enable (active-high, derived from reset)

    assign _en = ~i_rst;        // CPU runs while reset is deasserted

    instruction_memory u_imem(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_en(_en),
        .i_addr(_pc),
        .o_instr(_instr)
    );

    data_memory u_dmem(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_en(_en),
        .i_addr(_alu_out),
        .i_wdata(_wdata),
        .i_re(_mem_read),
        .i_we(_mem_write),
        .o_rdata(_rdata)
    );

    cpu u_cpu(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_en(_en),
        .i_instr(_instr),
        .i_rdata(_rdata),
        .o_pc(_pc),
        .o_alu_out(_alu_out),
        .o_wdata(_wdata),
        .o_zero(_zero),
        .o_mem_read(_mem_read),
        .o_mem_write(_mem_write)
    );

    // LED wired to reset button 
    assign o_led[0] = i_rst; 

endmodule