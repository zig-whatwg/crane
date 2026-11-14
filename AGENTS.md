<!-- Keep this file under 200 lines: rules here, details in the files the index names. -->
# Agent Guidelines for Crane

## What Crane is

**The goal is web spec conformance, not compatibility with any one framework.**
Crane is a general-purpose browser engine: the target is everything a headless
browser engine can run, with rendering and layout the single deliberate
exclusion. A framework's test suite - React's, or anything else's - is a way to
VERIFY that, never a way to scope it.

- "Framework X does not use this" is never a reason to leave something out, nor to stop halfway through an algorithm: implement what the spec says and let WPT, the judge of conformance, report the gap.
- Where the spec text and the browsers disagree, golden rule 2 decides: the browsers win, unless they are only behind a newer spec.
- **Stuck on HOW to implement something?** Read how V8, WebKit, Blink or Gecko did it BEFORE designing a mechanism, and cite it in the commit; take the design, never the code.
- **No invented paths** (the user, 2026-11-04): every behaviour follows the spec and what browsers do, and reaches the engine through the paths a browser has. That holds for hosts and the repl too: the repl IS the headless browser, so it reaches pages only through a browser's algorithms (browser-UI navigation, traversal, window.open), never a host-only shortcut. A host- or console-only path is a defect to remove, not a place to patch; a fix that keeps a copy in sync instead of reading the spec's source is not a fix.

**Not everything has a spec.** V8 handle ownership, allocator lifetimes and
teardown order are engine concerns — read the code, not `specs/`.

## Golden rules

1. **Algorithm precision.** WHATWG specs define web platform behaviour.
   Implement exactly as specified, step by step, with numbered comments. Small
   deviations break browser compatibility. Where the browsers do otherwise,
   rule 2 wins.
2. **Browsers decide - unless they are only behind the spec.** Where the
   browsers and the spec text disagree, find out WHY before choosing (the
   user, 2026-10-08, refined 2026-10-17):
   - **The spec was updated and at least one of Chrome, Firefox and Safari
     ships the newer behaviour:** implement the NEWER spec, even when the
     other two do not ("if one implements but two don't then we implement").
   - **The spec was updated and none of the three ships it yet, because they
     have not caught up:** implement the NEWER spec. Evidence of a lag: the
     change was merged with implementer support (WHATWG PRs list an
     implementation bug per engine), those engine bugs are open, not WontFix,
     and WPT was updated to the new behaviour.
   - **The spec was updated and ALL THREE have intentionally not implemented
     it:** do what the browsers do. This needs all three aligned, each with
     evidence of intent - a negative or deferred standards position
     (mozilla/standards-positions, WebKit/standards-positions), a WontFix
     engine bug, an implementer's objection on the spec PR or issue. One
     browser declining while another merely lags is not alignment: implement
     the newer spec.
   - **No newer spec is involved** - the browsers simply differ from the
     spec text: do what the browsers do. Where they split, follow the
     majority of Chrome, Firefox and Safari and say so. With no majority -
     all three differ - compare them mechanism by mechanism: if each
     mechanism has a majority AND those majorities together are one shipping
     browser's behaviour, do that; otherwise follow the spec (the user,
     2026-10-17; lesson
     spec-compliance-a-fatal-decode-drops-input-not-handler-state.md). Ask the
     integrator only when even that leaves the choice open.

   Whichever you choose, state it in a comment citing the evidence: the
   wpt.fyi results (Chrome, Firefox, Safari), the engine code, the spec
   change and its implementation bugs, the standards positions. A browser
   that does not ship the feature at all does not count toward a majority.
   Not a licence to skip spec work: where they agree with the spec, the
   spec's steps are the implementation.
3. **Performance matters**, but spec compliance comes first. Never sacrifice
   correctness for speed.
4. **Commit after every logical unit of work.** A feature, a fix, a passing
   test, a refactor — commit it. Do not accumulate changes.
