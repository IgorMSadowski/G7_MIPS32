# test.asm — exercises all 24 instructions
_start:
        addiu   $t0, $zero, 5        # $t0 = 5
        addiu   $t1, $zero, 3        # $t1 = 3

        add     $t2, $t0, $t1        # $t2 = 8
        addu    $t3, $t0, $t1        # $t3 = 8
        sub     $t4, $t2, $t1        # $t4 = 5
        subu    $t5, $t2, $t1        # $t5 = 5

        and     $t6, $t0, $t1        # $t6 = 1
        or      $t7, $t0, $t1        # $t7 = 7
        xor     $s0, $t0, $t1        # $s0 = 6
        nor     $s1, $t0, $t1        # $s1 = 0xFFFFFFF8

        sll     $s2, $t0, 2          # $s2 = 20
        srl     $s3, $s2, 1          # $s3 = 10

        slt     $s4, $t1, $t0        # $s4 = 1 (3 < 5)

        sw      $t2, 0($zero)        # Mem[0] = 8
        lw      $s5, 0($zero)        # $s5 = 8

        beq     $s5, $t2, equal      # taken
        addiu   $s6, $zero, 99       # skipped
equal:
        bne     $s5, $t1, neq        # taken
        addiu   $s6, $zero, 99       # skipped
neq:
        bltz    $t1, neg             # not taken (t1=3 is positive)
        bgez    $t1, gez             # taken
neg:
        addiu   $s6, $zero, 99       # skipped
gez:
        bgtz    $t0, gt              # taken (t0=5 > 0)
        addiu   $s6, $zero, 99       # skipped
gt:
        blez    $t1, lez             # not taken (t1=3 > 0)
        addiu   $s6, $zero, 100      # executed -> $s6 = 100
lez:
        jal     func
        addiu   $s7, $zero, 42       # runs after return from func

        j       end
        nop
func:
        addiu   $a0, $zero, 7
        jr      $ra
end:
        j       end
        nop