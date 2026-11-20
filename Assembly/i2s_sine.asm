# Fill data RAM with one period of the sine wave, then play it on repeat.
# Each word has a signed 16-bit left sample and a zero right sample.
# Table addresses: 0x00000100 to 0x000001BC.
# SW0 off plays left. SW0 on swaps to the right with ROTR.
# I2S MMIO: sample write at 0x10000300, ready bit 0 at 0x10000304.

load_samples:                   # 0x000
    lui  $t2, 0x0000
    sw   $t2, 0x0100($zero)      # Sample 0
    lui  $t2, 0x061E
    sw   $t2, 0x0104($zero)      # Sample 1
    lui  $t2, 0x0C22
    sw   $t2, 0x0108($zero)      # Sample 2
    lui  $t2, 0x11F0
    sw   $t2, 0x010C($zero)      # Sample 3
    lui  $t2, 0x1770
    sw   $t2, 0x0110($zero)      # Sample 4
    lui  $t2, 0x1C89
    sw   $t2, 0x0114($zero)      # Sample 5
    lui  $t2, 0x2125
    sw   $t2, 0x0118($zero)      # Sample 6
    lui  $t2, 0x2530
    sw   $t2, 0x011C($zero)      # Sample 7
    lui  $t2, 0x2898
    sw   $t2, 0x0120($zero)      # Sample 8
    lui  $t2, 0x2B4F
    sw   $t2, 0x0124($zero)      # Sample 9
    lui  $t2, 0x2D47
    sw   $t2, 0x0128($zero)      # Sample 10
    lui  $t2, 0x2E79
    sw   $t2, 0x012C($zero)      # Sample 11

    lui  $t2, 0x2EE0
    sw   $t2, 0x0130($zero)      # Sample 12
    lui  $t2, 0x2E79
    sw   $t2, 0x0134($zero)      # Sample 13
    lui  $t2, 0x2D47
    sw   $t2, 0x0138($zero)      # Sample 14
    lui  $t2, 0x2B4F
    sw   $t2, 0x013C($zero)      # Sample 15
    lui  $t2, 0x2898
    sw   $t2, 0x0140($zero)      # Sample 16
    lui  $t2, 0x2530
    sw   $t2, 0x0144($zero)      # Sample 17
    lui  $t2, 0x2125
    sw   $t2, 0x0148($zero)      # Sample 18
    lui  $t2, 0x1C89
    sw   $t2, 0x014C($zero)      # Sample 19
    lui  $t2, 0x1770
    sw   $t2, 0x0150($zero)      # Sample 20
    lui  $t2, 0x11F0
    sw   $t2, 0x0154($zero)      # Sample 21
    lui  $t2, 0x0C22
    sw   $t2, 0x0158($zero)      # Sample 22
    lui  $t2, 0x061E
    sw   $t2, 0x015C($zero)      # Sample 23

    lui  $t2, 0x0000
    sw   $t2, 0x0160($zero)      # Sample 24
    lui  $t2, 0xF9E2
    sw   $t2, 0x0164($zero)      # Sample 25
    lui  $t2, 0xF3DE
    sw   $t2, 0x0168($zero)      # Sample 26
    lui  $t2, 0xEE10
    sw   $t2, 0x016C($zero)      # Sample 27
    lui  $t2, 0xE890
    sw   $t2, 0x0170($zero)      # Sample 28
    lui  $t2, 0xE377
    sw   $t2, 0x0174($zero)      # Sample 29
    lui  $t2, 0xDEDB
    sw   $t2, 0x0178($zero)      # Sample 30
    lui  $t2, 0xDAD0
    sw   $t2, 0x017C($zero)      # Sample 31
    lui  $t2, 0xD768
    sw   $t2, 0x0180($zero)      # Sample 32
    lui  $t2, 0xD4B1
    sw   $t2, 0x0184($zero)      # Sample 33
    lui  $t2, 0xD2B9
    sw   $t2, 0x0188($zero)      # Sample 34
    lui  $t2, 0xD187
    sw   $t2, 0x018C($zero)      # Sample 35

    lui  $t2, 0xD120
    sw   $t2, 0x0190($zero)      # Sample 36
    lui  $t2, 0xD187
    sw   $t2, 0x0194($zero)      # Sample 37
    lui  $t2, 0xD2B9
    sw   $t2, 0x0198($zero)      # Sample 38
    lui  $t2, 0xD4B1
    sw   $t2, 0x019C($zero)      # Sample 39
    lui  $t2, 0xD768
    sw   $t2, 0x01A0($zero)      # Sample 40
    lui  $t2, 0xDAD0
    sw   $t2, 0x01A4($zero)      # Sample 41
    lui  $t2, 0xDEDB
    sw   $t2, 0x01A8($zero)      # Sample 42
    lui  $t2, 0xE377
    sw   $t2, 0x01AC($zero)      # Sample 43
    lui  $t2, 0xE890
    sw   $t2, 0x01B0($zero)      # Sample 44
    lui  $t2, 0xEE10
    sw   $t2, 0x01B4($zero)      # Sample 45
    lui  $t2, 0xF3DE
    sw   $t2, 0x01B8($zero)      # Sample 46
    lui  $t2, 0xF9E2
    sw   $t2, 0x01BC($zero)      # Sample 47

playback:                       # 0x180
    lui  $t4, 0x1000           # 0x180: MMIO base = 0x10000000
    addi $t5, $zero, 1         # 0x184: Mask for SW0 and I2S ready

restart:                        # 0x188
    addi $t0, $zero, 0x0100    # 0x188: First sample in data RAM
    addi $t1, $zero, 48        # 0x18C: Samples remaining

next_sample:                    # 0x190
    lw   $t2, 0($t0)           # 0x190: Read one stereo word from RAM
    lw   $t3, 0x0100($t4)      # 0x194: Read the GPIO switches
    and  $t3, $t3, $t5         # 0x198: Keep SW0
    beq  $t3, $zero, wait_ready # 0x19C: SW0 off, branch to 0x1A4
    rotr $t2, $t2, 16          # 0x1A0: Swap the two 16-bit channels

wait_ready:                     # 0x1A4
    lw   $t3, 0x0304($t4)      # 0x1A4: Read I2S status
    and  $t3, $t3, $t5         # 0x1A8: Keep the ready bit
    beq  $t3, $zero, wait_ready # 0x1AC: Queue full, branch to 0x1A4
    sw   $t2, 0x0300($t4)      # 0x1B0: Queue the stereo word

    addi $t0, $t0, 4           # 0x1B4: Next RAM word
    addi $t1, $t1, -1          # 0x1B8: One fewer sample to send
    bgtz $t1, next_sample      # 0x1BC: More samples, branch to 0x190
    j    restart               # 0x1C0: Loop playback from 0x188
