# Workflow: Run a sweep from a frozen copy of the runner

**Date**: 2026-09-22
**Lesson**: A `--from-file` sweep re-spawns its children from the on-disk
`zig-out/bin/wpt_runner`, so rebuilding mid-sweep contaminates the rest of it.
Copy the binary into `tmp/` and sweep from the copy. (And a fresh worktree needs
`mkdir -p zig-out/bin` before its first build, or the snapshot generator fails
with FileNotFound.)

**Takeaway**: **A sweep's result belongs to the binary its children exec.**
