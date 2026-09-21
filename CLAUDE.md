# Agent Guidelines for Crane

## What Crane is

A web platform engine in Zig. ~1M lines, 6,300+ files. V8 for JavaScript via a
hand-written C++ FFI wrapper (`src/runtime/engines/v8/v8_wrapper.cpp`, ~9.8k
lines).

Subsystems in `src/`: browser, dom, html, css, selector, fetch, streams, xhr,
websocket, service_worker, storage, cookiestore, csp, trusted_types,
permissions, webdriver, intl (CLDR), url, encoding, mimesniff, infra, webidl,
file, fs, quirks, referrer_policy, urlpattern, console, hr_time, platform,
js_bindings.

The WebIDL surface is **generated** from 341 official IDL files into 1,263
interfaces, with 1,270 hand-written impls behind them.

Layout is a pluggable backend (`src/platform/layout_backend.zig`) — Crane is the
web platform, the host supplies pixels. It links for `aarch64-ios`.

Conformance is judged by WPT (`zig build wpt`), not by our own tests.

**Not everything has a spec.** V8 handle ownership, allocator lifetimes and
teardown order are engine concerns — read the code, not `specs/`.

---

## Know what kind of work you're doing

**Spec work** (a DOM method, a parser state machine, a WebIDL conversion):
load the complete algorithm section from `specs/` before writing. Never work
from grep fragments — every algorithm has edge cases that live in the
surrounding prose.

**Engine work** (V8 handle ownership, allocator lifetimes, teardown order, the
FFI boundary, build/codegen): there is no spec. Read the code, and prefer a
measurement over an assumption — `gc_bench`, `leaks --atExit`, the live-handle
counters. Guessing at ownership here has shipped use-after-frees twice.

---

## Doing a task

All tasks: failing test first, commit each logical unit, `tmp/` for scratch.

Then branch on type:

| Type | First move |
|------|-----------|
| **Spec** | Load the full algorithm from `specs/` |
| **Bug** | Reproduce with a test before touching code |
| **WPT** | Isolate one test, fix, uncomment all, re-verify |
| **Engine** | Measure before and after; regression-check with timers |

### Fixing a WPT failure

```bash
zig build wpt -- <path/to/test.html>
```

1. **Isolate.** Comment out every other test in the file, leaving only the
   failing one. Confirm it fails.
2. **Fix it.** Verify the isolated test passes.
3. **Uncomment everything.** Re-run the whole file. This is not optional —
   tests interact, and shared state shows up only here.
4. **Commit** fix + test together.

Isolated or custom tests live in `tests/wpt/crane/`.

### Regression protocol for handle-ownership changes

`zig build test` is **not** sufficient, and neither are DOM WPT files — they
missed two use-after-frees that shipped.

```bash
./zig-out/bin/wpt_runner html/webappapis/timers/ --parallel=3   # x3, count crashes
```

---

## Tests come first

Write the failing test first, then satisfy it. This is not optional (see global
CLAUDE.md).

Where that is awkward, do it anyway but adapt the form:

- **WPT failures**: isolate the one failing test first, confirm it fails, fix,
  then uncomment and re-run all. That *is* the red-green loop.
- **Leaks**: the failing "test" is a measurement — record the B/cycle or leak
  count *before* the fix, so the after-number means something.
- **Comptime predicates**: pin the default in a test before relying on it.

WPT is the bar: `zig build wpt -- <path>`. Unit tests use
`std.testing.allocator` always, so leaks fail the test. Realistic inputs, spec
edge cases.

Two kinds this codebase keeps needing:

1. **Memory.** `std.testing.allocator` does not see C++ allocations. For
   anything touching V8 handles or allocators, measure with `zig build gc-bench`
   and name leaks with `leaks --atExit -- <cmd>`.
2. **Comptime predicates** that gate handle ownership (`typeRetainsContext`,
   `argHandleIsCopied`) must have a test pinning their **default**, not just
   their known cases. See `tests/v8/retention_predicate_test.zig` — two
   use-after-frees shipped because the default was wrong.

---

## Memory

Three families, three tools:

| Family | Measure with |
|--------|--------------|
| Zig pools (arena, slab, gpa) | `std.testing.allocator`, `gc_bench` columns |
| C++ `Global<T>` handles | `leaks --atExit`, live-handle counters |
| V8's own heap | `v8_Isolate_GetHeapUsage` |

