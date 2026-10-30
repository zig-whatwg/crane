# Workflow: A semantic change is as wide as its condition, not its spelling

**Date**: 2026-10-28
**Status**: 2026-10-29 (lane zigprep1) - tools/hasdecl_audit.zig is committed with its `hasdecl-audit` step; the two flips in tests/css/ci1_image_dependencies_test.zig are fixed (`pub`), and the three in held files (src/css/cascade.zig collectCandidates and CandidateIndex, src/dom/style/engine.zig treeCounts) are reported `known` until the port window.
**Lesson**: Zig 0.17's silent `@hasDecl` change reaches only a same-file non-pub declaration: of 17,624 uses on main the text clears 17,605, and a 0.16 build of probe copies finds exactly 5 flips among the other 19 - all in test guards, none in the binding.

**Why**: Zig 0.16 answers `@hasDecl(T, "x")` true for a pub `x`, and for a non-pub `x` only
when the `@hasDecl` is in the file that declares `x`. Zig 0.17 drops the second case. A non-pub
declaration of another file was already invisible, so an answer can flip only where a file asks
about a non-pub declaration it declares itself. The generated interfaces' 15,000 impl lookups
(`@hasDecl(impls, "call_x")`) all cross a file boundary and cannot flip.

**What Happened**: The 2026-10-02 analysis counted 4,158 uses (14,958 lines by the trial) and
treated every one as a silent risk to the binding, which finds impl functions by name. Lane
zig017trial wrote tools/hasdecl_audit.zig: it resolves each target through std.zig.Ast
(`@This()`, `const X = struct`, `A.B`, `@import`) and checks whether the file declares the asked
name non-pub. 3 sites change for certain, 16 are possible (a parameter or computed target). `--instrument` wraps those 19 in a probe that
`@compileLog`s `HASDECL-FLIP <path>:<line>` where 0.16's answer differs from the pub-only one
(`std.meta.declarations` lists pub declarations only, in 0.16 too); a 0.16 build of the copies
(check-target and zig build test) printed exactly 5: cascade.zig's `collectCandidates` and
`CandidateIndex`, style/engine.zig's `treeCounts`, and tests/css/ci1's `Checks.run`/`negative` - all
RED-first test guards that would turn 12 tests into loud failures, none in crane or wpt_runner. The
first run under-measured: the probe's pub-only loop hit the 1,000-branch eval quota on a generated
interface's declaration list, an error that hid that site until the probe raised its quota.

**Fix**: Before a toolchain change with a silent semantic difference, find the condition under
which the answer can differ and narrow by it statically; then measure the remainder with the
OLD compiler, which still knows both answers. The probe must not use the `comptime` keyword at
the call site (a redundant `comptime` in a comptime scope is a compile error) - an `inline fn`
returning `comptime blk: {...}` makes the pub-only answer comptime-known everywhere.

**Takeaway**: **A semantic change is as wide as its condition, not its spelling: count the uses
the condition can reach, then let the old compiler say which of them flip.**
