# op1, op2, op3 and q_mul: hand-written RV32I.
#
# uint32_t op1_asm(uint32_t a, uint32_t b, int *n)   a0, a1, a2 -> a0
# uint32_t op2_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# uint32_t op3_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# int32_t  q_mul_asm(int32_t a, int32_t b)           a0, a1 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. q_mul forms a 64-bit product in a register pair. Tests:
# tests/tfixed.c.

    .text

    .globl  op1_asm
    .type   op1_asm, @function
    .align  2
op1_asm:
    li      t0, 0               # 輪數放在t0
    beqz    a1, .Lop1_done      # b 一開始就是 0，直接return

    .Lop1_loop:
        and     t1, a0, a1          # a & b，會進位的位置
        xor     a0, a0, a1          # a ^ b不含進位的和
        slli    a1, t1, 1           # (a & b) << 1進位往左移一位
        addi    t0, t0, 1           
        bnez    a1, .Lop1_loop      # 還有進位就繼續跑

    .Lop1_done:
        sw      t0, 0(a2)           
        ret
    .size   op1_asm, .-op1_asm

    .globl  op2_asm
    .type   op2_asm, @function
    .align  2

op2_asm:
    sub     a0, a0, a1         # a=a-b無號數相減，結果超出範圍時自動對 2^32 取餘數（繞回）
    ret
    .size   op2_asm, .-op2_asm

    .globl  op3_asm
    .type   op3_asm, @function
    .align  2

op3_asm:                        #(a + b) / 2 = (a ^ b) / 2 + (a & b)* 2 / 2(抵銷)
    and     t0, a0, a1          # a & b,兩個都是 1，相加時會產生進位的位置
    xor     a0, a0, a1          # a ^ b不含進位的和
    srli    a0, a0, 1           # (a ^ b) >> 1，把不含進位的和除以 2
    add     a0, a0, t0          
    ret                         
    .size   op3_asm, .-op3_asm

    .globl  q_mul_asm
    .type   q_mul_asm, @function
    .align  2

q_mul_asm:
    li      a0, 0
    ret
    .size   q_mul_asm, .-q_mul_asm
