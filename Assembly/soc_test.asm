# G7 SoC integration test. RAM byte address 0x000003F8 records progress.
# 1 arithmetic/logic, 2 shifts, 3 RAM, 4 branches, 5 jumps, 6 PASS, 7 FAIL.
# The only work registers are t0, t1, and t2. JAL writes the fixed link register ra.
# PC is the instruction's byte address. Each HEX word is one line of soc_test.mem.
# Binary layouts: R = op | rs | rt | rd | shamt | funct
#                 I = op | rs | rt | imm16
#                 J = op | target26 (byte target divided by 4)
# Branch target = PC + 4 + (signed imm16 * 4). This core uses no delay slot.

# Arithmetic and logic
    addi $t0, $zero, 5             # PC 0x00000000 | HEX 20080005 | BIN 001000 00000 01000 0000000000000101 | t0 = 5
    addi $t1, $zero, 3             # PC 0x00000004 | HEX 20090003 | BIN 001000 00000 01001 0000000000000011 | t1 = 3
    add  $t2, $t0, $t1             # PC 0x00000008 | HEX 01095020 | BIN 000000 01000 01001 01010 00000 100000 | t2 = 8
    addi $t1, $zero, 8             # PC 0x0000000C | HEX 20090008 | BIN 001000 00000 01001 0000000000001000 | expected ADD result
    bne  $t2, $t1, fail            # PC 0x00000010 | HEX 15490071 | BIN 000101 01010 01001 0000000001110001 | ADD result must be 8 | target 0x000001D8, displacement +113 word(s)
    sub  $t2, $t0, $t1             # PC 0x00000014 | HEX 01095022 | BIN 000000 01000 01001 01010 00000 100010 | t2 = 5 - 8 = -3
    addi $t1, $zero, -3            # PC 0x00000018 | HEX 2009FFFD | BIN 001000 00000 01001 1111111111111101 | expected SUB result
    bne  $t2, $t1, fail            # PC 0x0000001C | HEX 1549006E | BIN 000101 01010 01001 0000000001101110 | SUB result must be -3 | target 0x000001D8, displacement +110 word(s)

    addi $t1, $zero, 3             # PC 0x00000020 | HEX 20090003 | BIN 001000 00000 01001 0000000000000011 | restore the second logic operand
    and  $t2, $t0, $t1             # PC 0x00000024 | HEX 01095024 | BIN 000000 01000 01001 01010 00000 100100 | 5 AND 3 = 1
    addi $t1, $zero, 1             # PC 0x00000028 | HEX 20090001 | BIN 001000 00000 01001 0000000000000001 | expected AND result
    bne  $t2, $t1, fail            # PC 0x0000002C | HEX 1549006A | BIN 000101 01010 01001 0000000001101010 | AND result must be 1 | target 0x000001D8, displacement +106 word(s)
    addi $t1, $zero, 3             # PC 0x00000030 | HEX 20090003 | BIN 001000 00000 01001 0000000000000011 | restore the second logic operand
    or   $t2, $t0, $t1             # PC 0x00000034 | HEX 01095025 | BIN 000000 01000 01001 01010 00000 100101 | 5 OR 3 = 7
    addi $t1, $zero, 7             # PC 0x00000038 | HEX 20090007 | BIN 001000 00000 01001 0000000000000111 | expected OR result
    bne  $t2, $t1, fail            # PC 0x0000003C | HEX 15490066 | BIN 000101 01010 01001 0000000001100110 | OR result must be 7 | target 0x000001D8, displacement +102 word(s)
    addi $t1, $zero, 3             # PC 0x00000040 | HEX 20090003 | BIN 001000 00000 01001 0000000000000011 | restore the second logic operand
    xor  $t2, $t0, $t1             # PC 0x00000044 | HEX 01095026 | BIN 000000 01000 01001 01010 00000 100110 | 5 XOR 3 = 6
    addi $t1, $zero, 6             # PC 0x00000048 | HEX 20090006 | BIN 001000 00000 01001 0000000000000110 | expected XOR result
    bne  $t2, $t1, fail            # PC 0x0000004C | HEX 15490062 | BIN 000101 01010 01001 0000000001100010 | XOR result must be 6 | target 0x000001D8, displacement +98 word(s)

    addi $t1, $zero, -1            # PC 0x00000050 | HEX 2009FFFF | BIN 001000 00000 01001 1111111111111111 | signed negative operand
    slt  $t2, $t1, $t0             # PC 0x00000054 | HEX 0128502A | BIN 000000 01001 01000 01010 00000 101010 | -1 < 5 gives 1
    addi $t0, $zero, 1             # PC 0x00000058 | HEX 20080001 | BIN 001000 00000 01000 0000000000000001 | expected true result
    bne  $t2, $t0, fail            # PC 0x0000005C | HEX 1548005E | BIN 000101 01010 01000 0000000001011110 | signed comparison must be true | target 0x000001D8, displacement +94 word(s)
    slt  $t2, $t0, $t1             # PC 0x00000060 | HEX 0109502A | BIN 000000 01000 01001 01010 00000 101010 | 1 < -1 gives 0
    bne  $t2, $zero, fail          # PC 0x00000064 | HEX 1540005C | BIN 000101 01010 00000 0000000001011100 | reversed comparison must be false | target 0x000001D8, displacement +92 word(s)
    addi $t1, $zero, 0             # PC 0x00000068 | HEX 20090000 | BIN 001000 00000 01001 0000000000000000 | save a zero before testing register zero
    addi $zero, $zero, 9           # PC 0x0000006C | HEX 20000009 | BIN 001000 00000 00000 0000000000001001 | attempt to write the zero register
    bne  $zero, $t1, fail          # PC 0x00000070 | HEX 14090059 | BIN 000101 00000 01001 0000000001011001 | register zero must still read zero | target 0x000001D8, displacement +89 word(s)

    addi $t2, $zero, 1             # PC 0x00000074 | HEX 200A0001 | BIN 001000 00000 01010 0000000000000001 | RAM checkpoint 1
    sw   $t2, 0x03F8($zero)        # PC 0x00000078 | HEX AC0A03F8 | BIN 101011 00000 01010 0000001111111000 | arithmetic and logic passed | RAM byte address 0x000003F8

