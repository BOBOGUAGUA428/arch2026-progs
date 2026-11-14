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

op3_asm:                        #(a+b)/2=(a^b) / 2+(a&b)*2/2(抵銷)
    and     t0, a0, a1          # a&b,兩個都是 1，相加時會產生進位的位置
    xor     a0, a0, a1          # a^b不含進位的和
    srli    a0, a0, 1           # (a^b)>>1，把不含進位的和除以 2
    add     a0, a0, t0          
    ret                         
    .size   op3_asm, .-op3_asm

    .globl  q_mul_asm
    .type   q_mul_asm, @function
    .align  2

q_mul_asm:
    # 1. 判斷result的正負， 以及先將 a b 轉絕對值
    xor     t3, a0, a1          # t3的最高位為result的正負（a b正負號不同時為1）
    srai    t0, a0, 31          # a是負數時全 1，否則全 0（srai是看最高位的正負補1 0）
    xor     a0, a0, t0          #做補數if a為負數則t0為全1，a各bit全部翻轉
    sub     a0, a0, t0          # if a為正a-0不變， ifa為負，則~a-(-1)=~a+1
    srai    t0, a1, 31
    xor     a1, a1, t0
    sub     a1, a1, t0          # a1 = |b|，同時也是 lo 的初始值

    # 2. 相乘結果放在 t1（hi）和 a1（lo）
    li      t1, 0               # hi = 0
    li      t2, 32              # loop要跑 32 輪
    .Lqm_loop:
        andi    t0, a1, 1           # 這一輪的乘數bit（lo 的最低位）
        beqz    t0, .Lqm_skip       # 0不用加
        add     t1, t1, a0          # 1則hi += |a|
    .Lqm_skip:
        slli    t0, t1, 31          # hi的最低位，準備放進 lo（左移31，擺到最高位）
        srli    a1, a1, 1           # lo右移：用過的乘數bit移出去
        or      a1, a1, t0          # hi的最低位放進 lo 的最高位
        srli    t1, t1, 1           # hi右移
        addi    t2, t2, -1          # 剩下的輪數減 1
        bnez    t2, .Lqm_loop

    # 3. 結果應該是負數時，把 hi:lo 取負號
    bgez    t3, .Lqm_round      # result為正，跳過
    #Set Less Than Unsigned (0 < lo) ? 1 : 0；無號數大於 0
    sltu    t0, zero, a1            # lo 不是 0 時，hi 要多減 1（借位），借位是自動借的
    sub     a1, zero, a1            #-lo= 0-lo
    sub     t1, zero, t1            #-hi=  0-hi
    sub     t1, t1, t0              #自己判斷有沒有借位，if借位 0-hi-1 ，else 0-hi-0

    # 4. 加上 2^19 四捨五入(先加一半能後砍掉)
    .Lqm_round:
        li      t0, 0x80000         # t0=2^19
        add     a1, a1, t0          # lo+=2^19
        sltu    t0, a1, t0          #小於代表繞回，設1進位
        add     t1, t1, t0          # 進位加到 hi

    # 5. 取第 20～51 位
    srli    a1, a1, 20              #lo 右移20位：原本的第20～31位
    slli    t1, t1, 12              #hi 左移12位：hi的第0～19位（就是 64 位元的第 32～51 位）
    or      a0, a1, t1
    ret
    .size   q_mul_asm, .-q_mul_asm
