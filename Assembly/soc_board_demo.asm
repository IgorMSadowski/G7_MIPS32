# Start with SW0 and SW1 off and press BTN0 to reset. LD0 shows reset.
# Flip SW0 for 010, then SW1 and press BTN1 for 101.
# Press BTN3 for IRQ3 and 111 on LD3-LD1.
# Release BTN1, then press it again to end the ISR. Main restores 101.

    j    boot                 # PC 0x00: Reset vector
    nop                       # PC 0x04: IRQ0 reserved for I2S
    nop                       # PC 0x08: IRQ1 reserved for I2S
    nop                       # PC 0x0C: IRQ2 unused
    j    isr_btn3             # PC 0x10: IRQ3 vector

boot:
    lui  $t4, 0x1000          # PC 0x14: MMIO base = 0x10000000
    addi $t4, $t4, 0x0100     # PC 0x18: Board demo page = 0x10000100
    addi $t0, $zero, 1        # PC 0x1C: SW0 mask
    addi $t1, $zero, 2        # PC 0x20: SW1 mask and LED pattern 010

wait_sw0:
    lw   $t2, 0($t4)          # PC 0x24: Read SW0 and SW1
    and  $t2, $t2, $t0        # PC 0x28: Keep SW0
    beq  $t2, $zero, wait_sw0 # PC 0x2C: Return to 0x24 while SW0 is off
    sw   $t1, 8($t4)          # PC 0x30: Display 010 at 0x10000108

wait_sw1:
    lw   $t2, 0($t4)          # PC 0x34: Read SW0 and SW1
    and  $t2, $t2, $t1        # PC 0x38: Keep SW1
    beq  $t2, $zero, wait_sw1 # PC 0x3C: Return to 0x34 while SW1 is off

    addi $t3, $zero, 5        # PC 0x40: Binary 101
    sw   $t3, 0($zero)        # PC 0x44: Store 101 at RAM byte address 0
    addi $t3, $zero, 0        # PC 0x48: Clear the register before reading RAM

wait_btn1:
    lw   $t2, 4($t4)          # PC 0x4C: Read BTN1 at 0x10000104
    beq  $t2, $zero, wait_btn1 # PC 0x50: Return to 0x4C while BTN1 is low
    lw   $t3, 0($zero)        # PC 0x54: Recover 101 from RAM
    sw   $t3, 8($t4)          # PC 0x58: Display the value fetched from RAM

    lui  $t5, 0x1000          # PC 0x5C: IRQ register base = 0x10000000
    addi $sp, $zero, 0x0400   # PC 0x60: Initialize the RAM stack
    addi $t6, $zero, 7        # PC 0x64: ISR LED pattern 111
    addi $t7, $zero, 0x18     # PC 0x68: Global enable and IRQ3 enable
    sw   $t7, 0($t5)          # PC 0x6C: Arm IRQ3 after the switch demo

done:
    beq  $t9, $zero, done    # PC 0x70: Wait for the ISR to finish
    sw   $t3, 8($t4)          # PC 0x74: Main restores 101 after the return
    addi $t9, $zero, 0        # PC 0x78: Clear the ISR completion flag
    j    done                 # PC 0x7C: Wait for the next BTN3 interrupt

isr_btn3:
    lw   $k1, 8($t5)          # PC 0x80: Read RETURN_PC at 0x10000008
    addi $sp, $sp, -4         # PC 0x84: Allocate one stack word
    sw   $k1, 0($sp)          # PC 0x88: Push the return PC
    sw   $t6, 8($t4)          # PC 0x8C: Display 111 while inside the ISR

wait_btn1_release:
    lw   $t8, 4($t4)          # PC 0x90: Read BTN1
    bne  $t8, $zero, wait_btn1_release # PC 0x94: Wait for BTN1 to go low

wait_btn1_press:
    lw   $t8, 4($t4)          # PC 0x98: Read BTN1 again
    beq  $t8, $zero, wait_btn1_press   # PC 0x9C: Wait for a new press

    lw   $k1, 0($sp)          # PC 0xA0: Pop the return PC
    addi $sp, $sp, 4          # PC 0xA4: Restore the stack pointer
    addi $t9, $zero, 1        # PC 0xA8: Tell main to restore the LED pattern
    jr   $k1                  # PC 0xAC: Return to main