# LUI, shifts, rotate and byte swap
    addi $t0, $zero, 5             # PC 0x0000007C | HEX 20080005 | BIN 001000 00000 01000 0000000000000101 | value to shift
    sll  $t2, $t0, 2               # PC 0x00000080 | HEX 00085080 | BIN 000000 00000 01000 01010 00010 000000 | 5 << 2 = 20
    addi $t1, $zero, 20            # PC 0x00000084 | HEX 20090014 | BIN 001000 00000 01001 0000000000010100 | expected SLL result
    bne  $t2, $t1, fail            # PC 0x00000088 | HEX 15490053 | BIN 000101 01010 01001 0000000001010011 | SLL result must be 20 | target 0x000001D8, displacement +83 word(s)
    srl  $t2, $t2, 1               # PC 0x0000008C | HEX 000A5042 | BIN 000000 00000 01010 01010 00001 000010 | 20 >> 1 = 10
    addi $t1, $zero, 10            # PC 0x00000090 | HEX 2009000A | BIN 001000 00000 01001 0000000000001010 | expected SRL result
    bne  $t2, $t1, fail            # PC 0x00000094 | HEX 15490050 | BIN 000101 01010 01001 0000000001010000 | SRL result must be 10 | target 0x000001D8, displacement +80 word(s)
    rotr $t2, $t0, 1               # PC 0x00000098 | HEX 00285042 | BIN 000000 00001 01000 01010 00001 000010 | 0x00000005 rotates to 0x80000002
    lui  $t1, 0x8000               # PC 0x0000009C | HEX 3C098000 | BIN 001111 00000 01001 1000000000000000 | t1 = 0x80000000
    addi $t1, $t1, 2               # PC 0x000000A0 | HEX 21290002 | BIN 001000 01001 01001 0000000000000010 | expected ROTR result
    bne  $t2, $t1, fail            # PC 0x000000A4 | HEX 1549004C | BIN 000101 01010 01001 0000000001001100 | bit 0 must wrap around to bit 31 | target 0x000001D8, displacement +76 word(s)
    srl  $t2, $t2, 31              # PC 0x000000A8 | HEX 000A57C2 | BIN 000000 00000 01010 01010 11111 000010 | only the top bit remains, at bit 0
    addi $t1, $zero, 1             # PC 0x000000AC | HEX 20090001 | BIN 001000 00000 01001 0000000000000001 | a logical shift fills with zeros
    bne  $t2, $t1, fail            # PC 0x000000B0 | HEX 15490049 | BIN 000101 01010 01001 0000000001001001 | SRL must produce 1 | target 0x000001D8, displacement +73 word(s)

    lui  $t0, 0x1234               # PC 0x000000B4 | HEX 3C081234 | BIN 001111 00000 01000 0001001000110100 | t0 = 0x12340000
    addi $t0, $t0, 0x5678          # PC 0x000000B8 | HEX 21085678 | BIN 001000 01000 01000 0101011001111000 | t0 = 0x12345678
    wsbh $t2, $t0                  # PC 0x000000BC | HEX 7C0850A0 | BIN 011111 00000 01000 01010 00010 100000 | swap bytes in each halfword -> 0x34127856
    lui  $t1, 0x3412               # PC 0x000000C0 | HEX 3C093412 | BIN 001111 00000 01001 0011010000010010 | upper half of the expected result
    addi $t1, $t1, 0x7856          # PC 0x000000C4 | HEX 21297856 | BIN 001000 01001 01001 0111100001010110 | lower half of the expected result
    bne  $t2, $t1, fail            # PC 0x000000C8 | HEX 15490043 | BIN 000101 01010 01001 0000000001000011 | WSBH result must be 0x34127856 | target 0x000001D8, displacement +67 word(s)

    addi $t2, $zero, 2             # PC 0x000000CC | HEX 200A0002 | BIN 001000 00000 01010 0000000000000010 | RAM checkpoint 2
    sw   $t2, 0x03F8($zero)        # PC 0x000000D0 | HEX AC0A03F8 | BIN 101011 00000 01010 0000001111111000 | shifts, LUI, rotate and byte swap passed | RAM byte address 0x000003F8

