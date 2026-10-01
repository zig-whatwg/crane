# Codegen: A committed generated tree needs committed, pinned inputs

**Date**: 2026-10-01
**Lesson**: The generated WebIDL tree was committed but its main input, specs/idl, was gitignored and fetched from webref `main` by `zig build setup`, so no check could regenerate it and a fresh clone got whatever webref was that day.

**Why**: "Generated files are committed" only means something if the generator's inputs are committed too. Otherwise a drift check is either impossible (lane mirrors had no specs/idl) or fails spuriously on a different snapshot.

**What Happened**: The codegen lane needed a from-scratch drift check. specs/idl existed only in the main checkout and chat's main mirror, with no recorded revision. It also held 7 Crane files mixed in with webref's 334 (copies of specs/supplementary, plus 3 that existed nowhere else), so a webref update would have silently deleted Crane's own definitions.

**Fix**:
1. Recover the revision: `git hash-object` every local file and compare with `git/trees/<sha>` of webref's `ed/idl` for each commit in the date window (`gh api repos/w3c/webref/commits?path=ed/idl&since=..&until=..`). One commit (08fb1a310e) matched all 334 files exactly; the 7 extras were the Crane files.
2. Commit specs/idl as pure webref at that SHA, record it in specs/idl/WEBREF.md with the update procedure, move Crane's files to specs/supplementary with provenance headers, and stop setup overwriting it.
3. Only then add the check (`zig build codegen-check`, in `zig build test`).

**Takeaway**: **Before checking a generated tree, pin and commit everything that generates it; an unrecorded upstream revision can be recovered by matching blob hashes against the upstream's trees.**
