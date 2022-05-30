.org 0x0
 	.global _start
_start:
    addi t0, zero, 0 # 00
    addi t1, zero, 0 # 04
    addi t2, zero, 101 # 08
for:
    add  t1, t1, t0 # 0c
    addi t0, t0, 1 # 10
    bne  t0, t2, for # 14
    addi t1, t1, 1 # 18
