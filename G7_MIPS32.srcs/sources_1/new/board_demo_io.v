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

// 0x00000000  0x08000005  j boot                                   Reset starts at 0x00000000. Jump over the IRQ vectors to boot at 0x00000014.
// 0x00000004  0x00000000  nop                                      Reserve the IRQ0 vector at 0x00000004 for future I2S use.
// 0x00000008  0x00000000  nop                                      Reserve the IRQ1 vector at 0x00000008 for future I2S use.
// 0x0000000C  0x00000000  nop                                      Leave the unused IRQ2 vector at 0x0000000C as a NOP.
// 0x00000010  0x0800001D  j isr_btn3                               IRQ3 enters at 0x00000010. Jump to the BTN3 handler at 0x00000074.
//
// boot:
// 0x00000014  0x201D0400  addi $sp, $zero, 0x0400                  Set $sp to 0x0400, one byte past RAM. The first push moves it into RAM.
// 0x00000018  0x3C0C1000  lui  $t4, 0x1000                         Put 0x1000 in the upper 16 bits of $t4 to form 0x10000000.
// 0x0000001C  0x218C0100  addi $t4, $t4, 0x0100                    Add 0x0100 to get the board demo base address 0x10000100.
// 0x00000020  0x20080001  addi $t0, $zero, 1                       Set $t0 to 0b01 so AND can isolate SW0 at bit 0.
// 0x00000024  0x20090002  addi $t1, $zero, 2                       Set $t1 to 0b10 to isolate SW1 at bit 1 and to display 010 on the LEDs.
//
// 0x00000028  0x3C0D1000  lui  $t5, 0x1000                         Set $t5 to 0x10000000, the base address of the interrupt controller.
// 0x0000002C  0x200E0007  addi $t6, $zero, 7                       Set $t6 to 0b111 to light the three demo LEDs while the ISR is running.
// 0x00000030  0x200F0018  addi $t7, $zero, 0x18                    0x18 = 0b11000. Bit 4 enables IRQs globally, bit 3 enables IRQ3, and bits [2:0] disable IRQ0 to IRQ2.
// 0x00000034  0xADAF0000  sw   $t7, 0($t5)                         Write $t7 to ENABLE at 0x10000000. This enables IRQ3 before the switch loops, after the stack and ISR values are ready.
//
// wait_sw0:
// 0x00000038  0x8D8A0000  lw   $t2, 0($t4)                         Read the switch bits into $t2 from 0x10000100.
// 0x0000003C  0x01485024  and  $t2, $t2, $t0                       Keep bit 0 only. The result is 1 if SW0 is on and 0 otherwise.
// 0x00000040  0x1140FFFD  beq  $t2, $zero, wait_sw0                If SW0 is off, go back to 0x00000038 and reread the switches.
// 0x00000044  0xAD890008  sw   $t1, 8($t4)                         Write 0b010 to the LED register at 0x10000108 to show that SW0 was detected.
//
// wait_sw1:
// 0x00000048  0x8D8A0000  lw   $t2, 0($t4)                         Read both switches again from 0x10000100 so the loop sees changes to SW1.
// 0x0000004C  0x01495024  and  $t2, $t2, $t1                       Keep bit 1 only. The result is 2 if SW1 is on and 0 otherwise.
// 0x00000050  0x1140FFFD  beq  $t2, $zero, wait_sw1                If SW1 is off, go back to 0x00000048 and reread the switches.
// 0x00000054  0x200B0005  addi $t3, $zero, 5                       Prepare the next LED pattern, 5 = 0b101.
// 0x00000058  0xAC0B0000  sw   $t3, 0($zero)                       Store 5 at RAM byte address 0x00000000 so the demo can read it back later.
// 0x0000005C  0x200B0000  addi $t3, $zero, 0                       Clear $t3 so the value used for the LEDs after BTN1 comes from the RAM load.
//
// wait_btn1:
// 0x00000060  0x8D8A0004  lw   $t2, 4($t4)                         Read BTN1 from 0x10000104. Bit 0 is 1 while the button is pressed.
// 0x00000064  0x1140FFFE  beq  $t2, $zero, wait_btn1               If BTN1 is low, go back to 0x00000060 and read it again.
// 0x00000068  0x8C0B0000  lw   $t3, 0($zero)                       Load the stored value 5 from RAM byte address 0x00000000 into $t3.
// 0x0000006C  0xAD8B0008  sw   $t3, 8($t4)                         Write the value read from RAM to the LED register at 0x10000108.
//
// Program ended enter loop
// done:
// 0x00000070  0x0800001C  j    done                                Jump back to 0x00000070. Leave the LEDs at 101 while waiting for IRQ3.
//
// isr_btn3:
// 0x00000074  0x8DBB0008  lw   $k1, 8($t5)                         Read RETURN_PC at 0x10000008 into $k1 to get the address where execution must resume.
// 0x00000078  0x23BDFFF8  addi $sp, $sp, -8                        Move $sp from 0x0400 to 0x03F8 to reserve two 4-byte words on the stack.
// 0x0000007C  0xAFBB0000  sw   $k1, 0($sp)                         Save the return PC in the first stack word at 0x03F8.
// 0x00000080  0x8D980008  lw   $t8, 8($t4)                         Read the current LED pattern from 0x10000108 before changing it.
// 0x00000084  0xAFB80004  sw   $t8, 4($sp)                         Save the LED pattern in the second stack word at 0x03FC.
// 0x00000088  0xAD8E0008  sw   $t6, 8($t4)                         Write 0b111 to 0x10000108 so the LEDs show that the ISR is running.
//
// wait_btn1_release:
// 0x0000008C  0x8D980004  lw   $t8, 4($t4)                         Read BTN1 at 0x10000104 to see whether it is already being held.
// 0x00000090  0x1700FFFE  bne  $t8, $zero, wait_btn1_release       If BTN1 is still high, go back to 0x0000008C and wait for it to be released.
//
// wait_btn1_press:
// 0x00000094  0x8D980004  lw   $t8, 4($t4)                         Read BTN1 again after observing it low.
// 0x00000098  0x1300FFFE  beq  $t8, $zero, wait_btn1_press         If BTN1 is still low, go back to 0x00000094 and wait for a fresh press.
//
// 0x0000009C  0x8FB80004  lw   $t8, 4($sp)                         Load the original LED pattern from the second stack word at 0x03FC.
// 0x000000A0  0xAD980008  sw   $t8, 8($t4)                         Write the saved pattern to 0x10000108 to restore the LEDs.
// 0x000000A4  0x8FBB0000  lw   $k1, 0($sp)                         Load the saved return PC from the first stack word at 0x03F8.
// 0x000000A8  0x23BD0008  addi $sp, $sp, 8                         Add 8 to $sp to release both stack words and restore it to 0x0400.
// 0x000000AC  0x03600008  jr   $k1                                 Jump to the address in $k1 to resume the interrupted program.

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

    // BTN1 and the switches are independent inputs with no source clock.
    wire btn1_synchronized;
    wire [1:0] switches_synchronized;

    xpm_cdc_single #(
        .DEST_SYNC_FF(2),
        .SRC_INPUT_REG(0),
        .INIT_SYNC_FF(1),
        .SIM_ASSERT_CHK(0)
    ) u_btn1_sync (
        .src_clk(1'b0),
        .src_in(i_btn1),
        .dest_clk(i_clk),
        .dest_out(btn1_synchronized)
    );

    xpm_cdc_single #(
        .DEST_SYNC_FF(2),
        .SRC_INPUT_REG(0),
        .INIT_SYNC_FF(1),
        .SIM_ASSERT_CHK(0)
    ) u_sw0_sync (
        .src_clk(1'b0),
        .src_in(i_sw[0]),
        .dest_clk(i_clk),
        .dest_out(switches_synchronized[0])
    );

    xpm_cdc_single #(
        .DEST_SYNC_FF(2),
        .SRC_INPUT_REG(0),
        .INIT_SYNC_FF(1),
        .SIM_ASSERT_CHK(0)
    ) u_sw1_sync (
        .src_clk(1'b0),
        .src_in(i_sw[1]),
        .dest_clk(i_clk),
        .dest_out(switches_synchronized[1])
    );

    // Address bits: MMIO region [31:12] | device page [11:8] | byte offset [7:0]

    // 0x10000100 Switch address (read only)
    // Address: 0001_0000_0000_0000_0000 | 0001 | 0000_0000
    // Read data: [31:2] = 0, [1] = SW1, [0] = SW0
    localparam [7:0] SWITCH_OFFSET = 8'h00;

    // 0x10000104 Button address (read only)
    // Address: 0001_0000_0000_0000_0000 | 0001 | 0000_0100
    // Read data: [31:1] = 0, [0] = BTN1
    localparam [7:0] BUTTON_OFFSET = 8'h04;

    // 0x10000108 LED address (read/write)
    // Address: 0001_0000_0000_0000_0000 | 0001 | 0000_1000
    // Data: [2] = LD3, [1] = LD2, [0] = LD1
    // Bits [31:3] read as zero and are ignored on writes. LD0 shows reset.
    localparam [7:0] LED_OFFSET    = 8'h08;

    always @(posedge i_clk) begin
        if (i_rst) begin
            o_rdata <= 32'b0;
            o_led   <= 3'b000;
        end else begin
            if (i_re) begin
                case (i_offset)
                    SWITCH_OFFSET: o_rdata <= {30'b0, switches_synchronized};
                    BUTTON_OFFSET: o_rdata <= {31'b0, btn1_synchronized};
                    LED_OFFSET:    o_rdata <= {29'b0, o_led};
                    default:       o_rdata <= 32'b0;
                endcase
            end

            if (i_we && (i_offset == LED_OFFSET))
                o_led <= i_led_pattern;
        end
    end
endmodule
