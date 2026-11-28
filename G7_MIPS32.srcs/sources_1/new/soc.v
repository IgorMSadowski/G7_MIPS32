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
    // Board clock and reset
    input  wire        i_clk,         // 125 MHz board clock on K17
    input  wire        i_rst,         // Reset button on the Zybo (Btn_0)

    // Board inputs
    input  wire [1:0]  i_sw,          // SW0 and SW1
    input  wire        i_btn1,        // Polled by the board demo
    input  wire        i_btn3,        // IRQ source 3

    // Board outputs
    output wire [3:0]  o_led          // LD0 reset, LD3-LD1 program output
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
    wire        demo_read;
    wire        demo_write;
    wire [7:0]  mmio_offset;

    wire        irq_read;
    wire        irq_write;
    wire [31:0] irq_rdata;
    wire        irq_request;
    wire        irq_ack;
    wire        irq_return;
    wire [31:0] irq_vector;
    wire [31:0] irq_return_pc;

    data_bus u_data_bus (
        .i_clk(clk_50mhz),
        .i_rst(soc_reset),

        .i_addr(_alu_out),
        .i_re(_mem_read),
        .i_we(_mem_write),

        .i_ram_rdata(ram_rdata),
        .i_irq_rdata(irq_rdata),
        // The I2S page is reserved until the peripheral is connected.
        .i_i2s_rdata(32'b0),
        .i_extra_rdata(demo_rdata),

        .o_rdata(_rdata),

        .o_ram_re(ram_read),
        .o_ram_we(ram_write),

        .o_mmio_offset(mmio_offset),
        .o_irq_re(irq_read),
        .o_irq_we(irq_write),
        .o_i2s_re(),
        .o_i2s_we(),
        .o_extra_re(demo_read),
        .o_extra_we(demo_write)
    );

    // Synchronize the physical button to the SoC clock before detecting a press.
    wire btn3_synchronized;
    reg btn3_previous;

    xpm_cdc_single #(
        .DEST_SYNC_FF(2),
        .SRC_INPUT_REG(0),
        .INIT_SYNC_FF(1),
        .SIM_ASSERT_CHK(0)
    ) u_btn3_sync (
        .src_clk(1'b0),
        .src_in(i_btn3 && !soc_reset),
        .dest_clk(clk_50mhz),
        .dest_out(btn3_synchronized)
    );

    // Keep the synchronized button value from the previous clock cycle.
    always @(posedge clk_50mhz) begin
        if (soc_reset)
            btn3_previous <= 1'b0;
        else
            btn3_previous <= btn3_synchronized;
    end

    // Send a one-cycle IRQ3 event when the synchronized button goes high.
    wire btn3_pressed_pulse = !soc_reset && btn3_synchronized && !btn3_previous;

    interrupt_controller u_irq (
        .i_clk(clk_50mhz),
        .i_rst(soc_reset),

        // Bit 3 carries the BTN3 press pulse to IRQ3.
        // Bit 2 is unused. Bits 1 and 0 are reserved for I2S and held at 0.
        .i_events({btn3_pressed_pulse, 3'b000}),

        .i_irq_ack(irq_ack),
        .i_irq_return(irq_return),
        .i_return_pc(irq_return_pc),

        .i_offset(mmio_offset),
        .i_re(irq_read),
        .i_we(irq_write),
        .i_wdata(_wdata),

        .o_irq_request(irq_request),
        .o_irq_vector(irq_vector),

        .o_rdata(irq_rdata)
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
        .i_addr(_pc),           // Instruction Memory address (current PC),

        .o_instr(_instr)        // Instruction word returned (valid one cycle later)
    );

    data_memory u_dmem(
        .i_clk(clk_50mhz),
        .i_rst(soc_reset),
        .i_en(_en),

        .i_addr(_alu_out),
        .i_re(ram_read),
        .i_we(ram_write),
        .i_wdata(_wdata),

        .o_rdata(ram_rdata)
    );

    cpu u_cpu(
        .i_clk(clk_50mhz),
        .i_rst(soc_reset),
        .i_en(_en),

        .i_instr(_instr),
        .i_rdata(_rdata),

        .i_irq_request(irq_request),
        .i_irq_vector(irq_vector),

        .o_pc(_pc),
        .o_imem_en(_imem_en),

        .o_alu_out(_alu_out),
        .o_wdata(_wdata),
        .o_mem_read(_mem_read),
        .o_mem_write(_mem_write),

        .o_irq_ack(irq_ack),
        .o_irq_return(irq_return),
        .o_return_pc(irq_return_pc)
    );

endmodule
