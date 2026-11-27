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
//////////////////////////////////////////////////////////////////////////////////

// Waits for SW0 then SW1 off and press BTN0 to reset. LD0 shows reset.
// Flip SW0 for 010, then SW1 and press BTN1 for 101.
// Press BTN3 for IRQ3 and 111 on LD3-LD1.
// Release BTN1, then press it again to end the ISR. Main restores 101.
//
// 0x00000000  0x08000005  j    boot                            Reset vector
// 0x00000004  0x00000000  nop                                  IRQ0 reserved for I2S
// 0x00000008  0x00000000  nop                                  IRQ1 reserved for I2S
// 0x0000000C  0x00000000  nop                                  IRQ2 unused
// 0x00000010  0x08000020  j    isr_btn3                        IRQ3 vector
//
// boot:
// 0x00000014  0x3C0C1000  lui  $t4, 0x1000                     MMIO base = 0x10000000
// 0x00000018  0x218C0100  addi $t4, $t4, 0x0100                Board demo page = 0x10000100
// 0x0000001C  0x20080001  addi $t0, $zero, 1                   SW0 mask
// 0x00000020  0x20090002  addi $t1, $zero, 2                   SW1 mask and LED pattern 010
//
// wait_sw0:
// 0x00000024  0x8D8A0000  lw   $t2, 0($t4)                     Read SW0 and SW1
// 0x00000028  0x01485024  and  $t2, $t2, $t0                   Keep SW0
// 0x0000002C  0x1140FFFD  beq  $t2, $zero, wait_sw0            Return to 0x24 while SW0 is off
// 0x00000030  0xAD890008  sw   $t1, 8($t4)                     Display 010 at 0x10000108
//
// wait_sw1:
// 0x00000034  0x8D8A0000  lw   $t2, 0($t4)                     Read SW0 and SW1
// 0x00000038  0x01495024  and  $t2, $t2, $t1                   Keep SW1
// 0x0000003C  0x1140FFFD  beq  $t2, $zero, wait_sw1            Return to 0x34 while SW1 is off
//
// 0x00000040  0x200B0005  addi $t3, $zero, 5                   Binary 101
// 0x00000044  0xAC0B0000  sw   $t3, 0($zero)                   Store 101 at RAM byte address 0
// 0x00000048  0x200B0000  addi $t3, $zero, 0                   Clear the register before reading RAM
//
// wait_btn1:
// 0x0000004C  0x8D8A0004  lw   $t2, 4($t4)                     Read BTN1 at 0x10000104
// 0x00000050  0x1140FFFE  beq  $t2, $zero, wait_btn1           Return to 0x4C while BTN1 is low
// 0x00000054  0x8C0B0000  lw   $t3, 0($zero)                   Recover 101 from RAM
// 0x00000058  0xAD8B0008  sw   $t3, 8($t4)                     Display the value fetched from RAM
//
// 0x0000005C  0x3C0D1000  lui  $t5, 0x1000                     IRQ register base = 0x10000000
// 0x00000060  0x201D0400  addi $sp, $zero, 0x0400              Initialize the RAM stack
// 0x00000064  0x200E0007  addi $t6, $zero, 7                   ISR LED pattern 111
// 0x00000068  0x200F0018  addi $t7, $zero, 0x18                Global enable and IRQ3 enable
// 0x0000006C  0xADAF0000  sw   $t7, 0($t5)                     Arm IRQ3 after the switch demo
//
// done:
// 0x00000070  0x1320FFFF  beq  $t9, $zero, done                Wait for the ISR to finish
// 0x00000074  0xAD8B0008  sw   $t3, 8($t4)                     Main restores 101 after the return
// 0x00000078  0x20190000  addi $t9, $zero, 0                   Clear the ISR completion flag
// 0x0000007C  0x0800001C  j    done                            Wait for the next BTN3 interrupt
//
// isr_btn3:
// 0x00000080  0x8DBB0008  lw   $k1, 8($t5)                     Read RETURN_PC at 0x10000008
// 0x00000084  0x23BDFFFC  addi $sp, $sp, -4                    Allocate one stack word
// 0x00000088  0xAFBB0000  sw   $k1, 0($sp)                     Push the return PC
// 0x0000008C  0xAD8E0008  sw   $t6, 8($t4)                     Display 111 while inside the ISR
//
// wait_btn1_release:
// 0x00000090  0x8D980004  lw   $t8, 4($t4)                     Read BTN1
// 0x00000094  0x1700FFFE  bne  $t8, $zero, wait_btn1_release   Wait for BTN1 to go low
//
// wait_btn1_press:
// 0x00000098  0x8D980004  lw   $t8, 4($t4)                     Read BTN1 again
// 0x0000009C  0x1300FFFE  beq  $t8, $zero, wait_btn1_press     Wait for a new press
//
// 0x000000A0  0x8FBB0000  lw   $k1, 0($sp)                     Pop the return PC
// 0x000000A4  0x23BD0004  addi $sp, $sp, 4                     Restore the stack pointer
// 0x000000A8  0x20190001  addi $t9, $zero, 1                   Tell main to restore the LED pattern
// 0x000000AC  0x03600008  jr   $k1                             Return to main
//////////////////////////////////////////////////////////////////////////////////

module board_demo_io(
    // Clock and reset
    input  wire        i_clk,
    input  wire        i_rst,

    // Board inputs
    input  wire [1:0]  i_sw,
    input  wire        i_btn1,

    // MMIO request and write data
    input  wire [7:0]  i_offset,
    input  wire        i_re,
    input  wire        i_we,
    input  wire [2:0]  i_led_pattern,

    // MMIO read data
    output reg  [31:0] o_rdata,

    // Board outputs
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
