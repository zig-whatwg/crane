# Workflow: Freeze the tree while a test run compiles

**Date**: 2026-09-22
**Lesson**: Under load, `zig build test` reads sources for ~20 minutes - an
edit landing in that window is compiled into some test binaries and not others.
Stage edits in `tmp/` until it finishes. Also: git worktrees share one stash
list, so pop by name; and `zig build test` prints "failed command" for passing
steps that wrote to stderr - judge it by its exit status.