5. **Handle dependencies correctly.** Check `src/` for the real implementation.
   If it doesn't exist, mock it with a clear `TODO` marker — never skip it.

## Doing a task

All tasks: failing test first, commit each logical unit, `tmp/` for scratch.

Then branch on type:

| Type | First move |
|------|-----------|
| **Spec** | Load the full algorithm from `specs/` |
| **Bug** | Reproduce with a test before touching code |
| **WPT** | Isolate one test, fix, uncomment all, re-verify |
| **Engine** | Measure before and after; regression-check with timers |

- **Spec work:** load the complete algorithm section from `specs/` before writing, never grep fragments; a spec not in `specs/` is fetched (`specs/get`) as its own commit, and one cached six months or more is compared with upstream first; `specs/idl/` is a pinned webref snapshot, updated only by the procedure in specs/idl/WEBREF.md (specs/AGENTS.md).
- **Engine work** (handle ownership, allocator lifetimes, teardown order, the FFI, build/codegen): there is no spec - read the code, and prefer a measurement (`gc_bench`, `leaks --atExit`, the live-handle counters) over an assumption.
- **Batch the expensive gates** (the user, 2026-11-01): each change still gets its own cheap red/green proof; changes whose files and WPT directories do not overlap share one native gate, one runner build and one A/B; before starting any gate or run over 20 minutes, batch in what else is about to land; merge current main into your branch before you report (docs/agents/working-on-crane.md).
- **Handle-ownership changes:** `zig build test` and the DOM WPT files are not sufficient - run the regression protocol (timers x3), and call a sweep-only crash fixed only when same-list counts say so (tests/AGENTS.md).
- Everything you generate that is not source or a committed doc goes in `tmp/`; background jobs use `$CLAUDE_JOB_DIR/tmp`; the project root holds committed docs only.

## Tests come first, in short

- Write the failing test first, then satisfy it; where that is awkward, adapt its form: a WPT failure's isolated test, a leak's count recorded before the fix, a test pinning a comptime predicate's default (tests/AGENTS.md).
- Unit tests use `std.testing.allocator` always, with realistic inputs and spec edge cases; it does not see C++ allocations, so measure those with `zig build gc-bench` and name leaks with `leaks --atExit`.
- A test directory is one executable, run by `tools/test_launcher` in seeded, shuffled batches: a test may assume only what the process start makes, and leaves the process as it found it; a race test between Browsers gives each Browser its own leak-checking `DebugAllocator`.

## Before every commit

```bash
zig fmt src/ tests/ tools/
zig build wpt-runner -j2 --cache-dir ~/Library/Caches/crane-z16-cache   # the one artifact WPT needs
zig build test       -j2 --cache-dir ~/Library/Caches/crane-z16-cache   # includes lint-impls
```

- `zig build test` also runs `crane-check`, `codegen-check` and the lints - lint-impls, lint-engine, lint-global-state, lint-platform, lint-refcount, lint-build - each a ratchet whose baseline only goes down (tools/AGENTS.md).
- **Verify mode:** a branch that adds or changes tests also passes `zig build test-verify` (plain and with `-Dsanitize-thread`) and `wpt_runner --repeat=10 --verify`, and its merge report quotes both (tests/AGENTS.md, "Verify mode").

All three must pass. For changes to V8 handle ownership, they are not
sufficient — see the regression protocol above.

## Building

