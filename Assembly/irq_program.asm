# IRQ3 integration test. Two IRQs use the same handler and stack their return PCs.
j boot
j unexpected            # IRQ0 vector at 0x04
j unexpected            # IRQ1 vector at 0x08
j unexpected            # IRQ2 vector at 0x0c
j handler               # IRQ3 vector at 0x10

boot:
lui $t0, 0x1000         # IRQ MMIO base 0x10000000
addi $sp, $zero, 0x400  # Stack starts above the highest RAM word
addi $t1, $zero, 24     # Global enable and IRQ3 enable
addi $t3, $zero, 8      # IRQ3 enable, global disabled
sw $t1, 0($t0)
addi $t2, $zero, 42
sw $t2, 0($zero)        # PC 0x2c. The testbench raises BTN3 here.
addi $zero, $zero, 0
addi $zero, $zero, 0
lw $t2, 0($zero)        # PC 0x38. The IRQ waits for write-back.
sw $t2, 4($zero)        # PC 0x3c. Visible proof that main resumed.

done:
j done

handler:
sw $zero, 8($t0)        # RETURN_PC is read-only.
lw $k1, 8($t0)          # Read saved_pc while new interrupts are blocked.
addi $sp, $sp, -4
sw $k1, 0($sp)          # Save this level's return address.
sw $t1, 0($t0)          # Allow another IRQ only after the push.

addi $zero, $zero, 0    # PC 0x58. A pending IRQ can enter here.
addi $zero, $zero, 0    # PC 0x5c. The inner ISR returns here.
addi $zero, $zero, 0

sw $t3, 0($t0)          # Block new entries while popping, keep IRQ3 enabled.
lw $k1, 0($sp)
addi $sp, $sp, 4
jr $k1                  # Jump to the popped address and end this IRQ level.

unexpected:
j unexpected
