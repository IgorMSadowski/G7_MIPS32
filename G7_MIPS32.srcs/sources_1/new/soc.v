`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// University of Minho 
// Engineer: Igor Sadowski
// 
// Module Name: System on Chip (SoC)
// Description: SoC for MIPS processor
//              Instantiates CPU, IMEM, DMEM, and LED output.
//////////////////////////////////////////////////////////////////////////////////

module soc(
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
    wire [31:0] _rdata;         // Read data returned from DMEM (lw result)
    wire        _mem_read;      // CPU requests DMEM read (1 = lw)
    wire        _mem_write;     // CPU requests DMEM write (1 = sw)
    wire        _en;            // Global CPU enable (active-high, derived from reset)

    
    // Instead of individual muxes, all devices share this single bi-directional bus.
    tri [31:0] data;

    // -------------------------------------------------------------------------
    // Peripheral address decoding
    // -------------------------------------------------------------------------
    wire [31:0] _addr = _alu_out; 
    
    // Sinais de seleção (Chip Select)
    // Bit 31 is 0 (0x0000...) -> Data Memory
    // Bit 31 is 1 (0x8000...) -> MMIO Peripherals (io_nxt)
    wire io_nxt = _addr[31]; 

    // Wires for DMEM and Control Bus
    wire [31:0] _rdata_dmem;
    wire [31:0] _ctrl;
    wire [7:0]  _sel;
    wire [7:0]  _per_rdy;

    assign _en = ~i_rst;        // CPU runs while reset is deasserted

    // The CPU drives the bus ONLY when writing to memory or IO.
    assign data = (_mem_write & _en & ~i_rst) ? _wdata : 32'bz;
    
    // The CPU reads directly from the shared bus.
    assign _rdata = data;


    instruction_memory u_imem(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_en(_en),
        .i_addr(_pc),           // Instruction Memory address (current PC)
        .o_instr(_instr)        // Instruction word returned (valid one cycle later)
    );

    
    // We gate the read and write enables with ~io_nxt to protect DMEM 
    // from peripheral accesses.
    data_memory u_dmem(
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_en(_en),
        .i_addr(_alu_out),
        .i_wdata(_wdata),
        .i_re(_mem_read & ~io_nxt),   
        .i_we(_mem_write & ~io_nxt),  
        .o_rdata(_rdata_dmem)
    );

    // Drive DMEM output onto the Tri-state bus ONLY when reading memory
    assign data = (_mem_read & ~io_nxt & _en & ~i_rst) ? _rdata_dmem : 32'bz;

    
    // Compresses control signals into a single bus and generates selectors.
    ctrl_enc u_ctrl_enc (
        .clk(i_clk), 
        .rst(i_rst), 
        .io(io_nxt),           // Pass the MSB (Bit 31) as the IO select signal
        .io_ad(_addr),         // Pass the address
        .lw(_mem_read), 
        .lb(1'b0), 
        .sw(_mem_write), 
        .sb(1'b0),
        .ctrl(_ctrl), 
        .sel(_sel)
    );


    // sel[0] is active when address bits [11:8] == 0000
    pario u_pario (
        .ctrl(_ctrl), 
        .sel(_sel[0]), 
        .i({1'b0, i_btn, i_sw}), // Combining 3 buttons and 4 switches into 8 bits
        .data(data),             // Connected to the shared tri-state bus
        .o({o_led[3:1], 1'b0})   // LEDs 1 to 3 (LED 0 is reset)
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
        .o_mem_write(_mem_write)
    );

    // LED wired to reset button 
    assign o_led[0] = i_rst; 

endmodule