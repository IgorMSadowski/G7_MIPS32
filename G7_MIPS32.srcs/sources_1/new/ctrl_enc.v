`timescale 1ns / 1ps
// Module: ctrl_enc
// Description: Compresses control signals into a 32-bit bus.
module ctrl_enc( 
    input  wire        clk, 
    input  wire        rst, 
    input  wire        io,       // 1 if accessing MMIO space (Bit 31 = 1)
    input  wire [31:0] io_ad,    // Address of the peripheral
    input  wire        lw,       // Load Word
    input  wire        lb,       // Load Byte
    input  wire        sw,       // Store Word
    input  wire        sb,       // Store Byte
    output wire [31:0] ctrl,     // Compressed control bus
    output wire [7:0]  sel       // Peripheral Chip Selects
);
    wire [3:0] oe, we;
    
    // Output Enable (Read) and Write Enable (Write) for 32-bit word
    assign oe[0] = io & (lw | lb); 
    assign oe[1] = io & lw;        
    assign oe[2] = 0;              
    assign oe[3] = 0;
    
    assign we[0] = io & (sw | sb); 
    assign we[1] = io & sw;        
    assign we[2] = 0;
    assign we[3] = 0;

    // Pack the bus: {oe, we, address[11:0], rst, clk}
    // We use io_ad[11:0] to give us room for 4096 peripherals/sub-registers.
    assign ctrl = {10'b0, oe, we, io_ad[11:0], rst, clk};

    // Decode the specific peripheral based on bits [11:8] of the address.
    // This is exactly like the professor's code, but for 32-bit addresses.
    assign sel[0] = io & (io_ad[11:8] == 4'h0); // 0x80000000 - ParIO
    assign sel[1] = io & (io_ad[11:8] == 4'h1); // 0x80000100 - Timer
    assign sel[2] = io & (io_ad[11:8] == 4'h2); // 0x80000200 - Future
    assign sel[3] = io & (io_ad[11:8] == 4'h3); 
    assign sel[4] = 0;
    assign sel[5] = 0;
    assign sel[6] = 0;
    assign sel[7] = 0;
endmodule