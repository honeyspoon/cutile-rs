#!/usr/bin/env python3
# SPDX-FileCopyrightText: Copyright (c) 2026 Abderahmane Bouziane
# SPDX-License-Identifier: Apache-2.0

"""Mechanical contributor checks kept outside upstreamable branches."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


FORK_ONLY_PATHS = (
    ".fork-ci/",
    ".github/workflows/fork-validate.yml",
)
SOURCE_SUFFIXES = {".c", ".cc", ".cpp", ".cu", ".h", ".hpp", ".py", ".rs", ".sh"}
COMMIT_SUBJECT = re.compile(
    r"^(build|chore|ci|doc|docs|feat|fix|perf|refactor|test)(\([^)]+\))?!?: [a-z0-9]"
)


def git(repo: Path, *args: str, check: bool = True) -> str:
    result = subprocess.run(
        ["git", *args], cwd=repo, text=True, capture_output=True, check=False
    )
    if check and result.returncode:
        sys.stderr.write(result.stdout)
        sys.stderr.write(result.stderr)
        raise SystemExit(result.returncode)
    return result.stdout


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} REPOSITORY BASE", file=sys.stderr)
        return 2

    repo = Path(sys.argv[1]).resolve()
    base = sys.argv[2]
    errors: list[str] = []
    warnings: list[str] = []

    merge_base = git(repo, "merge-base", base, "HEAD").strip()
    raw_changes = git(
        repo, "diff", "--name-status", "-z", f"{merge_base}..HEAD"
    ).split("\0")
    changes: list[tuple[str, str]] = []
    index = 0
    while index < len(raw_changes) and raw_changes[index]:
        status = raw_changes[index]
        path = raw_changes[index + 1]
        changes.append((status, path))
        index += 3 if status.startswith(("R", "C")) else 2

    paths = [path for _, path in changes]
    for path in paths:
        if path.startswith(FORK_ONLY_PATHS):
            errors.append(f"fork-only tooling leaked into contribution: {path}")

    diff_check = subprocess.run(
        ["git", "diff", "--check", f"{merge_base}..HEAD"],
        cwd=repo,
        text=True,
        capture_output=True,
        check=False,
    )
    if diff_check.returncode:
        errors.append(f"git diff --check failed:\n{diff_check.stdout}{diff_check.stderr}")

    commits = git(repo, "rev-list", "--reverse", "--no-merges", f"{merge_base}..HEAD")
    for commit in commits.splitlines():
        subject = git(repo, "show", "-s", "--format=%s", commit).strip()
        body = git(repo, "show", "-s", "--format=%B", commit)
        author_email = git(repo, "show", "-s", "--format=%ae", commit).strip()
        if not COMMIT_SUBJECT.match(subject):
            errors.append(f"{commit[:12]} has a non-conventional subject: {subject!r}")
        signoffs = re.findall(r"(?im)^Signed-off-by: .+ <([^>]+)>\s*$", body)
        if author_email.lower() not in {email.lower() for email in signoffs}:
            errors.append(
                f"{commit[:12]} lacks a Signed-off-by trailer for {author_email}"
            )
        if "Claude-Session:" in body or "ChatGPT-Session:" in body:
            warnings.append(f"{commit[:12]} contains an assistant-session trailer")

    for status, relative in changes:
        path = repo / relative
        if status.startswith("D") or not path.is_file():
            continue
        if status.startswith("A") and path.suffix in SOURCE_SUFFIXES:
            head = "\n".join(path.read_text(errors="replace").splitlines()[:12])
            if "SPDX-License-Identifier:" not in head:
                errors.append(f"new source file has no SPDX header: {relative}")
        if status.startswith("A") and path.stat().st_size > 1024 * 1024:
            errors.append(f"new file exceeds 1 MiB: {relative}")

    added_lines = git(repo, "diff", "--unified=0", f"{merge_base}..HEAD")
    forbidden = re.compile(r"^\+.*\b(dbg!|todo!|unimplemented!)\s*\(", re.MULTILINE)
    for match in forbidden.finditer(added_lines):
        errors.append(f"temporary debugging/placeholder macro added: {match.group(1)}")

    production_rust_changed = any(
        path.endswith(".rs") and "/tests/" not in f"/{path}" and not path.endswith("build.rs")
        for path in paths
    )
    tests_added = bool(re.search(r"^\+\s*#\[(?:tokio::)?test\]", added_lines, re.MULTILINE))
    if production_rust_changed and not tests_added:
        warnings.append("production Rust changed without a newly added #[test]")

    if len(paths) > 25:
        warnings.append(f"large review surface: {len(paths)} changed files")

    print(f"base: {base} ({merge_base[:12]})")
    print(f"changed files: {len(paths)}; non-merge commits: {len(commits.splitlines())}")
    for warning in warnings:
        print(f"warning: {warning}")
    for error in errors:
        print(f"error: {error}", file=sys.stderr)
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
