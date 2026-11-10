# gcd_u32_asm: binary GCD, hand-written RV32I.
#
# uint32_t gcd_u32_asm(uint32_t a, uint32_t b)   a in a0, b in a1, result in a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tgcd.c.

    .text

    .globl  gcd_u32_asm
    .type   gcd_u32_asm, @function
    .align  2

#a0,a1參數 ,t0 count,t1 暫存奇偶判斷結果,t2 暫存a or b 的結果

gcd_u32_asm:
    # 檢查a b是否都為0
    or t2, a0, a1
    li t0, 0
    beqz t2, .Ldone
    

.Lcommon:
    #   提示：兩個都是偶數，等於 (a | b) 的最低位是 0
    andi t1, t2, 1
    bnez t1, .Lloop #代表一奇一偶 或兩奇

    srli a0, a0, 1
    srli a1, a1, 1
    addi t0, t0, 1
    srli t2, t2, 1
    j .Lcommon



.Lloop:
    # 當a or b，其中一方為0，則外圈loop結束
    #     去掉偶數那一邊的 2 因子
    beqz a0, .Ldone
    beqz a1, .Ldone
    andi t1, a0, 1
    bnez  t1, .Lshiftb

    .Lshifta:
    srli a0, a0, 1
    andi t1, a0, 1
    beqz t1, .Lshifta
    
    .Lcompare:
    #大的減小的
    bltu a0, a1, .Lsub_b
    sub a0, a0, a1
    bnez a0,  .Lshifta

    .Ldone:
    # 用or(因為一方為0)重組並把前面簡化的倍率乘回來;
    or a0, a0, a1
    sll a0, a0, t0
    ret

    .Lsub_b:
    sub a1, a1, a0

    .Lshiftb_even:              #確定b已經為even
    srli a1, a1, 1

    .Lshiftb:
    andi t1, a1, 1 #可能是兩奇，先判斷
    beqz t1, .Lshiftb_even
    j .Lcompare

    .size   gcd_u32_asm, .-gcd_u32_asm
