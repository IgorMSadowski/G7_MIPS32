`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// University of Minho 
// Engineer: Igor Sadowski
// 
// Module Name: System on Chip (SoC)
// Description: SoC for MIPS processor
//              Connects the CPU, memories, data bus and ParIO.
//////////////////////////////////////////////////////////////////////////////////

module soc #(
    parameter IMEM_INIT_FILE = "/home/igor/Documents/Vivado_Projects/G7_MIPS32/Assembly/imem_init.mem"
)(
    input  wire        i_clk,      
    input  wire        i_rst,       // Reset button on the Zybo (Btn_0)
    input  wire [3:0]  i_sw,        // Switches (SW0 to SW3)
    input  wire [3:1]  i_btn,       // Buttons 1 to 3 (Btn_1 to Btn_3)
    output wire [3:0]  o_led        // LEDs (LD0 to LD3) LD0 is the reset indicator
    );

    // CPU memory bus wires
    wire [31:0] _instr;         // Instruction word returned from IMEM
    wire [31:0] _pc;            // Program counter / IMEM address from CPU
    wire [31:0] _alu_out;       // ALU result - doubles as DMEM address
    wire [31:0] _wdata;         // Write data for DMEM (rt register value for sw)
    wire [31:0] _rdata;         // Read response returned by the data bus
    wire        _mem_read;      // CPU requests DMEM read (1 = lw)
    wire        _mem_write;     // CPU requests DMEM write (1 = sw)
    wire        _en;            // Global CPU enable (active-high, derived from reset)

    wire [31:0] ram_read_data;
    wire [31:0] pario_read_data;
    wire        ram_read_enable;
    wire        ram_write_enable;
    wire        pario_read_enable;
    wire        pario_write_enable;
    wire        load_complete;
    wire        read_response_valid;

    assign _en = ~i_rst;        // CPU runs while reset is deasserted


    instruction_memory #(
        .MEM_INIT_FILE(IMEM_INIT_FILE)
    ) u_imem(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_en(_en),
        .i_addr(_pc),           // Instruction Memory address (current PC)
        .o_instr(_instr)        // Instruction word returned (valid one cycle later)
    );

    data_bus u_data_bus(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_en(_en),
        .i_address(_alu_out),
        .i_read_request(_mem_read),
        .i_write_request(_mem_write),
        .i_ram_read_data(ram_read_data),
        .i_pario_read_data(pario_read_data),
        .i_load_complete(load_complete),
        .o_ram_read_enable(ram_read_enable),
        .o_ram_write_enable(ram_write_enable),
        .o_pario_read_enable(pario_read_enable),
        .o_pario_write_enable(pario_write_enable),
        .o_read_data(_rdata),
        .o_read_response_valid(read_response_valid)
    );

    data_memory u_dmem(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_en(_en),
        .i_addr(_alu_out),
        .i_wdata(_wdata),
        .i_re(ram_read_enable),
        .i_we(ram_write_enable),
        .o_rdata(ram_read_data)
    );

    pario u_pario(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_write_enable(pario_write_enable),
        .i_pins({1'b0, i_btn, i_sw}),
        .i_write_data(_wdata),
        .o_read_data(pario_read_data),
        .o_led(o_led[3:1])
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
        .o_mem_read(_mem_read),
        .o_mem_write(_mem_write),
        .o_load_done(load_complete)
    );

    // LED wired to reset button 
    assign o_led[0] = i_rst; 

endmodule