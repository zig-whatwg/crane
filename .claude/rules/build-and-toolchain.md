---
paths:
  - "build.zig"
  - "build.zig.zon"
  - ".claude/worktrees/*/build.zig"
  - ".claude/worktrees/*/build.zig.zon"
---

# Building Crane: caches, -j and the toolchain

Moved verbatim from AGENTS.md (2026-11-03), section "Before every commit". The core keeps each rule as one line and points here. Claude Code loads this file for the paths above; Codex and a Bash read find it through the core's index.

`zig build test` also includes `crane-check` (crane compiled without linking); the integrator's merge check runs `zig build check-linux -j2` and the full `zig build crane -j2`.

**Local builds use `--cache-dir ~/Library/Caches/crane-z16-cache`, never a cache in `/tmp`.** macOS
deletes `/tmp` files untouched for three days (`com.apple.tmp_cleaner`, nightly at 00:00), and Zig trusts a
cache hit without re-checking its output, so a half-pruned cache entry stays a "hit" with files missing: on
2026-10-02 it made the iOS build fail with `'mbedtls/version.h' file not found` and looked like a build.zig
regression ([lesson](docs/lessons/workflow-a-zig-cache-in-tmp-is-pruned-by-macos-and-zig-still-trusts-it.md)).
**Codegen is the exception: `zig build codegen` and `codegen-check` run with a cache of your own**
(`--cache-dir ~/Library/Caches/crane-<lane>-codegen`, deleted when you are done). The shared cache serves
whichever worktree last built the codegen binary, so a regeneration can silently use another lane's
generator: on 2026-10-17 lane leaks4's regeneration picked up lane worklets' unmerged generator hunk.

**Never run a bare `zig build`, and always pass `-j2`.** In a pool job the hosts' zig shim replaces
the `-j` you pass with that host's fair share of root compiles, which it sizes from free memory and the
builds sharing the host. So `-j2` is the Mac's hard cap, and on chat/chat2 it is only a request (the user,
2026-11-01: a fixed `-j2` left a quiet 64 GB host idle). `build.zig` installs
19 artifacts, and every one that embeds the tree is a separate root-module
analysis of ~1M lines at ~6 GB of RAM each, three at a time by default. One
bare build is 18 GB; one bare build plus two agents doing the same on a 32 GB
machine is swap, which is what a load average of 68 looked like on 2026-09-22.
`wpt-runner` builds the single executable the WPT loop uses; `-j2` caps the
concurrent root compiles for `test`, which has many. The `wpt` step
(`zig build wpt -j2 -- <path>`) builds `wpt_runner` and runs it - it used to
depend on the whole install step (all 19 artifacts) AND `kill -9` every process
on the WPT ports first, which took the shared server down under three agents
mid-run. Both are gone; but on a shared machine prefer the binary directly:

```bash
./zig-out/bin/wpt_runner --from-file=<list> --parallel=1 --wpt-root=tests/wpt --output=<dir>
```

**The toolchain is Zig 0.17, pinned** (the user, 2026-10-28): a build of the
0.17.x branch at 77c319a0f00a (`zig version`: `0.17.1-dev+77c319a0f0`), because
0.17.0 cannot build aarch64-ios (ziglang/zig#37061, fixed for 0.17.1). It lives
at `~/crane-toolchains/zig-0.17.1-dev+77c319a0f0/` on the Mac and every pool
host; `build.zig.zon`'s `minimum_zig_version` says 0.17, and the pool's zig shim
picks the toolchain from it. Switch to 0.17.1 when it ships.

- **`zig build` takes no `--global-cache-dir`.** The global cache is set only
  through `ZIG_GLOBAL_CACHE_DIR` (the pool's shim exports `~/.cache/zig-017`, a
  cache 0.16 never shared); `--cache-dir` works as before.
- **The configuration is cached.** `build.zig` runs in a configure process
  whose result Zig 0.17 caches: anything it reads from the machine at configure
  time (a file probe, `xcrun`, `curl-config`) must call
  `b.graph.poisonCache()`, or a changed machine reuses a stale configuration.
- **The macOS SDK is the default one.** Zig 0.17's libc++ builds against the
  macOS 27 SDK, so the 0.16 workaround that built against a 26.x SDK through a
  libc file (`useBuildableMacosSdk`, the `INFINITY` break) is gone. Do not put
  an `xcrun` shim on PATH: Zig asks `xcrun --sdk macosx --show-sdk-path`, and
  `/tmp/sdkshim` broke the build twice by answering it with the wrong SDK.
