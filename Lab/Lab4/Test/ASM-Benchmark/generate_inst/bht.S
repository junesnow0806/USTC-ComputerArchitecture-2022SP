.org 0x0
 	.global _start
_start:
    addi t0, zero, 0 # 00
    addi t1, zero, 0 # 04
    addi t2, zero, 0
    addi t3, zero, 10
for_out: 
    addi t2, t2, 1 # 10
for_in:
    add  t1, t1, t0 # 14
    addi t0, t0, 1
    bne  t0, t3, for_in # 1c
    addi t0, zero, 0
    bne  t2, t3, for_out # 24
    addi t1, t1, 1 # 28
