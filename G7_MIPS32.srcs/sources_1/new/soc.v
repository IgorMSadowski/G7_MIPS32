`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// University of Minho 
// Engineer: Igor Sadowski
// 
// Module Name: System on Chip (SoC)
// Description: SoC for MIPS processor
//              Instantiates CPU, IMEM, DMEM, and LED output.
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

    // Address and peripheral decode
    wire [31:0] _addr = _alu_out;
    wire [31:0] _rdata_dmem;
    wire [31:0] _rdata_pario;
    wire [31:0] _ctrl;
    wire [7:0]  _sel;
    wire        _dmem_re;
    wire        _dmem_we;
    wire        _mmio_re;
    wire        _mmio_we;
    wire        _load_done;
    wire        _rsp_valid;

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

    // Decode requests and hold read responses until the CPU commits a load.
    data_bus u_data_bus(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_en(_en),
        .i_addr(_addr),
        .i_mem_read(_mem_read),
        .i_mem_write(_mem_write),
        .i_io_sel(|_sel),
        .i_dmem_rdata(_rdata_dmem),
        .i_mmio_rdata(_rdata_pario),
        .i_rsp_consume(_load_done),
        .o_dmem_re(_dmem_re),
        .o_dmem_we(_dmem_we),
        .o_mmio_re(_mmio_re),
        .o_mmio_we(_mmio_we),
        .o_rdata(_rdata),
        .o_rsp_valid(_rsp_valid)
    );

    data_memory u_dmem(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_en(_en),
        .i_addr(_alu_out),
        .i_wdata(_wdata),
        .i_re(_dmem_re),
        .i_we(_dmem_we),
        .o_rdata(_rdata_dmem)
    );

    ctrl_enc u_ctrl_enc (
        .clk(i_clk),
        .rst(i_rst),
        .io(_addr[31]),
        .io_ad(_addr),
        .lw(_mem_read),
        .lb(1'b0),
        .sw(_mem_write),
        .sb(1'b0),
        .ctrl(_ctrl),
        .sel(_sel)
    );


    pario u_pario (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_sel(_sel[0]),
        .i_re(_mmio_re),
        .i_we(_mmio_we),
        .i_ctrl(_ctrl),
        .i({1'b0, i_btn, i_sw}),
        .i_wdata(_wdata),
        .o_rdata(_rdata_pario),
        .o_led(o_led[3:1])
    );

    cpu u_cpu(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_en(_en),
        .i_instr(_instr),
        .i_rdata(_rdata),       // Reads from the tri-state bus
        .o_pc(_pc),
        .o_alu_out(_alu_out),
        .o_wdata(_wdata),
        .o_mem_read(_mem_read),
        .o_mem_write(_mem_write),
        .o_load_done(_load_done)
    );

    // LED wired to reset button 
    assign o_led[0] = i_rst; 

endmodule