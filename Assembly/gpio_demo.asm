# Zybo demo
# Start with SW0 and SW1 off. Press and release BTN0 to reset.
# Flip SW0, then SW1, then press BTN1. LD3-LD1 finish at 101.
# LD0 shows the reset button.

    lui  $t4, 0x1000          # 0x00: MMIO base = 0x10000000
    addi $t0, $zero, 1        # 0x04: SW0 mask
    addi $t1, $zero, 2        # 0x08: SW1 mask and LED pattern 010

wait_sw0:                     # 0x0C
    lw   $t2, 0x0100($t4)     # 0x0C: Read SW0 and SW1 at 0x10000100
    and  $t2, $t2, $t0        # 0x10: Keep SW0
    beq  $t2, $zero, wait_sw0 # 0x14: Return to 0x0C while SW0 is off
    sw   $t1, 0x0108($t4)     # 0x18: Display 010 at 0x10000108

wait_sw1:                     # 0x1C
    lw   $t2, 0x0100($t4)     # 0x1C: Read SW0 and SW1 at 0x10000100
    and  $t2, $t2, $t1        # 0x20: Keep SW1
    beq  $t2, $zero, wait_sw1 # 0x24: Return to 0x1C while SW1 is off

    addi $t3, $zero, 5        # 0x28: Binary 101
    sw   $t3, 0($zero)        # 0x2C: Save 101 in data RAM at 0x00000000
    addi $t3, $zero, 0        # 0x30: Clear the register before reading RAM

wait_btn1:                    # 0x34
    lw   $t2, 0x0104($t4)     # 0x34: Read BTN1 at 0x10000104
    beq  $t2, $zero, wait_btn1 # 0x38: Return to 0x34 while BTN1 is low

    lw   $t3, 0($zero)        # 0x3C: Recover 101 from data RAM
    sw   $t3, 0x0108($t4)     # 0x40: Display the value fetched from RAM

done:                         # 0x44
    j    done                 # 0x44: Hold the final LED pattern
