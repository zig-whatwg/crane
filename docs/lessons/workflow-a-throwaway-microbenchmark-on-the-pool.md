# Workflow: A throwaway microbenchmark on the pool - its own git repo, a build script, the pinned Zig

**Date**: 2026-11-10
**Lesson**: To run a standalone microbenchmark on the compute pool without a Crane worktree: give it its own git repo under tmp/ (crane-remote syncs the git toplevel it runs in), build it from a script (crane-remote rewrites `zig build` in the COMMAND string, which turns `zig build-exe` into `zig build --cache-dir <x>-exe`), and call the pinned 0.17 binary by path (the pool's `zig` shim picks 0.16.0 for a tree without a build.zig.zon declaring 0.17).

**Why**: crane-remote.sh and crane-pool.sh are built around Crane trees: the mirror is the git toplevel of the caller's directory (the MAIN checkout is refused for non-main mirrors), the command string is rewritten for cache paths, and ~/crane-bin/zig chooses the toolchain from build.zig.zon.

**What Happened**: Lane ndalloc b1 (a design batch with no worktree) needed tree-walk, address-space and allocator microbenchmarks on chat.local and server1. The first build printed 0.16.0 (the shim's default); `zig build-exe` in the command would have been mangled by the rewrite.

**Fix**: `git init` in tmp/plans/<lane>-bench; a `build.sh` that runs `$HOME/crane-toolchains/zig-0.17.1-dev+77c319a0f0/bin/zig build-exe` with `ZIG_GLOBAL_CACHE_DIR=~/.cache/zig-017`; `crane-remote.sh <mirror> 'bash build.sh'` from inside that directory; runs through `crane-pool.sh wpt <mirror> --pair perf 'bash run.sh <mode>'` (macOS) and `--os linux --pair <id>` (server1), each chunk checking the mirror's STOP file. Delete the mirrors, their caches and -bins at the end.

**Takeaway**: **A microbenchmark outside Crane's tree still runs on the pool the normal way: own git repo, build in a script, pinned toolchain by path.**
