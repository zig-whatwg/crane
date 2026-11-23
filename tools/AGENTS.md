# Tools and their lints

Moved verbatim from AGENTS.md (2026-11-03). The core keeps each rule as one line and points here.

## Tools are Zig

Crane is a Zig repo, and its tools are Zig. Anything committed to `tools/` or
run by `build.zig` is written in Zig, built by `build.zig` for the host
(`.target = b.graph.host`, as `codegen` is), and tested with `std.testing`
test blocks that `zig build test` runs. No Python, shell or JavaScript tools -
with one exception, the existing WPT tools (below).

- **A gate must not add an interpreter to the build.** A Python lint wired into
  `zig build test` makes every machine that builds Crane need Python to run its
  tests, and cannot be tested the way this repo tests things.
- **Tests first applies to tools.** Pin a tool's rules in `std.testing` blocks
  before relying on it - the Zig port of the impls-boundary lint caught a swap
  the first draft's rule could not see.
- **Scratch analysis is not a tool** - a throwaway query over a journal in the
  scratchpad is fine. The moment it is committed, wired into a build step, or
  anyone would run it twice, it is written in Zig.
- **The existing WPT tools are allowed as they are, in whatever language they
  are written in.** That is the upstream harness in `tests/wpt/` (`wpt serve`
  and the rest of WPT's own tooling are Python) and Crane's WPT scripts,
  `tools/wpt_progress.py` (run by `zig build wpt-progress`) and
  `tools/wpt_subset.py`. Use and maintain them without porting them. A NEW tool
  is Zig, WPT-related or not.
- **Any other non-Zig tool is debt, not precedent:** today that is
  `tools/update_impl_signatures.py`. Port it to Zig when you next need to change
  it; never add another.

## lint-impls: the check of the impls boundary

The rule itself: [src/webidl/AGENTS.md](../src/webidl/AGENTS.md), "The impls boundary".

The boundary is held twice, and neither has a baseline (lane impls9,
2026-11-17; the debt reached zero in lane impls8):

- **The module graph** - `zig build check-impls-boundary`, part of `zig build
  test`: only the interfaces, namespaces and mixins modules import `impls`, and
  each impl is a module of its own, so the compiler rejects a reference from
  anywhere else (src/webidl/AGENTS.md, "The impls boundary", has the messages).
  build.zig's `checkImplsBoundary` walks every module of every compile at
  configure time - reading no file - and fails the step on any import the rule
  forbids; its compile-failure cases (`expect_errors`, a one-line file in a
  module with a copy of a real module's imports) pin the compiler's answers.
- **`zig build lint-impls`** - also part of `zig build test` - names any
  reference by file, line and `Impl.member`, before anything compiles:

```bash
zig build lint-impls -j2 --cache-dir ~/Library/Caches/crane-z16-cache                # fails on any reference into an impl
zig build lint-impls -j2 --cache-dir ~/Library/Caches/crane-z16-cache -- --list      # every site, path:line Impl.member
zig build lint-impls -j2 --cache-dir ~/Library/Caches/crane-z16-cache -- --update    # the naming and unchecked-state ratchets only
```

`tools/lint_impls_boundary.zig` scans src/ (outside the generated layers),
tests/ and tools/: in an impl, every reference to another impl, ancestors
included; elsewhere, every use of the `impls` module, `impls.<helper>` included.
A path import is resolved against its file's directory, so any path into
`src/webidl/impls/` counts; an alias nothing reaches through still counts once,
as `Impl.@import`, because the import is the edge. Every reference fails:
`tools/impls_boundary_baseline.txt` was deleted, and the tool refuses it if it
comes back. The `//! lint-impls: hook for <Owner>` line is documentation - it
names who installs the hook; the tool does not parse it. The generated layers
(interfaces, mixins, namespaces, codegen) are skipped: delegating to impls is
their job.

## lint-engine: the check of the engine boundary

The rule itself: [src/runtime/AGENTS.md](../src/runtime/AGENTS.md), "The engine boundary".

**Checked, and `zig build test` runs the check:**

```bash
zig build lint-engine -j2 --cache-dir ~/Library/Caches/crane-z16-cache               # fails on any new V8 reference outside the adapter
zig build lint-engine -j2 --cache-dir ~/Library/Caches/crane-z16-cache -- --update   # after paying debt down: record the lower baseline
```

`tools/lint_engine_boundary.zig` counts, per file AND per name, every import
whose path names V8, every `v8_*` identifier, and every member reached through
an alias of a V8 import (`v8.context_manager`, `v8.ffi.Isolate`), against
`tools/engine_boundary_baseline.txt`. A count that rises fails, and so does a
pair the baseline lacks - which catches a swap. The baseline only goes down;
when it reaches zero, "v8" leaves the non-adapter modules' imports in build.zig
and the module graph enforces the rule. Report the baseline's total in every
summary, beside blocking files and passing subtests. Why this rule exists:
[Crane's JavaScript engine is an adapter](../docs/lessons/architecture-the-javascript-engine-is-an-adapter.md);
why the seam is a protocol designed whole:
[Design the protocol before migrating](../docs/lessons/architecture-design-the-protocol-before-migrating.md).

## The other lints

- `zig build lint-global-state`: its rule, its inventory and `-- --update` / `-- --rename` are in [src/AGENTS.md](../src/AGENTS.md), "Global state", item 3.
- `zig build lint-platform`: [src/platform/AGENTS.md](../src/platform/AGENTS.md), "The platform boundary".
- `zig build lint-refcount`: [src/AGENTS.md](../src/AGENTS.md), "DOM lifetime: reference counting".
- The naming ratchet of `zig build lint-impls` (`tools/impls_naming_baseline.txt`): [src/webidl/AGENTS.md](../src/webidl/AGENTS.md), "Names are the binding map".
- `zig build lint-build` (tools/lint_build_neutral.zig): build.zig and the neutral `.zig` files it imports name no engine, no operating system or platform adapter and no platform library (the user, 2026-11-12) - what is an adapter's goes in the adapter's own build file, behind the build side of its protocol (src/runtime/engine_build_protocol.zig for an engine; src/platform/platform_build_protocol.zig for a platform, whose adapters declare their extra kit parts and system libraries in `adapters/<platform>/platform_build.zig` - lane life1, 2026-11-21). It counts the words build.zig passes it - four classes: `engine`, `platform`, `target` (a branch on the target's OS) and `library` - per file, per word and per kind of text (code, comment, a line of an embedded script: comments count), against `tools/build_neutral_baseline.txt`; test declarations are exempt, and the engine's own build files are not counted. A count that rises fails, and so does a line the baseline lacks. The baseline only goes down, a slice with each batch of the build migration (`-- --update`, which refuses an increase; `-- --list` prints every site), and is never edited by hand.
- `zig build lint-hasdecl` (tools/lint_hasdecl.zig, lane tpg 2026-11-22): Zig 0.17's `@hasDecl` is false for every declaration that is not `pub` - in the probe's own file too - so a generic's optional hook (`if (@hasDecl(T, "drop"))`) declared without `pub` is silently compiled out. The lint resolves each `@hasDecl` / `std.meta.hasFn` / `hasMethod` probe's container (scopes, `@import` of a file or a build.zig module, aliases, field chains, a generic's call sites, `inline for` over string literals) and FAILS, with no baseline, on a probed name declared only without `pub`: make it `pub`, or rename it when the probe was never meant to find it. A probe it cannot resolve (an `anytype`'s type) needs a `// hasdecl: <the types that reach it, and that they declare it pub>` line; the unannotated ones are a ratchet in `tools/hasdecl_baseline.txt` (`-- --update`; `-- --list` prints each with the private declarations of its name). Where a missing hook is a bug, not an option, `@compileError` on `!@hasDecl` instead of skipping it.
- `zig build lint-css` (tools/lint_css_boundaries.zig): the CSS module's two cold Typed OM entries (Q59, Q61) stay off the parsing/computation files. Not a ratchet: any breach fails. A boundary rule like these is a lint here, never a `comptime {}` block that @embedFile's and searches sources: such a block runs in every binary that reaches its file - these two were 20 s of single-threaded Sema per test binary (lane compiletime1).
- `zig build lint-page-allocator` (tools/lint_page_allocator.zig, lane leak3 2026-11-22): no `std.heap.page_allocator` (or `PageAllocator`) in src/ without a `// page-allocator: <why>` line directly above it - the page allocator maps whole pages for every allocation, so a small record or a per-call temporary on it costs a page, and on Linux a mapping ([lesson](../docs/lessons/architecture-std-heap-page-allocator-maps-a-page-per-allocation.md)). Use the owner's allocator, a stack buffer over it (`std.heap.BufferFirstAllocator`), or libc's where none is in reach, said at the site. Tokenizer-based: comments and strings are never flagged. src/webidl/codegen/ (the build-time generator) is not scanned. Not a ratchet: any unmarked use fails.
- `zig build check-configure-cache`: no configure poisons Zig 0.17's configure cache and no Run step copies the configure-time environment - a sub-build of `check-configure-environment` per flag set (none, `-Dtest-binaries=engine`, `-Dsanitize-thread`, `-Dverify-base=HEAD`, `-Dsystem-curl`) with `--cache-poison=disallowed`; nothing is compiled; part of the whole test run. What build.zig used to ask the machine at configure time, tools/build_probe.zig asks at make time (.claude/rules/build-and-toolchain.md, "The configuration is cached").
- `zig build check-suite-facts` (tools/configurations_agree.zig): what a test executable is told about the engine and the busy Browser is the same with and without -Dsanitize-thread; four configures of the build root, nothing built; part of the whole test run.

## Compile time: what to measure

- `zig build code-size -- <binary> [--base=<binary>]` (tools/code_size_report.zig) groups a binary's functions by generic family from its symbol table - every `V8Interface(X).MethodCallback(...).callback` is one family - with count and bytes: what LLVM emitted, so what LLVM Emit Object (about 60% of a test binary's compile) spent its time on. Pick compile-time targets from it, not from guesses.
- A table the compiler would compute (a sort, a reverse index, a `StaticStringMap.initComptime` of thousands of entries) is computed once by a build step whose output Zig caches, and embedded with `@embedFile` of an anonymous import (build.zig `addGeneratedTables`); its identity with the compile-time result is pinned by a test.

## Known debt — do not add to it

- API-named functions in mixin impls that nothing calls - recorded in
  `tools/impls_naming_baseline.txt`, which may only go down
- V8 references outside src/runtime/engines/v8/ - recorded in
  `tools/engine_boundary_baseline.txt`, which may only go down
- Process-global and threadlocal mutable state - recorded in
  `tools/global_state_baseline.txt`, which may only go down
- Non-Zig tools outside the WPT exception: `tools/update_impl_signatures.py`
- Untested and undocumented code exists

These are real and being paid down. Saying "zero tolerance" about them trains
you to skim.
