# Workflow: A zig local cache shared by two checkouts can serve one the other's binary

**Date**: 2026-10-02
**Lesson**: Never point two checkouts of the same project at one zig local cache (`--cache-dir` /
`ZIG_LOCAL_CACHE_DIR`): a cache hit in one can run a binary built from the other's sources.

**Why**: zig's local-cache manifests (`<cache>/h/<key>.txt`) record each input file with its
stat and content hash, but some inputs are recorded by ABSOLUTE path. Two checkouts whose builds
compute the same manifest key look up the same manifest, and the second checkout then validates
the first checkout's files - unchanged, so the check passes - and reuses the first checkout's
output. Its own, different files are never hashed.

**What Happened**: Every mirror on chat.local (one per lane, plus main) built with
`--cache-dir ~/crane-cache` to share work. The teardown lane's `zig build test` failed
codegen-check with 1,358 generated files differing: the codegen binary it ran
(`~/crane-cache/o/cf34b71c.../codegen`) had been written while the instances lane was building, and
it emitted `pub fn installHooks()` - text that existed only in the instances mirror's
`src/webidl/codegen/writer.zig`. The manifest that served it listed
`/Users/bcardarella/crane-work/instances/src/webidl/codegen/writer.zig`. The same check with a
private cache passed. Any gate or A/B on chat could have measured another lane's code; main's
frozen runner was checked by symbol (realms2's `WrapperCache.deferEdge`, crashes4's
`WorkerHost.takeTimerId` present) before its baseline sweep was trusted.

**Fix**: Each mirror builds in its own local cache, `~/crane-caches/<mirror>`:
`tmp/remote/crane-remote.sh` sets `ZIG_LOCAL_CACHE_DIR` and rewrites `zig build` to pass it, and
the chat zig shim (`tmp/remote/zig-shim.sh`, deployed as `~/crane-bin/zig`) maps an explicit
`--cache-dir ~/crane-cache` to it, so scripts that hard-code the old path cannot escape. zig's
GLOBAL cache (`~/.cache/zig`: zig-lib artifacts such as compiler_rt and libc++) stays shared - its
inputs are the same files for every checkout. The cost is one cold build per mirror.

**Takeaway**: **A build cache is per checkout. Sharing one between checkouts trades minutes of
compile time for results that may belong to someone else's tree - and nothing says so.** When a
gate's result looks like another branch's code, check which binary actually ran (its mtime, its
symbols, the manifest that served it) before debugging the code.
