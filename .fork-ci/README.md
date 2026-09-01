# Fork-only contributor validation

This branch contains checks for `honeyspoon/cutile-rs`; it must never be
merged into an upstream contribution branch. Contribution branches should be
created from `NVlabs/cutile-rs:main`, and `pr_policy.py` rejects these paths if
they appear in the upstream diff.

Run the hosted checks after pushing a contribution branch:

```bash
gh workflow run fork-validate.yml \
  --repo honeyspoon/cutile-rs \
  --ref fork-ci \
  -f target_ref=feat/my-branch \
  -f base_ref=main
```

Install the local pre-commit and pre-push checks from a `fork-ci` worktree:

```bash
.fork-ci/install-hooks.sh /path/to/contribution/worktree
```

The hosted checks enforce contributor hygiene, Rust 1.89 compatibility,
formatting, scoped zero-warning clippy, rustdoc, compile-only workspace tests,
debug/release narrow-float tests, and a byte-for-byte comparison with the
official CUDA 13.3 host conversions.