# Data RAM, consecutive loads and immediate use of the loaded value
    addi $t0, $zero, 21            # PC 0x000000D4 | HEX 20080015 | BIN 001000 00000 01000 0000000000010101 | first RAM word
    addi $t1, $zero, 10            # PC 0x000000D8 | HEX 2009000A | BIN 001000 00000 01001 0000000000001010 | last RAM word
    sw   $t0, 0x0000($zero)        # PC 0x000000DC | HEX AC080000 | BIN 101011 00000 01000 0000000000000000 | RAM byte address 0x00000000
    sw   $t1, 0x03FC($zero)        # PC 0x000000E0 | HEX AC0903FC | BIN 101011 00000 01001 0000001111111100 | RAM byte address 0x000003FC
    addi $t0, $zero, 0             # PC 0x000000E4 | HEX 20080000 | BIN 001000 00000 01000 0000000000000000 | clear t0 before reading it back
    addi $t1, $zero, 0             # PC 0x000000E8 | HEX 20090000 | BIN 001000 00000 01001 0000000000000000 | clear t1 before reading it back
    lw   $t0, 0x0000($zero)        # PC 0x000000EC | HEX 8C080000 | BIN 100011 00000 01000 0000000000000000 | t0 = 21 after the LW stall
    lw   $t1, 0x03FC($zero)        # PC 0x000000F0 | HEX 8C0903FC | BIN 100011 00000 01001 0000001111111100 | t1 = 10 after the next LW stall
    sub  $t2, $t0, $t1             # PC 0x000000F4 | HEX 01095022 | BIN 000000 01000 01001 01010 00000 100010 | immediately use both load results -> 11
    addi $t0, $zero, 11            # PC 0x000000F8 | HEX 2008000B | BIN 001000 00000 01000 0000000000001011 | expected result from the two RAM words
    bne  $t2, $t0, fail            # PC 0x000000FC | HEX 15480036 | BIN 000101 01010 01000 0000000000110110 | both loads must have completed correctly | target 0x000001D8, displacement +54 word(s)

    addi $t2, $zero, 3             # PC 0x00000100 | HEX 200A0003 | BIN 001000 00000 01010 0000000000000011 | RAM checkpoint 3
    sw   $t2, 0x03F8($zero)        # PC 0x00000104 | HEX AC0A03F8 | BIN 101011 00000 01010 0000001111111000 | RAM passed | RAM byte address 0x000003F8

