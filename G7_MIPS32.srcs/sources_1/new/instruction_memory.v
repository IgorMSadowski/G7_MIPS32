`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// University of Minho 
// Engineer: Igor Sadowski
// 
// Module Name: Instruction Memory (IMEM)
// Description: Instruction memory for MIPS processor
//////////////////////////////////////////////////////////////////////////////////

// Instruction memory (ROM) - BRAM, latency 1

module instruction_memory #(
    parameter MEM_INIT_FILE = "/home/igor/Documents/Vivado_Projects/G7_MIPS32/Assembly/imem_init.mem"
)(
    input  wire        i_clk,       // Clock
    input  wire        i_rst,       // Reset
    input  wire        i_en,        // Enable
    input  wire [31:0] i_addr,      // Byte address from PC
    output wire [31:0] o_instr      // Instruction word output
    );

    wire [7:0] _addr_w;
    assign _addr_w = i_addr[9:2];  // 256 words x 4 bytes; byte address to word index

    xpm_memory_sprom #(
        .ADDR_WIDTH_A(8),          // 8-bit word address = 256 words
        .AUTO_SLEEP_TIME(0),        
        .CASCADE_HEIGHT(0),         
        .ECC_MODE("no_ecc"),        
        .ECC_TYPE("none"),          
        .IGNORE_INIT_SYNTH(0),      
        .MEMORY_INIT_FILE(MEM_INIT_FILE),
        .MEMORY_INIT_PARAM("0"),    
        .MEMORY_OPTIMIZATION("true"),
        .MEMORY_PRIMITIVE("block"), // BRAM
        .MEMORY_SIZE(8192),        // 256 words x 32 bits = 1 KiB
        .MESSAGE_CONTROL(0),        
        .RAM_DECOMP("auto"),        
        .READ_DATA_WIDTH_A(32),     
        .READ_LATENCY_A(1),         // 1-cycle BRAM latency
        .READ_RESET_VALUE_A("0"),   
        .RST_MODE_A("SYNC"),        
        .SIM_ASSERT_CHK(0),         
        .USE_MEM_INIT(1),           
        .USE_MEM_INIT_MMI(0),       
        .WAKEUP_TIME("disable_sleep") 
    ) imem_xpm (
        .addra(_addr_w),            // Word address
        .clka(i_clk),               // Clock
        .ena(i_en),                 // Enable
        .douta(o_instr),            // Data output
        .injectsbiterra(1'b0),      
        .injectdbiterra(1'b0),      
        .regcea(1'b1),              
        .rsta(i_rst),               
        .sleep(1'b0)                
    );

endmodule