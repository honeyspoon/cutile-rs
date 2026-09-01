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

static uint8_t scale_covering(float value) {
  if (std::isnan(value)) {
    return __nv_cvt_float_to_e8m0(
        value, __NV_SATFINITE, cudaRoundPosInf);
  }
  if (value <= 0.0f) {
    return 0;
  }
  return __nv_cvt_float_to_e8m0(
      value, __NV_SATFINITE, cudaRoundPosInf);
}

static void write_encodings(float value) {
  const uint8_t encoded[] = {
      __nv_cvt_float_to_fp8(value, __NV_SATFINITE, __NV_E4M3),
      __nv_cvt_float_to_fp8(value, __NV_NOSAT, __NV_E5M2),
      static_cast<uint8_t>(__nv_cvt_float_to_fp4(
          value, __NV_E2M1, cudaRoundNearest)),
      scale_covering(value),
  };
  std::fwrite(encoded, sizeof(encoded), 1, stdout);
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

  // Special classes are deliberately separate from the pseudorandom corpus:
  // all-ones f32 exponents below are rewritten to finite values.
  constexpr uint32_t special_inputs[] = {
      0x00000000, 0x80000000,  // signed zero
      0x00000001, 0x80000001,  // smallest signed subnormal
      0x007FFFFF, 0x807FFFFF,  // largest signed subnormal
      0x00800000, 0x80800000,  // smallest signed normal
      0x7F7FFFFF, 0xFF7FFFFF,  // largest signed finite
      0x7F800000, 0xFF800000,  // infinities
      0x7F800001, 0xFF800001,  // signaling NaNs, minimal payload
      0x7FC00000, 0xFFC00000,  // quiet NaNs
      0x7FFFFFFF, 0xFFFFFFFF,  // NaNs, maximal payload
  };
  for (uint32_t bits : special_inputs) {
    float value;
    std::memcpy(&value, &bits, sizeof(value));
    write_encodings(value);
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
    write_encodings(value);
  }
}
