`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// University of Minho 
// Engineer: Igor Sadowski
// 
// Module Name: System on Chip (SoC)
// Description: SoC for MIPS processor
//              Connects the CPU to instruction ROM, data RAM, and board GPIO.
//////////////////////////////////////////////////////////////////////////////////

module soc #(
    parameter IMEM_INIT_FILE = "/home/igor/Documents/Vivado_Projects/G7_MIPS32/Assembly/gpio_demo.mem"
)(
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
    wire [31:0] _alu_out;       // ALU result - doubles as DMEM address
    wire [31:0] _wdata;         // Write data for DMEM (rt register value for sw)
    wire [31:0] _rdata;         // Read data returned to the CPU
    wire        _mem_read;      // CPU issues a read (lw)
    wire        _mem_write;     // CPU commits a write (sw)
    wire        _en;            // Global CPU enable (active-high, derived from reset)

    assign _en = ~soc_reset;        // CPU runs while reset is deasserted

    localparam [11:0] SWITCH_OFFSET = 12'h100;  // 0x10000100
    localparam [11:0] BUTTON_OFFSET = 12'h104;  // 0x10000104
    localparam [11:0] LED_OFFSET    = 12'h108;  // 0x10000108

    wire peripheral_selected = _alu_out[28];
    wire [11:0] register_offset = _alu_out[11:0];
    wire [31:0] ram_rdata;
    reg  [1:0]  gpio_rdata;
    reg  [2:0]  led_pattern;

    (* ASYNC_REG = "TRUE" *) reg [2:0] gpio_meta, gpio_sync;

    always @(posedge clk_50mhz) begin
        gpio_meta <= {i_btn1, i_sw};
        gpio_sync <= gpio_meta;
    end

    always @(posedge clk_50mhz) begin
        if (soc_reset) begin
            gpio_rdata  <= 2'b00;
            led_pattern <= 3'b000;
        end else begin
            if (_mem_read && peripheral_selected) begin
                case (register_offset)
                    SWITCH_OFFSET: gpio_rdata <= gpio_sync[1:0];
                    BUTTON_OFFSET: gpio_rdata <= {1'b0, gpio_sync[2]};
                    default:       gpio_rdata <= 2'b00;
                endcase
            end

            if (_mem_write && peripheral_selected && (register_offset == LED_OFFSET))
                led_pattern <= _wdata[2:0];
        end
    end

    // The load holds the same address from read request to write-back.
    assign _rdata = peripheral_selected ? {30'b0, gpio_rdata} : ram_rdata;

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
        .i_re(_mem_read  && !peripheral_selected),
        .i_we(_mem_write && !peripheral_selected),
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

    // LD0 indicates the physical reset input.
    assign o_led[0] = i_rst;
    assign o_led[3:1] = led_pattern;

endmodule
