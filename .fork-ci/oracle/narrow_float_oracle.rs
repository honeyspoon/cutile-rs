// SPDX-FileCopyrightText: Copyright (c) 2026 Abderahmane Bouziane
// SPDX-License-Identifier: Apache-2.0

use std::io::{self, Write};

use cuda_core::{f4e2m1fn, f8e4m3fn, f8e5m2, f8e8m0fnu};

fn write_f32(out: &mut impl Write, value: f32) {
    let bits = if value.is_nan() {
        f32::NAN.to_bits()
    } else {
        value.to_bits()
    };
    out.write_all(&bits.to_le_bytes()).unwrap();
}

fn write_encodings(out: &mut impl Write, value: f32) {
    out.write_all(&[
        f8e4m3fn::from_f32(value).0,
        f8e5m2::from_f32(value).0,
        f4e2m1fn::from_f32(value).0,
        f8e8m0fnu::scale_covering(value).0,
    ])
    .unwrap();
}

fn main() {
    let mut out = io::BufWriter::new(io::stdout().lock());
    for bits in 0..=u8::MAX {
        write_f32(&mut out, f8e4m3fn(bits).to_f32());
        write_f32(&mut out, f8e5m2(bits).to_f32());
        write_f32(&mut out, f8e8m0fnu(bits).to_f32());
    }
    for bits in 0..16 {
        write_f32(&mut out, f4e2m1fn(bits).to_f32());
    }

    let special_inputs = [
        0x0000_0000,
        0x8000_0000,
        0x0000_0001,
        0x8000_0001,
        0x007F_FFFF,
        0x807F_FFFF,
        0x0080_0000,
        0x8080_0000,
        0x7F7F_FFFF,
        0xFF7F_FFFF,
        0x7F80_0000,
        0xFF80_0000,
        0x7F80_0001,
        0xFF80_0001,
        0x7FC0_0000,
        0xFFC0_0000,
        0x7FFF_FFFF,
        0xFFFF_FFFF,
    ];
    for bits in special_inputs {
        write_encodings(&mut out, f32::from_bits(bits));
    }

    let mut state = 0xC0FF_EE12u32;
    for _ in 0..1_000_000 {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        let mut bits = state;
        if bits & 0x7F80_0000 == 0x7F80_0000 {
            bits &= !0x0080_0000;
        }
        let value = f32::from_bits(bits);
        write_encodings(&mut out, value);
    }
}