# Branches. First check untaken cases, then check taken cases.
    addi $t0, $zero, -1            # PC 0x00000108 | HEX 2008FFFF | BIN 001000 00000 01000 1111111111111111 | negative input
    addi $t1, $zero, 1             # PC 0x0000010C | HEX 20090001 | BIN 001000 00000 01001 0000000000000001 | positive input
    beq  $t0, $t1, fail            # PC 0x00000110 | HEX 11090031 | BIN 000100 01000 01001 0000000000110001 | different values must not branch | target 0x000001D8, displacement +49 word(s)
    bne  $t1, $t1, fail            # PC 0x00000114 | HEX 15290030 | BIN 000101 01001 01001 0000000000110000 | equal values must not branch | target 0x000001D8, displacement +48 word(s)
    bltz $zero, fail               # PC 0x00000118 | HEX 0400002F | BIN 000001 00000 00000 0000000000101111 | zero is not negative | target 0x000001D8, displacement +47 word(s)
    bgez $t0, fail                 # PC 0x0000011C | HEX 0501002E | BIN 000001 01000 00001 0000000000101110 | -1 is below zero | target 0x000001D8, displacement +46 word(s)
    blez $t1, fail                 # PC 0x00000120 | HEX 1920002D | BIN 000110 01001 00000 0000000000101101 | 1 is above zero | target 0x000001D8, displacement +45 word(s)
    bgtz $zero, fail               # PC 0x00000124 | HEX 1C00002C | BIN 000111 00000 00000 0000000000101100 | zero is not positive | target 0x000001D8, displacement +44 word(s)
    beq  $t1, $t1, equal           # PC 0x00000128 | HEX 11290001 | BIN 000100 01001 01001 0000000000000001 | equal inputs must branch | target 0x00000130, displacement +1 word(s)
    j    fail                      # PC 0x0000012C | HEX 08000076 | BIN 000010 00000000000000000001110110 | reached only if the previous branch fell through | target 0x000001D8
equal:                          # PC 0x00000130
    bne  $t0, $t1, different       # PC 0x00000130 | HEX 15090001 | BIN 000101 01000 01001 0000000000000001 | different inputs must branch | target 0x00000138, displacement +1 word(s)
    j    fail                      # PC 0x00000134 | HEX 08000076 | BIN 000010 00000000000000000001110110 | reached only if the previous branch fell through | target 0x000001D8
different:                      # PC 0x00000138
    bltz $t0, negative             # PC 0x00000138 | HEX 05000001 | BIN 000001 01000 00000 0000000000000001 | -1 must branch | target 0x00000140, displacement +1 word(s)
    j    fail                      # PC 0x0000013C | HEX 08000076 | BIN 000010 00000000000000000001110110 | reached only if the previous branch fell through | target 0x000001D8
negative:                       # PC 0x00000140
    bgez $zero, nonnegative        # PC 0x00000140 | HEX 04010001 | BIN 000001 00000 00001 0000000000000001 | zero qualifies for BGEZ | target 0x00000148, displacement +1 word(s)
    j    fail                      # PC 0x00000144 | HEX 08000076 | BIN 000010 00000000000000000001110110 | reached only if the previous branch fell through | target 0x000001D8
