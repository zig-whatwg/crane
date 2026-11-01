# Workflow: Zig 0.17 package storage is generated, not source

**Date**: 2026-11-01
**Lesson**: A complete source-inventory check must distinguish Zig's root `zig-pkg/` storage from the source and dependency identities it authenticates.

**Why**: The pinned Zig 0.17 compiler uses `build_root/zig-pkg` as its package-storage directory. Package directories are named by hashes from `build.zig.zon`; stale versions may remain beside the selected versions. A build can populate this directory without changing any declared source file.

**What Happened**: A focused font-stretch preview reached its expected runtime failures, but the post-test source check rejected 9,029 newly materialized package files. All 9,212 declared source hashes still matched. Because that check stopped the script, the dependency checkpoint and required positive control did not run. The result was incomplete despite the expected assertion failures.

**Fix**: Classify only the exact root `zig-pkg/` as generated storage, alongside the explicit build-output exclusions. Keep every declared source hash, the pinned `build.zig.zon` bytes, compiler and external-dependency hashes, and all other inventory rules. A new file anywhere else still fails the check. Record whether package storage exists and list its top-level names for provenance; stale names are not a failure. Preserve the original verifier and incomplete receipt, then repeat the entire test/control job with all checkpoints. Do not turn a later read-only audit into the checkpoint that never ran.

The pinned distribution documents this in `lib/zig/compiler/Maker.zig` (default package root) and `Maker/Fetch.zig` (`LocalStorage` and package extraction). Crane's `.gitignore` already names `/zig-pkg/`; use that specific classification, not a blanket exclusion of every ignored path. Row 131 ANSWER Q70 approved this verification method.

**Takeaway**: **Authenticate source and dependency identity explicitly; generated package storage must not masquerade as a source change or hide a missed verification step.**
