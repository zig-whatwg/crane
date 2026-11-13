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

`zig build test` runs `lint-impls`, the impls-boundary ratchet (see "The impls
boundary"), so it fails on any new reference into an impl from code that does
not own it.

**Checked by `zig build lint-impls`** (part of `zig build test`), counting ancestors since 1a94e0043:

```bash
zig build lint-impls -j2 --cache-dir ~/Library/Caches/crane-z16-cache                # fails on any new reference into an impl
zig build lint-impls -j2 --cache-dir ~/Library/Caches/crane-z16-cache -- --update    # after paying debt down: record the lower baseline
```

`tools/lint_impls_boundary.zig` counts references into impls per file AND per
`Impl.member` against `tools/impls_boundary_baseline.txt`. Each use counts once,
however many times its alias is declared in the file; src/ (outside the
generated layers), tests/ and tools/ are scanned, and a file that imports
`impls` but reaches nothing in it counts one `impls.@import`, because the
module-graph step drops that edge too. `-- --list` prints every site as
`path:line Impl.member`: the work list for a conversion batch. A count that
rises fails; so does a pair the baseline lacks - which catches a swap. The
`//! lint-impls: hook for <Owner>` line is documentation - it names who installs
the hook; the tool does not parse it (its in-hierarchy hook check went with the
ancestor exception, 1a94e0043). The
generated layers (interfaces, mixins, namespaces, codegen) are skipped:
delegating to impls is their job. `--rebase-for-rule-change` exists for one purpose: re-recording the
baseline when the RULE changes (it was used once, when ancestors started to count); a code change
never uses it.

**The baseline must reach zero before Crane 0.1** (the user, 2026-10-10; roadmap item `impls-boundary`).

The baseline only goes down. `--update` refuses to record an increase, and
editing the file by hand to make the check pass defeats the only thing that
stops this debt growing. The count is whatever the baseline says - **do not
write it down here.**

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
- `zig build lint-build` (tools/lint_build_neutral.zig): build.zig and the neutral `.zig` files it imports name no engine, no operating system or platform adapter and no platform library (the user, 2026-11-12) - what is an adapter's goes in the adapter's own build file, behind the build side of its protocol (src/runtime/engine_build_protocol.zig). It counts the words build.zig passes it - four classes: `engine`, `platform`, `target` (a branch on the target's OS) and `library` - per file, per word and per kind of text (code, comment, a line of an embedded script: comments count), against `tools/build_neutral_baseline.txt`; test declarations are exempt, and the engine's own build files are not counted. A count that rises fails, and so does a line the baseline lacks. The baseline only goes down, a slice with each batch of the build migration (`-- --update`, which refuses an increase; `-- --list` prints every site), and is never edited by hand.
- `zig build lint-css` (tools/lint_css_boundaries.zig): the CSS module's two cold Typed OM entries (Q59, Q61) stay off the parsing/computation files. Not a ratchet: any breach fails. A boundary rule like these is a lint here, never a `comptime {}` block that @embedFile's and searches sources: such a block runs in every binary that reaches its file - these two were 20 s of single-threaded Sema per test binary (lane compiletime1).
- `zig build check-suite-facts` (tools/configurations_agree.zig): what a test executable is told about the engine and the busy Browser is the same with and without -Dsanitize-thread; four configures of the build root, nothing built; part of the whole test run.

## Compile time: what to measure

- `zig build code-size -- <binary> [--base=<binary>]` (tools/code_size_report.zig) groups a binary's functions by generic family from its symbol table - every `V8Interface(X).MethodCallback(...).callback` is one family - with count and bytes: what LLVM emitted, so what LLVM Emit Object (about 60% of a test binary's compile) spent its time on. Pick compile-time targets from it, not from guesses.
- A table the compiler would compute (a sort, a reverse index, a `StaticStringMap.initComptime` of thousands of entries) is computed once by a build step whose output Zig caches, and embedded with `@embedFile` of an anonymous import (build.zig `addGeneratedTables`); its identity with the compile-time result is pinned by a test.

## Known debt — do not add to it

- References into impls from anywhere but their own generated interface -
  recorded in `tools/impls_boundary_baseline.txt`, which may only go down
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
