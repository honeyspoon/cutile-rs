#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2026 Abderahmane Bouziane
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

repo=${1:?usage: run_narrow_float_oracle.sh REPOSITORY}
if [[ ! -d "$repo/cuda-core/examples" ]]; then
  echo "not a cutile-rs checkout: $repo" >&2
  exit 2
fi

repo=$(cd "$repo" && pwd)
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
rust_oracle="$repo/cuda-core/examples/fork_ci_narrow_float_oracle.rs"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir" "$rust_oracle"' EXIT
nvcc_bin=${NVCC:-${CUDA_TOOLKIT_PATH:-/usr/local/cuda}/bin/nvcc}

cp "$script_dir/oracle/narrow_float_oracle.rs" "$rust_oracle"
"$nvcc_bin" -std=c++17 -O2 "$script_dir/oracle/narrow_float_oracle.cu" \
  -o "$tmp_dir/cuda-oracle"
"$tmp_dir/cuda-oracle" > "$tmp_dir/cuda.bin"
(
  cd "$repo"
  cargo run --locked --release --quiet -p cuda-core \
    --example fork_ci_narrow_float_oracle
) > "$tmp_dir/rust.bin"

cmp "$tmp_dir/cuda.bin" "$tmp_dir/rust.bin"
echo "CUDA and Rust narrow-float conversions match byte-for-byte"
