#include "bf16.h"

uint16_t bf16_from_f32(uint32_t f32bits)
{
    // 取high 16 bit和 low 16 bit
    uint16_t high = f32bits >> 16;
    uint16_t low = f32bits & 0xFFFF;

    // 檢查NaN和Inf
    uint8_t exp = (f32bits >> 23) & 0xFF;
    if (exp == 255) {
        return high;
    }

    // RNE 檢查進位
    if (low > 0x8000 || ((low == 0x8000) && (high & 1) == 1)) {
        high++;
    }

    return high;
}


uint16_t bf16_mul(uint16_t a, uint16_t b)
{
    // 取得 Sign
    uint16_t s = (a >> 15) ^ (b >> 15);

    // 取得 Exponent
    int32_t expa = (a >> 7) & 0xFF;
    int32_t expb = (b >> 7) & 0xFF;

    // 取得 Fraction
    uint16_t frac_a = a & 0x7F;
    uint16_t frac_b = b & 0x7F;

    // 先處理 a 的 NaN / Infinity
    if (expa == 255) {
        if (frac_a != 0)
            return a;  // Nan

        // b為+-0 Infinity* +-0 =NaN
        if ((b & 0x7FFF) == 0)
            return 0x7FC0;

        // 不然回傳Infinity
        return (uint16_t) ((s << 15) | 0x7F80);
    }

    // 再處理 b 的 NaN / Infinity
    if (expb == 255) {
        if (frac_b != 0)
            return b;

        if ((a & 0x7FFF) == 0)
            return 0x7FC0;

        return (uint16_t) ((s << 15) | 0x7F80);
    }

    // 處理 Zero
    if ((a & 0x7FFF) == 0 || (b & 0x7FFF) == 0) {
        return (uint16_t) (s << 15);
    }

    // 處理 a 的有效數字
    uint32_t ma = frac_a;

    if (expa == 0) {
        // Denormal 沒有 Hidden Bit
        expa = 1;  // 1-127=-126

        while (ma < 128) {  // 做正規化
            ma <<= 1;       // 多乘一個2 指數-1
            expa--;
        }
    } else {
        // Normal 有 Hidden Bit
        ma |= 0x80;
    }

    // 處理 b 的有效數字
    uint32_t mb = frac_b;

    if (expb == 0) {
        expb = 1;

        while (mb < 128) {
            mb <<= 1;
            expb--;
        }
    } else {
        mb |= 0x80;
    }

    // 有效數字相乘
    uint32_t mr = ma * mb;

    // 計算指數
    int32_t expr = expa + expb - 127;

    // 正規化
    if (mr & 0x8000) {
        mr >>= 8;
        expr++;
    } else {
        mr >>= 7;
    }

    // Overflow
    if (expr >= 255) {
        return (uint16_t) ((s << 15) | 0x7F80);
    }

    // 太小，回傳 Zero
    if (expr < -6) {
        return (uint16_t) (s << 15);
    }

    // Underflow，轉成 Denormal
    if (expr <= 0) {
        mr = (mr & 0x7F) >> (1 - expr);  // 先 & 0x7F 去掉隱藏的 1，再右移
        return (uint16_t) ((s << 15) | mr);
    }

    //  Normal 結果，重新組合 BF16
    uint16_t result =
        (uint16_t) ((s << 15) | ((uint32_t) expr << 7) | (mr & 0x7F));

    return result;
}

uint16_t bf16_sqrt(uint16_t a)
{
    (void) a;
    return 0;
}
