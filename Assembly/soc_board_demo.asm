# Zybo demo
# Start with SW0 and SW1 off. Press and release BTN0 to reset.
# Flip SW0, then SW1, then press BTN1. LD3-LD1 finish at 101.
# LD0 shows the reset button.

    lui  $t4, 0x1000          # 0x00: MMIO base = 0x10000000
    addi $t4, $t4, 0x0100    # 0x04: Board test page = 0x10000100
    addi $t0, $zero, 1        # 0x08: SW0 mask
    addi $t1, $zero, 2        # 0x0C: SW1 mask and LED pattern 010

wait_sw0:                     # 0x10
    lw   $t2, 0x00($t4)       # 0x10: Read SW0 and SW1 at 0x10000100
    and  $t2, $t2, $t0        # 0x14: Keep SW0
    beq  $t2, $zero, wait_sw0 # 0x18: Return to 0x10 while SW0 is off
    sw   $t1, 0x08($t4)       # 0x1C: Display 010 at 0x10000108  

wait_sw1:                     # 0x20
    lw   $t2, 0x00($t4)       # 0x20: Read SW0 and SW1 at 0x10000100
    and  $t2, $t2, $t1        # 0x24: Keep SW1
    beq  $t2, $zero, wait_sw1 # 0x28: Return to 0x20 while SW1 is off

    addi $t3, $zero, 5        # 0x2C: Binary 101
    sw   $t3, 0($zero)        # 0x30: Save 101 in data RAM at 0x00000000
    addi $t3, $zero, 0        # 0x34: Clear the register before reading RAM

wait_btn1:                    # 0x38
    lw   $t2, 0x04($t4)       # 0x38: Read BTN1 at 0x10000104
    beq  $t2, $zero, wait_btn1 # 0x3C: Return to 0x38 while BTN1 is low

    lw   $t3, 0($zero)        # 0x40: Recover 101 from data RAM
    sw   $t3, 0x08($t4)       # 0x44: Display the value fetched from RAM

done:                         # 0x48
    j    done                 # 0x48: Hold the final LED pattern