**A leak invisible to (1) is usually (2).** This migration fixed 635,764 leaked
handles while the suite was green throughout.

### Zig side

`defer` at the point of allocation, `errdefer` on error paths, thread the
allocator through the call chain, no global state.

**`ArenaAllocator.free` is a no-op.** An arena serving a hot path is a leak
until teardown, invisible to both `std.testing.allocator` and `mstats()`.

### The C++ seam — where the bugs are

The wrapper heap-allocates a `Global<T>` wherever V8 returns a borrowed
`Local<T>`. Every `v8_*` call returning a pointer allocates, and **the caller
owns it**. One wrong assumption here leaked in ~20 places at once, on the DOM's
hottest paths.

- Returned `*Context` / `*Object` / `*Value`: dispose it, or don't acquire it.
  **Prefer not acquiring** — moving acquisition past the early returns needs no
  proof about what the callee retains.
- Before disposing, **prove** the callee doesn't retain it. Two use-after-frees
  shipped from guessing.
- Gate any "safe to dispose" decision on an **allowlist** predicate whose
  default is the safe answer. Blocklists are wrong by default over an open set
  of types.

---

## Before every commit

```bash
zig fmt src/ tests/ tools/
PATH=/tmp/sdkshim:$PATH zig build      --cache-dir /tmp/crane-z16-cache
PATH=/tmp/sdkshim:$PATH zig build test --cache-dir /tmp/crane-z16-cache
```

`/tmp/sdkshim` is required and does **not** survive a reboot.

All three must pass. For changes to V8 handle ownership, they are not
sufficient — see the regression protocol above.

---

## WebIDL codegen

```
specs/idl/            341 official .idl files (symlink to webref)
specs/supplementary/  extra definitions
        |
        v             src/webidl/codegen/
        |
src/webidl/interfaces/    1,263  generated
src/webidl/typedefs/             generated
src/webidl/dictionaries/         generated
src/webidl/callbacks/            generated
src/webidl/impls/         1,270  HAND-WRITTEN, never overwritten
src/webidl/impls_tmp/            generated stubs, gitignored, NOT built
```

Generated files **are** committed. `impls/` is yours; codegen writes stubs to
`impls_tmp/` for you to diff and merge by hand.

### Never edit generated files directly

Fix the codegen in `src/webidl/codegen/` or the source IDL, then regenerate.

You *may* edit a generated file to test a fix, but the fix must then move into
the codegen and the temporary edit must be overwritten by a regeneration —
that is how you know the codegen actually produces it. Never commit a
hand-edited generated file.

Regenerate — **one source per invocation**:

```bash
zig build codegen -- specs/idl/           --dest-root src/webidl/
zig build codegen -- specs/supplementary/ --dest-root src/webidl/
```

Passing both sources to one invocation fails with `error.UnknownArgument`.

When codegen behaviour is in question, **delete the generated directories and
regenerate from scratch.** Partial regeneration hides systemic issues — that is
how a parent-vs-child signature bug stayed hidden behind 12 "unrelated" type
mismatches. Then `zig build` to confirm no interface/impl signature drift.

### New interfaces

1. Run codegen. 2. Copy the stub from `impls_tmp/X.zig` to `impls/X.zig`.
3. Implement it. 4. Commit the file in `impls/`.

When an IDL signature changes, diff `impls_tmp/X.zig` against `impls/X.zig` and
merge by hand, preserving your implementation.

---

## The impls boundary

Two directions, one rule: **impls are private.**

```
External code      ->  interfaces, never impls
Impl -> other type ->  interfaces, never impls
Impl -> itself     ->  fine
```

Interfaces are the stable API and may add CEReactions, validation and other
cross-cutting concerns. A direct impl call bypasses all of it.

When an impl needs internal state another type owns, move the algorithm *into*
that impl and add a delegate on its interface.

Check with:

```bash
zig build lint-impls
```

The count is whatever that prints — **do not write it down here.** The last
hardcoded figure said "53 files, 245 instances" and was 138/434 by the time
anyone checked.

---

## Golden rules

1. **Algorithm precision.** WHATWG specs define web platform behaviour.
   Implement exactly as specified, step by step, with numbered comments. Small
   deviations break browser compatibility.
