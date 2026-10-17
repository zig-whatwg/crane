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

**Status (2026-10-12)**: it holds on this Mac too. AGENTS.md's one local cache,
`~/Library/Caches/crane-z16-cache`, is shared by every worktree under `.claude/worktrees/`. Lane bindlpo
ran `zig build codegen -- --dest-root src/webidl/` with it while lane implsb2 was changing the codegen.
The run rewrote 1,260 generated interfaces with implsb2's construction-chain text, where bindlpo's own
codegen wrote one line. A lane-private cache (`~/Library/Caches/crane-<lane>-cache`, deleted with the lane)
gave the one line. Run codegen, or any build whose output you commit, from a lane's own cache, and read
`git status` after every regeneration.

**Status (2026-10-17)**: a third occurrence, again on this Mac. Lane bindtype ran `zig build codegen -j2
--cache-dir ~/Library/Caches/crane-z16-cache -- --dest-root src/webidl/` in its worktree (base 93275d76703,
its codegen changes uncommitted) while lane idlupdate was changing the codegen in its worktree. The codegen
that ran failed on bindtype's own specs/idl with `error: Element.setHTMLUnsafe is declared twice (again in
sanitizer-integration.idl)` and `error.DuplicateMember`, and its stack trace named
`.claude/worktrees/idlupdate/src/webidl/codegen/ir.zig`. The two trees' codegen sources differed:
generator.zig, writer.zig, pipeline.zig, inherited_mixins.zig and member_overrides.zig, the last being the
table that decides that duplicate. The same command with a lane-private cache (`--cache-dir
~/Library/Caches/crane-z16-cache-bindtype`) built bindtype's codegen, regenerated without error, and
codegen-check matched it. The failed run wrote nothing, which is the only reason it was harmless: it failed
in stage 1, before any file was written. AGENTS.md still names the one shared local cache for every local
build. Until it changes, a lane runs codegen and every build whose output it commits from a lane-private
cache.
