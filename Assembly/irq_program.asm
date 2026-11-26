# IRQ0 integration test. The handler records its MMIO reads in data RAM.
j boot
j handler               # IRQ0 vector at 0x04
j unexpected            # IRQ1 vector at 0x08
j unexpected            # IRQ2 vector at 0x0c
j unexpected            # IRQ3 vector at 0x10

boot:
lui $t0, 0x1000         # IRQ MMIO base 0x10000000
addi $t1, $zero, 17     # Enable global interrupts and IRQ0
sw $t1, 0($t0)
addi $t2, $zero, 42
sw $t2, 0($zero)
lw $t3, 4($t0)
addi $zero, $zero, 0    # PC 0x2c. The testbench raises BTN1 here.
addi $zero, $zero, 0
addi $zero, $zero, 0
lw $t2, 0($zero)        # PC 0x38. The IRQ must wait for its write-back.
sw $t2, 4($zero)        # PC 0x3c. Visible proof that the program resumed.

done:
j done

handler:
lw $k1, 8($t0)          # Read the saved return PC.
sw $k1, 8($zero)
lw $t3, 4($t0)          # Read IRQ pending bits after ACK.
sw $t3, 12($zero)
jr $k1

unexpected:
j unexpected