2. **Browser compatibility.** Match real browser behaviour. When in doubt,
   check how Chrome, Firefox and Safari handle it.
3. **Performance matters**, but spec compliance comes first. Never sacrifice
   correctness for speed.
4. **Commit after every logical unit of work.** A feature, a fix, a passing
   test, a refactor — commit it. Do not accumulate changes.
5. **Handle dependencies correctly.** Check `src/` for the real implementation.
   If it doesn't exist, mock it with a clear `TODO` marker — never skip it.

---

## Generated files go in `tmp/`

Everything you generate that isn't source or a committed doc goes in `tmp/`
(gitignored):

```
tmp/summaries/   session summaries, reports
tmp/analysis/    investigation notes
tmp/plans/       design docs, decision logs
tmp/debug/       test output, traces
tmp/scratch/     everything else
```

Project root is for committed docs only (README, CHANGELOG, CONTRIBUTING). Put
something there only if the user explicitly asks for it.

**Background jobs**: use `$CLAUDE_JOB_DIR/tmp` instead — parallel jobs clobber
each other in `/tmp`.

---

## Non-negotiable

- Memory leaks, Zig or C++
- Committing a hand-edited generated file
- Calling impls across the boundary in **new** code
- Deviating from a spec algorithm without saying why
- Debug output in the hot path — `std.log.scoped`, never `std.debug.print`; no
  unguarded `fprintf` in `v8_wrapper.cpp`. A prototype-chain dump guarded only
  by `strcmp(name, "HTMLDivElement")` ran on every wrapped element and emitted
  500,000 stderr writes in one benchmark.
- Leaving temporary artifacts behind — worktrees, `/tmp` clones, build caches

## Known debt — do not add to it

- 434 impls-boundary violations (`zig build lint-impls`)
- Intermittently red suite: `tests/storage/backend_benchmark_test.zig` asserts
  absolute wall-clock (`avgNs() < 1_000_000`) and fails under load
- Untested and undocumented code exists

These are real and being paid down. Saying "zero tolerance" about them trains
you to skim.

---

## When in doubt

1. **Have you committed recently?** If you have working changes, commit them now.
2. **Creating files?** `tmp/`, unless asked otherwise.
3. **Which subsystem?** Check the file path and imports.
4. **Spec work?** Read the complete section from `specs/whatwg/[spec]/`.
5. **Engine work?** Read the code and measure.
6. **Check dependencies** in `src/` before mocking anything.
7. **Look at existing tests** for patterns in similar subsystems.

---

## WHATWG specifications

| Spec | URL | Local |
|------|-----|-------|
| URL | https://url.spec.whatwg.org/ | `specs/whatwg/url/` |
| Encoding | https://encoding.spec.whatwg.org/ | `specs/whatwg/encoding/` |
| Streams | https://streams.spec.whatwg.org/ | `specs/whatwg/streams/` |
| Infra | https://infra.spec.whatwg.org/ | `specs/whatwg/infra/` |
| WebIDL | https://webidl.spec.whatwg.org/ | `specs/whatwg/webidl/` |
| Console | https://console.spec.whatwg.org/ | `specs/whatwg/console/` |
| MIME Sniff | https://mimesniff.spec.whatwg.org/ | `specs/whatwg/mimesniff/` |
| Fetch | https://fetch.spec.whatwg.org/ | `specs/whatwg/fetch/` |
| DOM | https://dom.spec.whatwg.org/ | `specs/whatwg/dom/` |
| HTML | https://html.spec.whatwg.org/ | `specs/whatwg/html/` |

Specs reference each other constantly. Most depend on **Infra**; anything with
a Web API depends on **WebIDL**.

---

## ⚠️ Expand this file when you learn

When you learn something new or find a better way to do something, you **must**
update this file.

Add a lesson when you: discover a bug pattern that could recur, find a better
approach to a common task, learn from user feedback about correct methodology,
identify a systemic issue rather than a one-off, or establish a new best
practice.

```markdown
### Category: Brief Lesson Title

**Date**: YYYY-MM-DD
**Lesson**: One-sentence summary.

**Why**: The underlying issue.

**What Happened**: Context, what went wrong, how it manifested.

**Fix**: Step-by-step, with code if relevant.

**Takeaway**: **Bold key insight** for future work.
```

