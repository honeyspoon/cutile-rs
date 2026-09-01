#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2026 Abderahmane Bouziane
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

remote=${1:-origin}
branch=${2:-$(git branch --show-current)}
if [[ -z $branch || $branch == fork-ci ]]; then
  echo "refusing to publish an empty or fork-only contribution branch" >&2
  exit 2
fi

git push "$remote" "HEAD:$branch"
target_ref=$(git ls-remote --exit-code "$remote" "refs/heads/$branch" | awk '{print $1}')
if [[ ! $target_ref =~ ^[0-9a-f]{40}$ ]]; then
  echo "could not resolve $remote/$branch to a commit" >&2
  exit 2
fi

gh workflow run fork-validate.yml \
  --repo honeyspoon/cutile-rs \
  --ref fork-ci \
  -f "target_ref=$target_ref" \
  -f base_ref=main

echo "Dispatched fork validation for $branch at $target_ref"
