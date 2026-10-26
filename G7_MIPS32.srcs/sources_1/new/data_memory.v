`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// University of Minho 
// Engineer: Igor Sadowski
// 
// Module Name: Data Memory (DMEM)
// Description: Data memory for MIPS processor
//////////////////////////////////////////////////////////////////////////////////

// Data memory (RAM) - BRAM, latency 1

module data_memory(
    input  wire        i_clk,       // Clock
    input  wire        i_rst,       // Reset
    input  wire        i_en,        // Global enable
    input  wire [31:0] i_addr,      // Byte address (ALU result)
    input  wire [31:0] i_wdata,     // Write data (rt value for sw)
    input  wire        i_re,        // Read enable (lw)
    input  wire        i_we,        // Write enable (sw)
    output wire [31:0] o_rdata      // Read data output
    );

    wire [5:0] _addr_w;             // Word address to XPM
    assign _addr_w = i_addr[7:2];   // 64 words × 4 bytes

    xpm_memory_spram #(
        .ADDR_WIDTH_A(6),           // 6-bit word address
        .AUTO_SLEEP_TIME(0),        // no auto power-down
        .BYTE_WRITE_WIDTH_A(8),     // byte-granular writes → 4-bit wea
        .CASCADE_HEIGHT(0),         // no cascading
        .ECC_BIT_RANGE("7:0"),      // (unused; ECC disabled)
        .ECC_MODE("no_ecc"),        // no error correction
        .ECC_TYPE("none"),          // (unused; ECC disabled)
        .IGNORE_INIT_SYNTH(0),      // honor init params
        .MEMORY_INIT_FILE("none"),  // DMEM starts undefined
        .MEMORY_INIT_PARAM("0"),    // all-zero init if file absent
        .MEMORY_OPTIMIZATION("true"),// allow init optimization
        .MEMORY_PRIMITIVE("block"), // ★ BRAM, not LUTRAM
        .MEMORY_SIZE(2048),         // 64 words × 32 bits = 2 Kbit
        .MESSAGE_CONTROL(0),        // quiet simulation
        .RAM_DECOMP("auto"),        // let Vivado choose decomposition
        .READ_DATA_WIDTH_A(32),     // 32-bit output
        .READ_LATENCY_A(1),         // ★ 1-cycle BRAM latency
        .READ_RESET_VALUE_A("0"),   // douta = 0 while rsta asserted
        .RST_MODE_A("SYNC"),        // synchronous reset
        .SIM_ASSERT_CHK(0),         // no assertions
        .USE_MEM_INIT(1),           // allow init
        .USE_MEM_INIT_MMI(0),       // no MMI file
        .WAKEUP_TIME("disable_sleep"),// never sleep
        .WRITE_DATA_WIDTH_A(32),    // 32-bit write data
        .WRITE_MODE_A("read_first"),// douta = old data on same-cycle write
        .WRITE_PROTECT(1)           // allow writes after initial load
    ) dmem_xpm (
        .addra(_addr_w),            // Word address
        .clka(i_clk),               // Clock
        .dina(i_wdata),             // Write data
        .ena(i_en | i_re | i_we),   // enable on any access
        .wea({4{i_we}}),            // 4-bit byte write enable
        .douta(o_rdata),            // ★ output drives port directly
        .injectsbiterra(1'b0),      // no ECC error injection
        .injectdbiterra(1'b0),      // no ECC error injection
        .regcea(1'b1),              // always enable output register
        .rsta(i_rst),               // reset output on reset
        .sleep(1'b0)                // never sleep
    );

endmodule