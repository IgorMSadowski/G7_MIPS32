# Exercises the 24 instructions in the G7 ISA with t0-t3 as working registers.
# The LEDs show 101 on success or 111 on failure. No button presses are needed.

    j    main

add_two:                        # 0x00000004, target of JALR
    addi $t2, $t2, 2
    jr   $t1

add_one:
    addi $t2, $t2, 1
    jr   $ra

main:
    lui  $t3, 0x1000             # MMIO base for the final result

    # Arithmetic and logic
    addi $t0, $zero, 5
    addi $t1, $zero, 3
    add  $t2, $t0, $t1
    addi $t1, $zero, 8
    bne  $t2, $t1, fail
    sub  $t2, $t2, $t0
    addi $t1, $zero, 3
    bne  $t2, $t1, fail

    and  $t2, $t0, $t1
    addi $t1, $zero, 1
    bne  $t2, $t1, fail
    addi $t1, $zero, 3
    or   $t2, $t0, $t1
    addi $t1, $zero, 7
    bne  $t2, $t1, fail
    addi $t1, $zero, 3
    xor  $t2, $t0, $t1
    addi $t1, $zero, 6
    bne  $t2, $t1, fail

    addi $t1, $zero, -1
    slt  $t2, $t1, $t0
    addi $t1, $zero, 1
    bne  $t2, $t1, fail

    # Shifts, rotate and byte swap
    sll  $t2, $t0, 2
    addi $t1, $zero, 20
    bne  $t2, $t1, fail
    srl  $t2, $t2, 1
    addi $t1, $zero, 10
    bne  $t2, $t1, fail
    rotr $t2, $t0, 1
    lui  $t1, 0x8000
    addi $t1, $t1, 2
    bne  $t2, $t1, fail
    addi $t0, $zero, 0x1234
    wsbh $t2, $t0
    addi $t1, $zero, 0x3412
    bne  $t2, $t1, fail

    # Store 0x3412 in RAM, clear t2, and load the value back
    sw   $t2, 0($zero)
    addi $t2, $zero, 0
    lw   $t2, 0($zero)
    bne  $t2, $t1, fail

    # Taken branches skip a jump to the failure loop
    beq  $t2, $t1, equal
    j    fail
equal:
    addi $t0, $zero, -1
    bltz $t0, negative
    j    fail
negative:
    blez $zero, nonpositive
    j    fail
nonpositive:
    bgez $zero, nonnegative
    j    fail
nonnegative:
    addi $t0, $zero, 1
    bgtz $t0, positive
    j    fail
positive:
    bne  $t0, $zero, calls
    j    fail

calls:
    addi $t2, $zero, 0
    jal  add_one                 # add_one returns through ra
    addi $t0, $zero, 1
    bne  $t2, $t0, fail
    addi $t0, $zero, 0x0004      # Address of add_two
    jalr $t1, $t0                # add_two returns through t1
    addi $t0, $zero, 3
    bne  $t2, $t0, fail

    addi $t2, $zero, 5
    sw   $t2, 0x0108($t3)        # LD3-LD1 = 101
passed:
    j    passed

fail:
    addi $t2, $zero, 7
    sw   $t2, 0x0108($t3)        # LD3-LD1 = 111
failed:
    j    failed
