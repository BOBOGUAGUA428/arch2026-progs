# BFloat16 routines: hand-written RV32I.
#
# uint16_t bf16_from_f32_asm(uint32_t f32bits)   a0 -> a0
# uint16_t bf16_mul_asm(uint16_t a, uint16_t b)  a0, a1 -> a0
# uint16_t bf16_sqrt_asm(uint16_t a)             a0 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tbf16.c.

    .text

    .globl  bf16_from_f32_asm
    .type   bf16_from_f32_asm, @function
    .align  2

bf16_from_f32_asm:
    # 指數全1(Inf/NaN)：高16位原樣回傳
    slli    t0, a0, 1           # 左移1位去掉sign
    li      t1, 0xFF000000      # t1=0xFF000000(最高8位全1)
    bgeu    t0, t1, .Lf32_top   # t0>=t1代表指數是0xFF可能是Inf或NaN，直接去取前16位

    # 四捨五入(平手取偶數)：加上0x7FFF和第16位
    srli    t0, a0, 16          # 第16位移到最低位
    andi    t0, t0, 1           # 留第16位
    add     a0, a0, t0          # 32bit加第16位的bit
    li      t1, 0x7FFF          # t1=0x7FFF
    add     a0, a0, t1          # 加0x7FFF
.Lf32_top:
    srli    a0, a0, 16          # 取前16位
    ret
    .size   bf16_from_f32_asm, .-bf16_from_f32_asm

    .globl  bf16_mul_asm
    .type   bf16_mul_asm, @function
    .align  2

bf16_mul_asm:
    li      a0, 0
    ret
    .size   bf16_mul_asm, .-bf16_mul_asm

    .globl  bf16_sqrt_asm
    .type   bf16_sqrt_asm, @function
    .align  2

bf16_sqrt_asm:
    # 特殊值
    srli    t0, a0, 7
    andi    t0, t0, 0xFF        # t0=指數
    andi    t1, a0, 0x7F        # t1=小數
    li      t2, 0xFF
    beq     t0, t2, .Lsq_special    # 指數255：NaN或Inf
    slli    t3, a0, 17          # 去掉sign位，全0代表±0
    beqz    t3, .Lsq_zero
    srli    t3, a0, 15
    bnez    t3, .Lsq_nan        # 負數：NaN
    beqz    t0, .Lsq_zero       # denormal：+0

    # 奇數指數先變偶數
    ori     t1, t1, 0x80        # m=補回隱藏的1
    addi    t0, t0, -127        # e=真正的指數
    andi    t2, t0, 1           # e是奇數嗎(0或1)
    sll     t1, t1, t2          # 奇數：m乘2
    sub     t0, t0, t2          # 奇數：e減1
    srai    t0, t0, 1           # e/2(算術右移保留負號)
    addi    t0, t0, 127         # 新的指數欄位

    # N=128*m+127
    slli    t1, t1, 7
    addi    t1, t1, 127

    # 逐位元整數平方根：最大的res使res*res<=N
    li      t2, 0               # res
    li      t3, 0x4000          # bit=4的7次方
.Lsq_loop:
    add     t4, t2, t3          # res+bit
    srli    t2, t2, 1
    bltu    t1, t4, .Lsq_skip   # N<res+bit：這一位是0
    sub     t1, t1, t4
    add     t2, t2, t3          # 這一位是1
.Lsq_skip:
    srli    t3, t3, 2
    bnez    t3, .Lsq_loop

    # 組合
    andi    t2, t2, 0x7F        # 去掉隱藏的1
    slli    t0, t0, 7
    or      a0, t0, t2
    ret

.Lsq_special:
    bnez    t1, .Lsq_ret        # NaN：原樣回傳
    srli    t3, a0, 15
    bnez    t3, .Lsq_nan        # -Inf：NaN
.Lsq_ret:
    ret                         # +Inf：原樣回傳
.Lsq_nan:
    li      a0, 0x7FC0
    ret
.Lsq_zero:
    li      a0, 0
    ret
    .size   bf16_sqrt_asm, .-bf16_sqrt_asm
