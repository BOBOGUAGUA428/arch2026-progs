#include "gcd.h"

uint32_t gcd_u32(uint32_t a, uint32_t b)
{
    uint32_t count = 0;

    if (a == 0 && b == 0) {  // 先解決都為0的情況 以免進入while導致無限迴圈
        return 0;
    }

    while ((a & 1) == 0 &&
           (b & 1) == 0) {  // 兩者都是偶數，把2提出直到一方不為偶數
        a >>= 1;
        b >>= 1;
        count++;
    }

    while (a != 0 && b != 0) {  // 一奇一偶，把2提出直到兩者為奇數

        if ((a & 1) == 0) {
            while ((a & 1) == 0) {
                a >>= 1;
            }

        } else {
            while ((b & 1) == 0) {
                b >>= 1;
            }
        }
        if (a >= b) {  // 相減最大因數不變
            a = a - b;
        } else
            b = b - a;
    }

    return (a | b) << count;
}
