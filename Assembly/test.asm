# test.asm — exercises Common + G7 ISA
# Address guide for the CURRENT instruction layout:
# ROM addresses are byte addresses; each instruction occupies 4 bytes.
# A label names the address of the next instruction and occupies no ROM space.
# Branch destination = PC + 4 + (signed offset << 2).
# J/JAL destination = {(PC+4)[31:28], target26, 2'b00}.
# JR/JALR destination is the byte address stored in the source register.
# ROM and RAM are separate: RAM address 0 is not ROM address 0.
# Adding/removing instructions changes addresses: check the assembler listing (-l).
# The address loaded into $t8 is a literal and must match func_jalr.
_start:          # ROM 0x00000000
        # --- 1. Test Common ISA ---
        lui     $t0, 0x1234             # ROM 0x00000000: $t0 = 0x12340000
        addi    $t1, $zero, 5           # ROM 0x00000004: $t1 = 5
        addi    $t2, $zero, -3          # ROM 0x00000008: $t2 = -3 (0xFFFFFFFD)

        add     $t3, $t1, $t2           # ROM 0x0000000C: $t3 = 5 + (-3) = 2
        sub     $t4, $t1, $t2           # ROM 0x00000010: $t4 = 5 - (-3) = 8
        and     $t5, $t1, $t2           # ROM 0x00000014: $t5 = 5 AND -3 = 5
        or      $t6, $t1, $t2           # ROM 0x00000018: $t6 = 5 OR -3 = -3
        xor     $t7, $t1, $t2           # ROM 0x0000001C: $t7 = 5 XOR -3 = -8 (0xFFFFFFF8)
        slt     $s0, $t2, $t1           # ROM 0x00000020: $s0 = 1 because -3 < 5 (signed)
        sll     $s1, $t1, 2             # ROM 0x00000024: $s1 = 5 << 2 = 20
        srl     $s2, $s1, 1             # ROM 0x00000028: $s2 = 20 >> 1 = 10

        sw      $t3, 0($zero)           # ROM 0x0000002C: RAM[0x00000000] = 2; this normal store also lights LD0
        lw      $s3, 0($zero)           # ROM 0x00000030: $s3 = RAM[0x00000000] = 2

        # --- 2. Test G7 ISA ---
        # wsbh: swap bytes in halfwords of $t0 (0x12340000 -> 0x34120000)
        wsbh    $s4, $t0                # ROM 0x00000034: $s4 = 0x34120000

        # rotr: rotate $t0 right by 8 (0x12340000 -> 0x00123400)
        rotr    $s5, $t0, 8             # ROM 0x00000038: $s5 = 0x00123400

        # branches
        beq     $s3, $t3, beq_ok        # ROM 0x0000003C: taken: branch -> beq_ok (0x00000044); 0x40 + (1 << 2)
        addi    $k0, $zero, 99          # ROM 0x00000040: guard: skipped by BEQ; would set $k0 = 99
beq_ok:          # ROM 0x00000044
        bne     $s3, $t1, bne_ok        # ROM 0x00000044: taken: branch -> bne_ok (0x0000004C); 0x48 + (1 << 2)
        addi    $k0, $zero, 99          # ROM 0x00000048: guard: skipped by BNE; would set $k0 = 99
bne_ok:          # ROM 0x0000004C
        bltz    $t2, bltz_ok            # ROM 0x0000004C: taken: branch -> bltz_ok (0x00000054); 0x50 + (1 << 2)
        addi    $k0, $zero, 99          # ROM 0x00000050: guard: skipped by BLTZ; would set $k0 = 99
bltz_ok:         # ROM 0x00000054
        bgez    $t1, bgez_ok            # ROM 0x00000054: taken: branch -> bgez_ok (0x0000005C); 0x58 + (1 << 2)
        addi    $k0, $zero, 99          # ROM 0x00000058: guard: skipped by BGEZ; would set $k0 = 99
bgez_ok:         # ROM 0x0000005C
        bgtz    $t1, bgtz_ok            # ROM 0x0000005C: taken: branch -> bgtz_ok (0x00000064); 0x60 + (1 << 2)
        addi    $k0, $zero, 99          # ROM 0x00000060: guard: skipped by BGTZ; would set $k0 = 99
bgtz_ok:         # ROM 0x00000064
        blez    $t2, blez_ok            # ROM 0x00000064: taken: branch -> blez_ok (0x0000006C); 0x68 + (1 << 2)
        addi    $k0, $zero, 99          # ROM 0x00000068: guard: skipped by BLEZ; would set $k0 = 99
blez_ok:         # ROM 0x0000006C
        addi    $s6, $zero, 1           # ROM 0x0000006C: $s6 = 1; all branch guards were skipped

        # --- 3. Test Jumps and JALR ---
        # Load a small address into $t8 to test jalr
        addi    $t8, $zero, 0x8C        # ROM 0x00000070: $t8 = 0x0000008C, the byte address of func_jalr
        jalr    $ra, $t8                # ROM 0x00000074: jump -> $t8 = func_jalr (0x0000008C); $ra = PC+4 = 0x00000078
        addi    $s7, $zero, 42          # ROM 0x00000078: return destination of JR at 0x00000090; $s7 = 42

        jal     func_jr                 # ROM 0x0000007C: jump -> func_jr (0x00000094); target field = 0x25; $ra = 0x00000080
        addi    $t9, $zero, 77          # ROM 0x00000080: return destination of JR at 0x00000098; $t9 = 77

        j       end                     # ROM 0x00000084: jump -> end (0x0000009C); target field = 0x27
        nop                             # ROM 0x00000088: skipped after J; this SoC has no branch/jump delay slots

func_jalr:       # ROM 0x0000008C
        addi    $a0, $zero, 7           # ROM 0x0000008C: func_jalr entry: $a0 = 7
        jr      $ra                     # ROM 0x00000090: jump -> $ra; here $ra = 0x00000078, set by JALR at 0x00000074

func_jr:         # ROM 0x00000094
        addi    $a1, $zero, 8           # ROM 0x00000094: func_jr entry: $a1 = 8
        jr      $ra                     # ROM 0x00000098: jump -> $ra; here $ra = 0x00000080, set by JAL at 0x0000007C

end:             # ROM 0x0000009C
        j       end                     # ROM 0x0000009C: jump -> end (0x0000009C); infinite self-loop; target field = 0x27
        nop                             # ROM 0x000000A0: skipped after the self-loop J; no delay slot