Categories: Codegen, Debugging, Architecture, Testing, Workflow, Spec Compliance.

---

## Lessons Learned

### Architecture: Local vs Global at the FFI seam

**Date**: 2026-09-21
**Lesson**: The C++ wrapper allocates a `Global<T>` wherever V8 lends a `Local<T>`.

**Why**: V8's API returns borrowed handles scoped to a `HandleScope`. Crossing
into Zig needs something that outlives the scope, so the wrapper heap-allocates
— and ownership transfers to the caller, silently.

**What Happened**: One unstated convention produced identical leaks in ~20
unrelated places at once: `GetCurrentContext` (2 per element),
`GetArgument` (1 per element), and the `[Global]` getter path. 635,764 leaked
handles per 200,000 cycles, on the DOM's hottest paths, with a green test suite.

**Fix**: `leaks --atExit -- <cmd>` named all three in one run. Dispose what you
acquire, or restructure so you never acquire it.

**Takeaway**: **Every `v8_*` call returning a pointer allocates. The caller owns it.**

---

### Architecture: Allowlist, never blocklist, for ownership predicates

**Date**: 2026-09-21
**Lesson**: A predicate deciding whether a handle may be released must default to "no".

**What Happened**: Written as a blocklist twice — "retains unless it's an
Instance pointer", then "retains only for `*runtime.CallbackWrapper`" — and
twice an unlisted type slipped through into a use-after-free. 2–3 crashes per
timers run the first time; 10 of 12 files the second, because `setTimeout`'s
handler is `typedefs.TimerHandler`, a union whose `function` arm is a callback.

**Fix**: `typeRetainsContext` and `argHandleIsCopied` are allowlists of provably
inert types. Unrecognised types get the conservative answer, which costs memory
and never correctness. Both have tests pinning the default.

**Takeaway**: **A blocklist over an open set of types is wrong by default —
every type nobody thought of falls on the dangerous side.**

---

### Testing: Regression-check handle changes with timers, not DOM

**Date**: 2026-09-21
**Lesson**: DOM WPT files do not catch V8 handle-ownership breakage.

**What Happened**: Two crashing regressions passed 12 DOM files and were caught
only by `html/webappapis/timers/ --parallel=3`. Timers exercise callback
retention across turns of the event loop; DOM property access does not.

**Fix**: Run timers three times and count crashes. The baseline floor is 0–1
per run.

**Takeaway**: **Pick the regression suite that exercises the lifetime you
changed, not the one that touches the same file.**

---

### Debugging: An instrument can confound its own result

**Date**: 2026-09-21
**Lesson**: `gc_bench` forced a GC once per batch, and the batch *was* the sample interval.

**What Happened**: Asking for fewer report rows meant asking for fewer
collections. The same build doing the same work reported 756 B/element at
`300000 200000` and 476 at `300000 25000` — a 1.6x spread that was pure print
frequency. Two figures minutes apart looked like a regression and were an
artefact.

**Fix**: Batch pinned at 5,000 cycles, sampling independent of it. Verified by
two granularities agreeing to the byte.

**Takeaway**: **Keep the perturbation independent of the reporting cadence, and
prefer a slope between adjacent samples over any per-unit average.**

---

### Debugging: `leaks --atExit` is the tool; attaching never works

**Date**: 2026-09-21
**Lesson**: Use `leaks --atExit -- <cmd>`, not `leaks <pid>`.

**What Happened**: `gc_bench` runs 500,000 cycles in ~15s, so both `leaks <pid>`
and `heap <pid>` lose the race to attach. Worse, `MallocStackLogging=1` panicked
with "incorrect alignment" — which looked like a tool problem and was actually a
teardown bug (an undefined `DebugAllocator` deinitialised in
`deinitIsolateAllocator`). Most of a phase was spent inferring what one command
would have named.

**Fix**: Fix teardown first, then `leaks --atExit`. Tally by entry point and
divide by cycle count — a clean `1.00/cycle` points straight at the call site.
To prove a residual is startup cost rather than a leak, compare two cycle
counts: 100k vs 400k differing by <3 KB is ~0 B/cycle.

**Takeaway**: **If a memory tool looks broken, suspect your own teardown before
the tool.**
