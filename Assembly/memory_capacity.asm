# Fixture for tb_memories: independent words across the 1 KiB ROM.
# This image is not the SoC demonstration program.
.org 0x000
    lui  $t0, 0x1234
    addi $t1, $zero, 5
.org 0x100
    addi $t2, $zero, 0x100
.org 0x3FC
    addi $t3, $zero, 0x3FC