nonnegative:                    # PC 0x00000148
    blez $zero, nonpositive        # PC 0x00000148 | HEX 18000001 | BIN 000110 00000 00000 0000000000000001 | zero qualifies for BLEZ | target 0x00000150, displacement +1 word(s)
    j    fail                      # PC 0x0000014C | HEX 08000076 | BIN 000010 00000000000000000001110110 | reached only if the previous branch fell through | target 0x000001D8
nonpositive:                    # PC 0x00000150
    bgtz $t1, positive             # PC 0x00000150 | HEX 1D200001 | BIN 000111 01001 00000 0000000000000001 | 1 must branch | target 0x00000158, displacement +1 word(s)
    j    fail                      # PC 0x00000154 | HEX 08000076 | BIN 000010 00000000000000000001110110 | reached only if the previous branch fell through | target 0x000001D8
positive:                       # PC 0x00000158
    addi $t0, $zero, 2             # PC 0x00000158 | HEX 20080002 | BIN 001000 00000 01000 0000000000000010 | test a negative branch displacement with two iterations
branch_loop:                    # PC 0x0000015C
    addi $t0, $t0, -1              # PC 0x0000015C | HEX 2108FFFF | BIN 001000 01000 01000 1111111111111111 | decrement the loop counter
    bgtz $t0, branch_loop          # PC 0x00000160 | HEX 1D00FFFE | BIN 000111 01000 00000 1111111111111110 | branch backwards once | target 0x0000015C, displacement -2 word(s)
    bne  $t0, $zero, fail          # PC 0x00000164 | HEX 1500001C | BIN 000101 01000 00000 0000000000011100 | loop must stop at zero | target 0x000001D8, displacement +28 word(s)

    addi $t2, $zero, 4             # PC 0x00000168 | HEX 200A0004 | BIN 001000 00000 01010 0000000000000100 | RAM checkpoint 4
    sw   $t2, 0x03F8($zero)        # PC 0x0000016C | HEX AC0A03F8 | BIN 101011 00000 01010 0000001111111000 | branches passed | RAM byte address 0x000003F8

# J, JAL, JR and JALR. Check the saved PC+4 in each subroutine.
    addi $t2, $zero, 10            # PC 0x00000170 | HEX 200A000A | BIN 001000 00000 01010 0000000000001010 | subroutines add 1 and then 2
    j    call_jal                  # PC 0x00000174 | HEX 0800005F | BIN 000010 00000000000000000001011111 | skip the failure instruction | target 0x0000017C
    j    fail                      # PC 0x00000178 | HEX 08000076 | BIN 000010 00000000000000000001110110 | reached only if J falls through | target 0x000001D8
call_jal:                       # PC 0x0000017C
    jal  add_one                   # PC 0x0000017C | HEX 0C00006E | BIN 000011 00000000000000000001101110 | write the address of return_jal to ra | target 0x000001B8, link 0x00000180
return_jal:                     # PC 0x00000180
    addi $t0, $zero, 11            # PC 0x00000180 | HEX 2008000B | BIN 001000 00000 01000 0000000000001011 | t2 must be 11 after returning through ra
    bne  $t2, $t0, fail            # PC 0x00000184 | HEX 15480014 | BIN 000101 01010 01000 0000000000010100 | verify the JAL/JR result | target 0x000001D8, displacement +20 word(s)
    addi $t0, $zero, 0x01C8        # PC 0x00000188 | HEX 200801C8 | BIN 001000 00000 01000 0000000111001000 | load the byte address for the register jump
    jalr $t1, $t0                  # PC 0x0000018C | HEX 01004809 | BIN 000000 01000 00000 01001 00000 001001 | jump to add_two and save return_jalr in t1 | target 0x000001C8, link 0x00000190