- **Never run a bare `zig build`, and always pass `-j2`:** every artifact that embeds the tree is a ~6 GB root compile; on a shared machine run `./zig-out/bin/wpt_runner` directly (.claude/rules/build-and-toolchain.md).
- **Lane agents compile nothing on this Mac** (the user, 2026-10-29): every `zig build`, test run and benchmark goes through `crane-remote.sh` or `crane-pool.sh`; on the Mac a lane edits, reads, runs git and `zig fmt`.
- **Local builds use `--cache-dir ~/Library/Caches/crane-z16-cache`, never a cache in `/tmp`;** `zig build codegen` and `codegen-check` use a cache of your own (`~/Library/Caches/crane-<lane>-codegen`, deleted when you are done).
- **The toolchain is Zig 0.17, pinned** (the user, 2026-10-28): `0.17.1-dev+77c319a0f0`; `zig build` takes no `--global-cache-dir`, the global cache is set only through `ZIG_GLOBAL_CACHE_DIR`; anything `build.zig` reads from the machine at configure time calls `b.graph.poisonCache()`; never put an `xcrun` shim on PATH.
- **The production WPT runner is the release console's build** (ReleaseSafe throughout, libc malloc, the console's platform graph: the user, 2026-11-09), about 12 minutes cold; the bug-finding runner is ReleaseSafe with Crane's modules in Debug (the user, 2026-10-11), `-Dwpt-runner-optimize=Debug` for a diagnosis; an A/B compares runners built in the same mode as its baseline (.claude/rules/wpt-workflow.md).

## Boundaries

- **Impls:** an interface's impl is reached ONLY through that interface's own generated file - no other impl, not an ancestor's, and no other code names an `XImpl` or imports `impls`; a step with no IDL member goes through a `src/dom` hook its owner installs; shared helpers live outside `src/webidl/impls/`; never cast another type's `_internal` to its `InternalState` (src/webidl/AGENTS.md, "The impls boundary").
- **Names are the binding map:** in an impl, `get_`/`set_`/`call_` mean "exposed to script" and nothing else, and a mixin's member is implemented once, in the mixin's impl; a private function never takes one of those prefixes (src/webidl/AGENTS.md).
- **Never edit generated files** (`src/webidl/{interfaces,typedefs,dictionaries,callbacks,mixins,namespaces,enums}/`, the directories `codegen-check` compares): fix the codegen or the IDL and regenerate with `zig build codegen -- --dest-root src/webidl/`, one invocation over both sources (src/webidl/AGENTS.md, "WebIDL codegen").
- **Engine:** V8 types and calls live only in `src/runtime/engines/v8/` and `tests/v8/`; everything else calls the `engine` protocol, and a new engine need is a new protocol operation, requested from the integrator; ownership is in the types - a `JSValue` parameter is borrowed, what the caller must release has an owning type (src/runtime/AGENTS.md, "The engine boundary").
- **Platform:** no new OS access outside `src/platform/` (files, clocks, network, threads, process, getenv, randomness, curl, sqlite, mbedtls); everything platform-specific goes through the `platform` protocol (src/platform/AGENTS.md).
- **Global state:** no new `threadlocal` and no new container-level `var`; state has an owner - the process, a Browser, a Tab, an agent or a realm - and a hook is installed once, at process start; a reviewed exception carries its `// process-wide:` or `// per-thread:` line (src/AGENTS.md, "Global state").
- **DOM lifetime:** an object that keeps a node for script holds it through `src/dom/node_holds.zig` or a traced edge, never a bare pointer; collected trees are freed in slices from the event loop, never inside the collector; no direct `.parent_node =` write outside NodeBase's setter (src/AGENTS.md).
- **Memory:** `defer` at the allocation, `errdefer` on error paths; every `v8_*` call returning a pointer allocates and the caller owns it - prefer not acquiring it, and prove the callee does not retain it before disposing it; a "safe to dispose" gate is an allowlist whose default is the safe answer; `ArenaAllocator.free` is a no-op (src/AGENTS.md, "Memory").
- **Tools are Zig:** anything committed to `tools/` or run by `build.zig` is Zig, tested with `std.testing`; only the existing WPT tools are exempt (tools/AGENTS.md).
- **Known debt only goes down:** the baselines in `tools/` never rise, and a change that touches an impl reference or a direct V8 call converts it; a baseline is never edited by hand, and the impls baseline reaches zero before Crane 0.1 (tools/AGENTS.md).
- **Upstream WPT:** never edit a test in `tests/wpt/` outside `crane/` to make it pass; Crane's own tests live in `tests/wpt/crane/`.

