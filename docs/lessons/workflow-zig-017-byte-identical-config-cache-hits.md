# Workflow: Zig 0.17 Caches Tree-Embedding Compiles Across Byte-Identical Build Edits

**Date**: 2026-11-26
**Lesson**: `build.zig` on Zig 0.17 has no undeclared or over-broad cache input invalidating the tree-embedding compiles across byte-identical configurations; `--cache-dir` is passed verbatim in the compiler `@args` file, so cache-hit proofs must reuse the same `--cache-dir` path and untouched `src/` bytes.

**Why**: An undeclared or over-broad cache input on the 6 tree-embedding artifacts (`wpt_runner`, `wpt_runner_bug_finding`, `repl`, release `repl`, `gc_bench`, `crane`) would add 6–15 minutes to every incremental build.

**What Happened**: In lane `bp1` batch P4 c1 (`6f9f7795c`, `chat2.local`), the 6 tree-embedding artifacts recompiled against `p4base` even though the build configuration (`A`) was byte-identical (`section_diff`: `SAME PROGRAM`, with debug `crane` differing only in two thread-sharded `___anon_` intern-pool names), while `c2`–`c4` hit cache.

**Fix**: Investigated directly on macOS (`chat.local`, base `029f57376`) with `--summary all` and inspection of `$CACHE/args/*`:
1. Cold build of `repl-exe` + `wpt-runner` (`121/121` steps) followed by a back-to-back identical build: **100% cached** (0 recompiles).
2. Comment-only edits to `build.zig`, `src/platform/kit/kit_build.zig`, and `src/platform/platform_build_protocol.zig` (forcing a full build-runner recompile and reconfigure with byte-identical configuration): **`wpt_runner` cached 215 ms, `snapshot_generator` cached 272 ms, `repl` cached 272 ms** (0 recompiles).
3. Touching `build.zig.zon`: **100% cached** (`wpt_runner` 185 ms, `snapshot_generator` 225 ms, `repl` 172 ms).
4. Fresh `rsync` after editing only `tests/wpt_runner/`: **`repl` cached 179 ms, `snapshot_generator` cached 178 ms** (only `wpt_runner` recompiled).
5. Inspecting `$CACHE/args/*` showed all module and archive inputs are repo-relative or content-hashed (`o/<blake3>/...`), with no ambient timestamp, git, or environment leak; `--cache-dir <abs_path>` is an explicit compiler argument, so any path change or cache relocation invalidates compiles even when `A` is identical. No `build.zig` bug remained to patch (`check-configure-cache` and `lint-build` both at 0).

**Takeaway**: **Verify Zig 0.17 compile cache hits with back-to-back `--summary all` runs in the exact same `--cache-dir` and inspect `$CACHE/args/*`; `build.zig` already hits cache 100% across byte-identical reconfigures.**
