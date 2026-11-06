#include "fixed.h"

uint32_t op1(uint32_t a, uint32_t b, int *n)
{
    *n = 0;
    while (b != 0) {
        uint32_t temp = (a & b)
                        << 1;  // 資料傳進來後把a變成無視進位的和，b為進位的值
        a = a ^ b;
        b = temp;
        (*n)++;
    }

    return a;
}

uint32_t op2(uint32_t a, uint32_t b)
{
    return a - b;
}

uint32_t op3(uint32_t a, uint32_t b)
{
    return (a >> 1) + (b >> 1) + ((a & 1) & (b & 1));
}

int32_t q_mul(int32_t a, int32_t b)
{
    uint32_t ua = (uint32_t) a;
    uint32_t ub = (uint32_t) b;

    uint32_t ah = ua >> 16;
    uint32_t al = ua & 0xFFFF;  // ua=ah*(2^16)+al

    uint32_t bh = ub >> 16;
    uint32_t bl = ub & 0xFFFF;  // ub=bh*(2^16)+bl

    // ua * ub =(ah*bh)*(2^32)+(ah*bl)*(2^16)+(al*bh)*(2^16)+(al*bl)


    uint32_t p0 = al * bl;
    uint32_t p1 = ah * bl;
    uint32_t p2 = al * bh;
    uint32_t p3 = ah * bh;

    uint64_t product = ((uint64_t) p3 << 32) + ((uint64_t) p2 << 16) +
                       ((uint64_t) p1 << 16) + (uint64_t) p0;

    if (a < 0)
        product -= ((uint64_t) ub << 32);

    if (b < 0)
        product -= ((uint64_t) ua << 32);



    product += (uint64_t) 1 << (Q - 1);

    // 右移 20位，只保留低 32 位
    uint32_t result_bits = (uint32_t) (product >> Q);

    return (int32_t) result_bits;
}
