# Start with SW0 and SW1 off and press BTN0 to reset. LD0 shows reset.
# Flip SW0 for 010, then SW1 and press BTN1 for 101.
# Press BTN3 for IRQ3 and 111 on LD3-LD1.
# Release BTN1, then press it again to end the ISR. The ISR restores the previous LEDs.

    j    boot                 # PC 0x00: Reset starts at 0x00000000. Jump over the IRQ vectors to boot at 0x00000014.
    nop                       # PC 0x04: Reserve the IRQ0 vector at 0x00000004 for future I2S use.
    nop                       # PC 0x08: Reserve the IRQ1 vector at 0x00000008 for future I2S use.
    nop                       # PC 0x0C: Leave the unused IRQ2 vector at 0x0000000C as a NOP.
    j    isr_btn3             # PC 0x10: IRQ3 enters at 0x00000010. Jump to the BTN3 handler at 0x00000074.

boot:
    addi $sp, $zero, 0x0400   # PC 0x14: Set $sp to 0x0400, one byte past RAM. The first push moves it into RAM.
    lui  $t4, 0x1000          # PC 0x18: Put 0x1000 in the upper 16 bits of $t4 to form 0x10000000.
    addi $t4, $t4, 0x0100     # PC 0x1C: Add 0x0100 to get the board demo base address 0x10000100.
    addi $t0, $zero, 1        # PC 0x20: Set $t0 to 0b01 so AND can isolate SW0 at bit 0.
    addi $t1, $zero, 2        # PC 0x24: Set $t1 to 0b10 to isolate SW1 at bit 1 and to display 010 on the LEDs.

    lui  $t5, 0x1000          # PC 0x28: Set $t5 to 0x10000000, the base address of the interrupt controller.
    addi $t6, $zero, 7        # PC 0x2C: Set $t6 to 0b111 to light the three demo LEDs while the ISR is running.
    addi $t7, $zero, 0x18     # PC 0x30: Build 0x18 = 0b11000. Bit 4 enables IRQs globally, bit 3 enables IRQ3, and bits [2:0] disable IRQ0 to IRQ2.
    sw   $t7, 0($t5)          # PC 0x34: Write $t7 to ENABLE at 0x10000000. This enables IRQ3 before the switch loops, after the stack and ISR values are ready.

wait_sw0:
    lw   $t2, 0($t4)          # PC 0x38: Read the switch bits into $t2 from 0x10000100.
    and  $t2, $t2, $t0        # PC 0x3C: Keep bit 0 only. The result is 1 if SW0 is on and 0 otherwise.
    beq  $t2, $zero, wait_sw0 # PC 0x40: If SW0 is off, go back to 0x00000038 and reread the switches.
    sw   $t1, 8($t4)          # PC 0x44: Write 0b010 to the LED register at 0x10000108 to show that SW0 was detected.

wait_sw1:
    lw   $t2, 0($t4)          # PC 0x48: Read both switches again from 0x10000100 so the loop sees changes to SW1.
    and  $t2, $t2, $t1        # PC 0x4C: Keep bit 1 only. The result is 2 if SW1 is on and 0 otherwise.
    beq  $t2, $zero, wait_sw1 # PC 0x50: If SW1 is off, go back to 0x00000048 and reread the switches.

    addi $t3, $zero, 5        # PC 0x54: Prepare the next LED pattern, 5 = 0b101.
    sw   $t3, 0($zero)        # PC 0x58: Store 5 at RAM byte address 0x00000000 so the demo can read it back later.
    addi $t3, $zero, 0        # PC 0x5C: Clear $t3 so the value used for the LEDs after BTN1 comes from the RAM load.

wait_btn1:
    lw   $t2, 4($t4)          # PC 0x60: Read BTN1 from 0x10000104. Bit 0 is 1 while the button is pressed.
    beq  $t2, $zero, wait_btn1 # PC 0x64: If BTN1 is low, go back to 0x00000060 and read it again.
    lw   $t3, 0($zero)        # PC 0x68: Load the stored value 5 from RAM byte address 0x00000000 into $t3.
    sw   $t3, 8($t4)          # PC 0x6C: Write the value read from RAM to the LED register at 0x10000108.

done:
    j    done                 # PC 0x70: Jump back to 0x00000070. Leave the LEDs at 101 while waiting for IRQ3.

isr_btn3:
    lw   $k1, 8($t5)          # PC 0x74: Read RETURN_PC at 0x10000008 into $k1 to get the address where execution must resume.
    addi $sp, $sp, -8         # PC 0x78: Move $sp from 0x0400 to 0x03F8 to reserve two 4-byte words on the stack.
    sw   $k1, 0($sp)          # PC 0x7C: Save the return PC in the first stack word at 0x03F8.
    lw   $t8, 8($t4)          # PC 0x80: Read the current LED pattern from 0x10000108 before changing it.
    sw   $t8, 4($sp)          # PC 0x84: Save the LED pattern in the second stack word at 0x03FC.
    sw   $t6, 8($t4)          # PC 0x88: Write 0b111 to 0x10000108 so the LEDs show that the ISR is running.

wait_btn1_release:
    lw   $t8, 4($t4)          # PC 0x8C: Read BTN1 at 0x10000104 to see whether it is already being held.
    bne  $t8, $zero, wait_btn1_release # PC 0x90: If BTN1 is still high, go back to 0x0000008C and wait for it to be released.

wait_btn1_press:
    lw   $t8, 4($t4)          # PC 0x94: Read BTN1 again after observing it low.
    beq  $t8, $zero, wait_btn1_press   # PC 0x98: If BTN1 is still low, go back to 0x00000094 and wait for a fresh press.

    lw   $t8, 4($sp)          # PC 0x9C: Load the original LED pattern from the second stack word at 0x03FC.
    sw   $t8, 8($t4)          # PC 0xA0: Write the saved pattern to 0x10000108 to restore the LEDs.
    lw   $k1, 0($sp)          # PC 0xA4: Load the saved return PC from the first stack word at 0x03F8.
    addi $sp, $sp, 8          # PC 0xA8: Add 8 to $sp to release both stack words and restore it to 0x0400.
    jr   $k1                  # PC 0xAC: Jump to the address in $k1 to resume the interrupted program.
