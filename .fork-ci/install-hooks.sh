#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2026 Abderahmane Bouziane
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

target=${1:?usage: install-hooks.sh CONTRIBUTION_WORKTREE}
target=$(cd "$target" && pwd)
source_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
git_dir=$(git -C "$target" rev-parse --git-common-dir)
if [[ $git_dir != /* ]]; then
  git_dir="$target/$git_dir"
fi

mkdir -p "$git_dir/hooks" "$git_dir/fork-ci"
cp "$source_dir/pr_policy.py" "$git_dir/fork-ci/pr_policy.py"
cp "$source_dir/push-and-validate.sh" "$git_dir/fork-ci/push-and-validate.sh"
cp "$source_dir/hooks/pre-commit" "$git_dir/hooks/pre-commit"
cp "$source_dir/hooks/pre-push" "$git_dir/hooks/pre-push"
chmod +x \
  "$git_dir/fork-ci/pr_policy.py" \
  "$git_dir/fork-ci/push-and-validate.sh" \
  "$git_dir/hooks/pre-commit" \
  "$git_dir/hooks/pre-push"

echo "Installed cuTile contributor hooks in $git_dir/hooks"
