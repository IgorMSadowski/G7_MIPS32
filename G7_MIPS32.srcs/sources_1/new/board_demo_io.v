`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Igor Sadowski
// 
// Create Date:
// Design Name: 
// Module Name: Board Demo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Board Demo for MIPS processor
//
//
// Zybo demo
// Start with SW0 and SW1 off. Press and release BTN0 to reset.
// Flip SW0, then SW1, then press BTN1. LD3-LD1 finish at 101.
// LD0 shows the reset button.
//
//     lui  $t4, 0x1000          # 0x00: MMIO base = 0x10000000
//     addi $t4, $t4, 0x0100    # 0x04: Board test page = 0x10000100
//     addi $t0, $zero, 1        # 0x08: SW0 mask
//     addi $t1, $zero, 2        # 0x0C: SW1 mask and LED pattern 010
//
// wait_sw0:                     # 0x10
//     lw   $t2, 0x00($t4)       # 0x10: Read SW0 and SW1 at 0x10000100
//     and  $t2, $t2, $t0        # 0x14: Keep SW0
//     beq  $t2, $zero, wait_sw0 # 0x18: Return to 0x10 while SW0 is off
//     sw   $t1, 0x08($t4)       # 0x1C: Display 010 at 0x10000108
//
// wait_sw1:                     # 0x20
//     lw   $t2, 0x00($t4)       # 0x20: Read SW0 and SW1 at 0x10000100
//     and  $t2, $t2, $t1        # 0x24: Keep SW1
//     beq  $t2, $zero, wait_sw1 # 0x28: Return to 0x20 while SW1 is off
//
//     addi $t3, $zero, 5        # 0x2C: Binary 101
//     sw   $t3, 0($zero)        # 0x30: Save 101 in data RAM at 0x00000000
//     addi $t3, $zero, 0        # 0x34: Clear the register before reading RAM
//
// wait_btn1:                    # 0x38
//     lw   $t2, 0x04($t4)       # 0x38: Read BTN1 at 0x10000104
//     beq  $t2, $zero, wait_btn1 # 0x3C: Return to 0x38 while BTN1 is low
//
//     lw   $t3, 0($zero)        # 0x40: Recover 101 from data RAM
//     sw   $t3, 0x08($t4)       # 0x44: Display the value fetched from RAM
//
// done:                         # 0x48
//     j    done                 # 0x48: Hold the final LED pattern
// }
//////////////////////////////////////////////////////////////////////////////////

module board_demo_io(
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire [1:0]  i_sw,
    input  wire        i_btn1,
    input  wire [7:0]  i_offset,
    input  wire        i_re,
    input  wire        i_we,
    input  wire [2:0]  i_led_pattern,
    output reg  [31:0] o_rdata,
    output reg  [2:0]  o_led
    );

    localparam [7:0] SWITCH_OFFSET = 8'h00;
    localparam [7:0] BUTTON_OFFSET = 8'h04;
    localparam [7:0] LED_OFFSET    = 8'h08;

    (* ASYNC_REG = "TRUE" *) reg [2:0] inputs_meta;
    (* ASYNC_REG = "TRUE" *) reg [2:0] inputs_sync;

    always @(posedge i_clk) begin
        inputs_meta <= {i_btn1, i_sw};
        inputs_sync <= inputs_meta;
    end

    always @(posedge i_clk) begin
        if (i_rst) begin
            o_rdata <= 32'b0;
            o_led   <= 3'b000;
        end else begin
            if (i_re) begin
                case (i_offset)
                    SWITCH_OFFSET: o_rdata <= {30'b0, inputs_sync[1:0]};
                    BUTTON_OFFSET: o_rdata <= {31'b0, inputs_sync[2]};
                    default:       o_rdata <= 32'b0;
                endcase
            end

            if (i_we && (i_offset == LED_OFFSET))
                o_led <= i_led_pattern;
        end
    end
endmodule
