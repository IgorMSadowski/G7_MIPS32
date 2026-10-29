# test.asm — exercises Common + G7 ISA
_start:
        # --- 1. Test Common ISA ---
        lui     $t0, 0x1234          # $t0 = 0x12340000
        addi    $t1, $zero, 5        # $t1 = 5
        addi    $t2, $zero, -3       # $t2 = -3

        add     $t3, $t1, $t2        # $t3 = 2
        sub     $t4, $t1, $t2        # $t4 = 8
        and     $t5, $t1, $t2        # $t5 = 5 & -3 = 1
        or      $t6, $t1, $t2        # $t6 = 5 | -3 = -3
        xor     $t7, $t1, $t2        # $t7 = 5 ^ -3 = -4
        slt     $s0, $t2, $t1        # $s0 = 1 (-3 < 5)
        sll     $s1, $t1, 2          # $s1 = 20
        srl     $s2, $s1, 1          # $s2 = 10

        sw      $t3, 0($zero)        # Mem[0] = 2
        lw      $s3, 0($zero)        # $s3 = 2

        # --- 2. Test G7 ISA ---
        # wsbh: swap bytes in halfwords of $t0 (0x12340000 -> 0x34120000)
        wsbh    $s4, $t0             # $s4 = 0x34120000

        # rotr: rotate $t0 right by 8 (0x12340000 -> 0x00123400)
        rotr    $s5, $t0, 8          # $s5 = 0x00123400

        # branches
        beq     $s3, $t3, beq_ok     # taken
        addi    $s6, $zero, 99
beq_ok:
        bne     $s3, $t1, bne_ok     # taken
        addi    $s6, $zero, 99
bne_ok:
        bltz    $t2, bltz_ok         # taken
        addi    $s6, $zero, 99
bltz_ok:
        bgez    $t1, bgez_ok         # taken
        addi    $s6, $zero, 99
bgez_ok:
        bgtz    $t1, bgtz_ok         # taken
        addi    $s6, $zero, 99
bgtz_ok:
        blez    $t2, blez_ok         # taken
        addi    $s6, $zero, 99
blez_ok:
        addi    $s6, $zero, 1        # $s6 = 1 (all branches passed)

        # --- 3. Test Jumps and JALR ---
        # Load a small address into $t8 to test jalr
        addi    $t8, $zero, 0x60     # hardcoded address of func_jalr
        jalr    $ra, $t8             # jump to func_jalr
        addi    $s7, $zero, 42       # runs after return

        jal     func_jr              # test standard jal
        addi    $t9, $zero, 77       # runs after return

        j       end
        nop

func_jalr:
        addi    $a0, $zero, 7
        jr      $ra

func_jr:
        addi    $a1, $zero, 8
        jr      $ra

end:
        j       end
        nop
