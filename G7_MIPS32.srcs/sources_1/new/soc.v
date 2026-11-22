`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// University of Minho 
// Engineer: Igor Sadowski
// 
// Module Name: System on Chip (SoC)
// Description: SoC for MIPS processor
//              Connects the CPU to instruction ROM and the data bus.
//////////////////////////////////////////////////////////////////////////////////

module soc #(
    // Board bitstream: "/home/igor/Documents/Vivado_Projects/G7_MIPS32/Assembly/soc_board_demo.mem"
    // SoC timing test: "/home/igor/Documents/Vivado_Projects/G7_MIPS32/Assembly/soc_test.mem"
    parameter MEM_INIT_FILE = "/home/igor/Documents/Vivado_Projects/G7_MIPS32/Assembly/soc_board_demo.mem"
) (
    input  wire        i_clk,       // 125 MHz board clock on K17
    input  wire        i_rst,       // Reset button on the Zybo (Btn_0)
    input  wire [1:0]  i_sw,        // SW0 and SW1
    input  wire        i_btn1,      // BTN1
    output wire [3:0]  o_led        // LD0 reset, LD3-LD1 program output
    );

    wire clk_50mhz;
    wire clock_locked;

    clk_wiz_0 u_clock (
        .clk_in1(i_clk),
        .clk_out1(clk_50mhz),
        .reset(i_rst),
        .locked(clock_locked)
    );

    // Request reset while the button is pressed or the clock is not ready.
    wire reset_request = i_rst | ~clock_locked;

    // UG949 single-bit CDC: asynchronously assert reset, synchronously release it.
    wire soc_reset;

    xpm_cdc_async_rst #(
        .DEST_SYNC_FF(2),
        .INIT_SYNC_FF(0),
        .RST_ACTIVE_HIGH(1)
    ) u_reset_sync (
        .src_arst(reset_request),
        .dest_clk(clk_50mhz),
        .dest_arst(soc_reset)
    );

    // CPU memory bus wires
    wire        _imem_en;       // CPU-controlled ROM advance
    wire [31:0] _instr;         // Instruction word returned from IMEM
    wire [31:0] _pc;            // Program counter / IMEM address from CPU
    (* KEEP = "TRUE" *) wire [31:0] _alu_out;       // ALU result - doubles as DMEM address
    (* KEEP = "TRUE" *) wire [31:0] _wdata;         // Write data for DMEM (rt register value for sw)
    wire [31:0] _rdata;         // Read data returned to the CPU
    wire        _mem_read;      // CPU issues a read (lw)
    wire        _mem_write;     // CPU commits a write (sw)
    wire        _en;            // Global CPU enable (active-high, derived from reset)

    assign _en = ~soc_reset;        // CPU runs while reset is deasserted

    wire [31:0] ram_rdata;
    wire ram_read;
    (* KEEP = "TRUE" *) wire        ram_write;
    wire [31:0] demo_rdata;
    wire        demo_read, demo_write;
    wire [7:0]  mmio_offset;

    data_bus u_data_bus (
        .i_clk(clk_50mhz),
        .i_rst(soc_reset),
        .i_addr(_alu_out),
        .i_re(_mem_read),
        .i_we(_mem_write),
        .i_ram_rdata(ram_rdata),
        // Reserved pages until the I2S and IRQ register interfaces are connected.
        .i_i2s_rdata(32'b0),
        .i_irq_rdata(32'b0),
        .i_extra_rdata(demo_rdata),
        .o_ram_re(ram_read),
        .o_ram_we(ram_write),
        .o_i2s_re(),
        .o_i2s_we(),
        .o_irq_re(),
        .o_irq_we(),
        .o_extra_re(demo_read),
        .o_extra_we(demo_write),
        .o_mmio_offset(mmio_offset),
        .o_rdata(_rdata)
    );

    board_demo_io u_demo_io (
        .i_clk(clk_50mhz),
        .i_rst(soc_reset),
        .i_sw(i_sw),
        .i_btn1(i_btn1),
        .i_offset(mmio_offset),
        .i_re(demo_read),
        .i_we(demo_write),
        .i_led_pattern(_wdata[2:0]),
        .o_rdata(demo_rdata),
        .o_led(o_led[3:1])
    );
    assign o_led[0] = i_rst;

    instruction_memory #(
        .MEM_INIT_FILE(MEM_INIT_FILE)
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
        .i_re(ram_read),
        .i_we(ram_write),
        .o_rdata(ram_rdata)
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

endmodule