## WPT and the 0.1 gate

- **The 0.1 gate: no file in the worklist blocks.** A file blocks when it times out, errors or crashes, or finishes OK with none of its subtests passing; a file only ALL THREE browsers intentionally deviate on is exempt, and so is a file that fails identically in all three because of a test bug filed upstream, until that bug is resolved (the user, 2026-11-08), and a file whose every failure is geometry no renderer answers yet (`needs-renderer`, the user, 2026-11-09: it still runs and shows on the site, and stops being exempt when a renderer exists); each is listed with its evidence in `tools/wpt_gate_exemptions.txt`.
- Fixing a file: isolate the one failing test, fix it, then uncomment everything and re-run the whole file; commit the fix and its test together (.claude/rules/wpt-workflow.md).
- Only main's runs go where the report reads them (`wpt-results/<label>/`, one directory deep), a lane's to `wpt-results/lanes/<label>/`.
- After a feature commit, regenerate (`zig build wpt-progress`; push `gh-pages` with main) and keep `docs/roadmap.toml` current; once per working session, a full worklist sweep at HEAD from a frozen runner, with its `journal.wptreport.jsonl`.
- Every summary reports the headline - blocking files and passing subtests, the rate outside `encoding/` and the mean per-file rate - beside the engine-boundary baseline total and the global-state total with its `by rule:` line.
- **WPT runs Crane only in its production configuration** (the user, 2026-11-09: "I want our WPT to only ever run Crane with the exact same configuration and memory setup that Crane would have running in a production environment. We should never special case something" - "architect ours like the way browsers do it"): two builds of one tree. The PRODUCTION run, `wpt_runner` (`zig build wpt-runner`), is the release console's build and platform graph exactly, and it alone feeds generations, the site, A/B pass counts and every timing. The BUG-FINDING run, `wpt_runner_bug_finding`, adds detection only (debug allocator, poison-on-free, Debug checks, the full C sanitizer). It is never published or timed; its gate is no crash, poison read, leak or assertion, and any subtest that differs between the two runs is a bug, listed with an owner in `tools/wpt_build_differences.txt`, which only goes down (.claude/rules/wpt-workflow.md).

## Clean up as you go, not at the end

Delete each temporary artifact **as soon as it stops being useful**, not when
the task finishes. "I'll tidy up at the end" means it is still there at the end,
because the end is where context runs out and sessions get interrupted.

- Before reporting a task complete, verify rather than claim: `git worktree list`, `pgrep -fl 'gc_bench|wpt_runner|zig build'`, `du -sh /tmp/* 2>/dev/null | sort -h | tail -5`; kill the servers and background jobs you started in the step that stops needing them (docs/agents/working-on-crane.md).

## Non-negotiable

- Memory leaks, Zig or C++
- Committing a hand-edited generated file
- Referencing an impl from anywhere but its own generated interface, in **new**
  code - ancestors included; `zig build lint-impls` (part of `zig build test`)
  enforces it
- V8 outside the V8 adapter in **new** code - `zig build lint-engine` (part of
  `zig build test`) enforces it; see "The engine boundary"
- A new `threadlocal` or container-level `var` - `zig build lint-global-state`
  (part of `zig build test`) enforces it; see "Global state"
- A `get_`/`set_`/`call_` name on a function the generated code does not bind -
  see "Names are the binding map"; `zig build lint-impls` enforces it
- A new tool written in anything but Zig (the existing WPT tools excepted) -
  see "Tools are Zig"
- Deviating from a spec algorithm without saying why
- Debug output in the hot path — `std.log.scoped`, never `std.debug.print`; no
  unguarded `fprintf` in `v8_wrapper.cpp`. A prototype-chain dump guarded only
  by `strcmp(name, "HTMLDivElement")` ran on every wrapped element and emitted
  500,000 stderr writes in one benchmark.
