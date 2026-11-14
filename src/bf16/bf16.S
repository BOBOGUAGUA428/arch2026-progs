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
    # sign、指數、小數
    xor     t6, a0, a1          # 第15位是result的sign
    srli    t6, t6, 15
    slli    t6, t6, 15          # t6=只留sign位
    srli    t0, a0, 7
    andi    t0, t0, 0xFF        # t0=a的指數
    srli    t1, a1, 7
    andi    t1, t1, 0xFF        # t1=b的指數
    andi    t2, a0, 0x7F        # t2=a的小數
    andi    t3, a1, 0x7F        # t3=b的小數
    li      t4, 0xFF

    # a的Inf/NaN(規格要求先a後b)
    bne     t0, t4, .Lmul_chk_b
    bnez    t2, .Lmul_ret       # a是NaN：原樣回傳a
    slli    t5, a1, 17          # 去掉sign位，全0代表b是±0
    beqz    t5, .Lmul_nan       # Inf×0=NaN
    j       .Lmul_inf           # b是NaN也回傳Inf

.Lmul_chk_b:
    # b的Inf/NaN
    bne     t1, t4, .Lmul_chk_zero
    bnez    t3, .Lmul_ret_b     # b是NaN：原樣回傳b
    slli    t5, a0, 17
    beqz    t5, .Lmul_nan
    j       .Lmul_inf

.Lmul_chk_zero:
    # 任一邊是±0：回傳帶sign的0
    slli    t5, a0, 17
    beqz    t5, .Lmul_ret_sign
    slli    t5, a1, 17
    beqz    t5, .Lmul_ret_sign

    # 補回隱藏的1
    beqz    t0, .Lmul_a_sub     # denormal先正規化
    ori     t2, t2, 0x80
.Lmul_a_done:
    beqz    t1, .Lmul_b_sub
    ori     t3, t3, 0x80
.Lmul_b_done:

    # 8位×8位shift-and-add
    li      t5, 0               # 乘積
.Lmul_loop:
    andi    a2, t3, 1
    beqz    a2, .Lmul_skip
    add     t5, t5, t2          # 乘數這一位是1：加上被乘數
.Lmul_skip:
    slli    t2, t2, 1
    srli    t3, t3, 1
    bnez    t3, .Lmul_loop

    # 指數相加，乘積正規化
    add     t0, t0, t1
    addi    t0, t0, -127
    srli    a2, t5, 15          # 乘積第15位(0或1)
    srli    t5, t5, 7
    srl     t5, t5, a2          # 第15位是1就多移1位
    add     t0, t0, a2          # 同時指數+1

    # 溢位和下溢
    bge     t0, t4, .Lmul_inf   # 指數>=255
    blez    t0, .Lmul_under     # 指數<=0

    # 組合
    andi    t5, t5, 0x7F        # 去掉隱藏的1
    slli    t0, t0, 7
    or      a0, t6, t0
    or      a0, a0, t5
.Lmul_ret:
    ret

.Lmul_under:
    li      a2, -6
    blt     t0, a2, .Lmul_ret_sign  # 指數<-6：回傳帶sign的0
    andi    t5, t5, 0x7F        # 規格：先去掉隱藏的1再右移
    li      a2, 1
    sub     a2, a2, t0
    srl     t5, t5, a2          # 右移(1-指數)位
    or      a0, t6, t5
    ret
.Lmul_ret_b:
    mv      a0, a1
    ret
.Lmul_inf:
    slli    a0, t4, 7           # 0xFF<<7=0x7F80
    or      a0, a0, t6
    ret
.Lmul_nan:
    li      a0, 0x7FC0
    ret
.Lmul_ret_sign:
    mv      a0, t6
    ret
.Lmul_a_sub:
    li      t0, 1               # denormal的指數當成1
.Lmul_a_norm:
    slli    t2, t2, 1
    addi    t0, t0, -1
    andi    a2, t2, 0x80
    beqz    a2, .Lmul_a_norm    # 第7位還不是1就繼續
    j       .Lmul_a_done
.Lmul_b_sub:
    li      t1, 1
.Lmul_b_norm:
    slli    t3, t3, 1
    addi    t1, t1, -1
    andi    a2, t3, 0x80
    beqz    a2, .Lmul_b_norm
    j       .Lmul_b_done
    .size   bf16_mul_asm, .-bf16_mul_asm

    .globl  bf16_sqrt_asm
    .type   bf16_sqrt_asm, @function
    .align  2
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