return_jalr:                    # PC 0x00000190
    addi $t0, $zero, 13            # PC 0x00000190 | HEX 2008000D | BIN 001000 00000 01000 0000000000001101 | t2 must be 13 after returning through t1
    bne  $t2, $t0, fail            # PC 0x00000194 | HEX 15480010 | BIN 000101 01010 01000 0000000000010000 | verify the JALR/JR result | target 0x000001D8, displacement +16 word(s)

    addi $t2, $zero, 5             # PC 0x00000198 | HEX 200A0005 | BIN 001000 00000 01010 0000000000000101 | RAM checkpoint 5
    sw   $t2, 0x03F8($zero)        # PC 0x0000019C | HEX AC0A03F8 | BIN 101011 00000 01010 0000001111111000 | jumps and links passed | RAM byte address 0x000003F8

# Bus integration. Check the unmapped read result, then signal PASS.
    lui  $t0, 0x1000               # PC 0x000001A0 | HEX 3C081000 | BIN 001111 00000 01000 0001000000000000 | base for the unmapped MMIO check
    lw   $t2, 0x0200($t0)          # PC 0x000001A4 | HEX 8D0A0200 | BIN 100011 01000 01010 0000001000000000 | 0x10000200 is an unmapped page; t2 should become 0
    bne  $t2, $zero, fail          # PC 0x000001A8 | HEX 1540000B | BIN 000101 01010 00000 0000000000001011 | unmapped read must return zero | target 0x000001D8, displacement +11 word(s)
    addi $t2, $zero, 6             # PC 0x000001AC | HEX 200A0006 | BIN 001000 00000 01010 0000000000000110 | RAM checkpoint 6
    sw   $t2, 0x03F8($zero)        # PC 0x000001B0 | HEX AC0A03F8 | BIN 101011 00000 01010 0000001111111000 | all groups passed | RAM byte address 0x000003F8
passed:                         # PC 0x000001B4
    j    passed                    # PC 0x000001B4 | HEX 0800006D | BIN 000010 00000000000000000001101101 | stay here when the test passes | target 0x000001B4

add_one:                        # PC 0x000001B8
    addi $t0, $zero, 0x0180        # PC 0x000001B8 | HEX 20080180 | BIN 001000 00000 01000 0000000110000000 | expected PC+4 from JAL
    bne  $ra, $t0, fail            # PC 0x000001BC | HEX 17E80006 | BIN 000101 11111 01000 0000000000000110 | check the link written to ra | target 0x000001D8, displacement +6 word(s)
    addi $t2, $t2, 1               # PC 0x000001C0 | HEX 214A0001 | BIN 001000 01010 01010 0000000000000001 | t2 = 11
    jr   $ra                       # PC 0x000001C4 | HEX 03E00008 | BIN 000000 11111 00000 00000 00000 001000 | return to return_jal | target 0x00000180

add_two:                        # PC 0x000001C8
    addi $t0, $zero, 0x0190        # PC 0x000001C8 | HEX 20080190 | BIN 001000 00000 01000 0000000110010000 | expected PC+4 from JALR
    bne  $t1, $t0, fail            # PC 0x000001CC | HEX 15280002 | BIN 000101 01001 01000 0000000000000010 | check the link written to t1 | target 0x000001D8, displacement +2 word(s)
    addi $t2, $t2, 2               # PC 0x000001D0 | HEX 214A0002 | BIN 001000 01010 01010 0000000000000010 | t2 = 13
    jr   $t1                       # PC 0x000001D4 | HEX 01200008 | BIN 000000 01001 00000 00000 00000 001000 | return to return_jalr | target 0x00000190

fail:                           # PC 0x000001D8
    addi $t2, $zero, 7             # PC 0x000001D8 | HEX 200A0007 | BIN 001000 00000 01010 0000000000000111 | RAM checkpoint 7
    sw   $t2, 0x03F8($zero)        # PC 0x000001DC | HEX AC0A03F8 | BIN 101011 00000 01010 0000001111111000 | report the failed check | RAM byte address 0x000003F8
failed:                         # PC 0x000001E0
    j    failed                    # PC 0x000001E0 | HEX 08000078 | BIN 000010 00000000000000000001111000 | stay here when a check fails | target 0x000001E0