- Leaving temporary artifacts behind, or deferring cleanup to the end of a task
  — see "Clean up as you go"

## ⚠️ Record what you learn

- When you learn something that could recur - a bug pattern, a better approach to a common task, user feedback on method, a systemic issue, a new best practice - you **must** record it as a lesson: a file in `docs/lessons/` and one line in its index, committed with the work that taught it (the format: docs/lessons/AGENTS.md).

Keep this file a rulebook. When a lesson becomes a rule, write the rule in its
section above and keep the lesson as the reason. When a lesson is superseded,
update its file with a dated **Status** line rather than leaving advice that
contradicts current practice.

## Lessons index

The index - one line per lesson, its title and takeaway - is
[docs/lessons/README.md](docs/lessons/README.md). It is kept out of this file
because every agent re-reads this file on every call.

- Starting a batch, read the lessons your brief names before you design anything; stuck on a symptom, grep `docs/lessons/` before theorising.

## Index: before you work in X, read Y

Every section moved out of this file kept its heading there: a comment citing `AGENTS.md "<heading>"` means the file this table lists it under. The two `.claude/rules/` files load by themselves only in Claude Code, for their paths; Codex, and a Bash read, open them from here.

| Before you work in | Read | Its sections (headings, and the bold leads comments cite) |
|---|---|---|
| any file under `src/` | [src/AGENTS.md](src/AGENTS.md) | Global state; DOM lifetime: reference counting; Memory (Zig side; The C++ seam — where the bugs are) |
| `src/webidl/`, codegen, an impl, code that reaches another type | [src/webidl/AGENTS.md](src/webidl/AGENTS.md) | WebIDL codegen; Never edit generated files directly; New interfaces; Names are the binding map; The impls boundary |
| the JavaScript engine, `src/runtime/`, `tests/v8/` | [src/runtime/AGENTS.md](src/runtime/AGENTS.md) | The engine boundary (rules 1-8) |
| `src/platform/`, anything that touches the OS | [src/platform/AGENTS.md](src/platform/AGENTS.md) | The platform boundary |
| `tests/`, a test, the launcher | [tests/AGENTS.md](tests/AGENTS.md) | Tests come first (A test directory is one executable; Seeds; Shapes; Two variants; Two kinds: Memory, Comptime predicates); Regression protocol for handle-ownership changes; Verify mode |
| `tools/`, a lint, a baseline | [tools/AGENTS.md](tools/AGENTS.md) | Tools are Zig; lint-impls; lint-engine; The other lints; Known debt — do not add to it |
| a spec, `specs/` | [specs/AGENTS.md](specs/AGENTS.md) | Know what kind of work you're doing (Spec work; Specs are cached in `specs/`); WHATWG specifications |
| WPT: a failure, a run, the report, the runner | [.claude/rules/wpt-workflow.md](.claude/rules/wpt-workflow.md) | Fixing a WPT failure; Keep the progress report current (The 0.1 gate; Keep the roadmap current); The two runs: production and bug-finding; The runner's build modes |
| `build.zig`, caches, `-j`, the toolchain | [.claude/rules/build-and-toolchain.md](.claude/rules/build-and-toolchain.md) | `crane-check` and the merge check; Local builds use `--cache-dir`; Never run a bare `zig build`; The toolchain is Zig 0.17 |
| a lesson: using or writing one | [docs/lessons/AGENTS.md](docs/lessons/AGENTS.md) | Record what you learn: the format; Lessons index: using them |
| how to work here | [docs/agents/working-on-crane.md](docs/agents/working-on-crane.md) | What Crane is: the details (Stuck on HOW); Engine work; Batch the expensive gates; Generated files go in `tmp/`; Clean up as you go: the details; When in doubt |
