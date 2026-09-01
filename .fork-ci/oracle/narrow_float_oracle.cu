// SPDX-FileCopyrightText: Copyright (c) 2026 Abderahmane Bouziane
// SPDX-License-Identifier: Apache-2.0

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>

#include <cuda_fp4.h>
#include <cuda_fp8.h>

static void write_float(float value) {
  uint32_t bits;
  if (std::isnan(value)) {
    value = NAN;
  }
  std::memcpy(&bits, &value, sizeof(bits));
  std::fwrite(&bits, sizeof(bits), 1, stdout);
}

int main() {
  for (unsigned bits = 0; bits <= UINT8_MAX; ++bits) {
    __nv_fp8_e4m3 e4;
    __nv_fp8_e5m2 e5;
    __nv_fp8_e8m0 e8;
    e4.__x = static_cast<uint8_t>(bits);
    e5.__x = static_cast<uint8_t>(bits);
    e8.__x = static_cast<uint8_t>(bits);
    write_float(static_cast<float>(e4));
    write_float(static_cast<float>(e5));
    write_float(static_cast<float>(e8));
  }
  for (unsigned bits = 0; bits < 16; ++bits) {
    __nv_fp4_e2m1 e2;
    e2.__x = static_cast<uint8_t>(bits);
    write_float(static_cast<float>(e2));
  }

  uint32_t state = 0xC0FFEE12u;
  for (unsigned i = 0; i < 1000000; ++i) {
    state ^= state << 13;
    state ^= state >> 17;
    state ^= state << 5;
    uint32_t bits = state;
    if ((bits & 0x7F800000u) == 0x7F800000u) {
      bits &= ~0x00800000u;
    }
    float value;
    std::memcpy(&value, &bits, sizeof(value));
    const uint8_t encoded[] = {
        __nv_cvt_float_to_fp8(value, __NV_SATFINITE, __NV_E4M3),
        __nv_cvt_float_to_fp8(value, __NV_NOSAT, __NV_E5M2),
        static_cast<uint8_t>(__nv_cvt_float_to_fp4(
            value, __NV_E2M1, cudaRoundNearest)),
        (value > 0.0f && !std::signbit(value))
            ? __nv_cvt_float_to_e8m0(
                  value, __NV_SATFINITE, cudaRoundPosInf)
            : uint8_t{0},
    };
    std::fwrite(encoded, sizeof(encoded), 1, stdout);
  }
}
