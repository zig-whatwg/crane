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

**The goal is web spec conformance, not compatibility with any one framework.**
Crane is a general-purpose browser engine: the target is everything a headless
browser engine can run, with rendering and layout the single deliberate
exclusion. A framework's test suite - React's, or anything else's - is a way to
VERIFY that, never a way to scope it.

So **"framework X does not use this" is not a reason to leave something out**,
and neither is it a reason to stop halfway through an algorithm. That criterion
was used by mistake early in this work and produced two real defects: an
`addEventListener` options flatten that handled only the boolean form because
"React passes booleans", which made `addEventListener(t, fn, 2.3)` register as
a bubble listener when the spec says capture; and `navigation-api/` excluded
from the WPT worklist on the grounds that React and Phoenix do not need it.
When in doubt, implement what the spec says and let WPT report the gap.

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
zig build      --cache-dir /tmp/crane-z16-cache
zig build test --cache-dir /tmp/crane-z16-cache
```

**Do NOT put `/tmp/sdkshim` on PATH.** It was required until the machine
upgraded to macOS 27 on 2026-09-21. `MacOSX15.sdk` no longer exists, Zig's own
SDK detection now works, and recreating the shim pointed at `MacOSX27.0.sdk`
breaks the build outright:

    use of undeclared identifier 'INFINITY'
      zig/0.16.0/lib/libcxx/include/__random/clamp_to_integral.h:47
    error: sub-compilation of libcxx failed

The identical build with no shim on PATH has no libcxx error at all. The old
platform-aware shim is parked at `/tmp/sdkshim.disabled-2026-09-21` in case an
iOS build ever needs its `--sdk` handling back.

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

## Clean up as you go, not at the end

Delete each temporary artifact **as soon as it stops being useful**, not when
the task finishes. "I'll tidy up at the end" means it is still there at the end,
because the end is where context runs out and sessions get interrupted.

Applies to: build caches, `/tmp` clones and scratch directories, git worktrees
and their branches, crash dumps, throwaway databases, captured logs and profiler
output, and anything under `tmp/` you have finished reading.

Concretely, while working:

- **Finished with a measurement?** Delete the logs it produced. A `leaks` or
  `heap` dump is worth keeping until you have extracted the number, and worthless
  after.
- **Switched approach?** The artifacts of the abandoned one go now.
- **Spawned load generators, servers or background jobs?** Kill them in the same
  step that stops needing them, and verify with `pgrep` rather than assuming.
- **Long session?** Check disk periodically — `df -h /` and
  `du -sh /tmp/* 2>/dev/null | sort -h | tail -5`. Do not wait to be surprised.

Build caches are the big one. `/tmp/crane-z16-cache` reached **31 GB** in a
single session; deleting it returned 398 GB free to 429 GB. It is worth keeping
while you are still building and worth deleting the moment you are not — a cold
rebuild is ~10 minutes, since V8 itself is prebuilt.

Keep `/tmp/sdkshim` — it is 4 KB, every build needs it, and it does not survive
a reboot.

Before reporting a task complete, verify rather than claim:

```bash
git worktree list          # only the checkout you expect
pgrep -fl 'gc_bench|wpt_runner|zig build'   # nothing of yours running
du -sh /tmp/* 2>/dev/null | sort -h | tail -5
```

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
- Leaving temporary artifacts behind, or deferring cleanup to the end of a task
  — see "Clean up as you go"

## Known debt — do not add to it

- 434 impls-boundary violations (`zig build lint-impls`)
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

### Architecture: InstanceRegistry.createIn destabilises the DOM

**Date**: 2026-09-21
**Lesson**: Per-instance state taken from the shared arena and returned on `remove` gets reissued under a live reader.

**Why**: `utils.InstanceRegistry` keys on `@intFromPtr(instance)`, and the slab
RECYCLES instance addresses. `createIn` takes a block from the process-wide
`ArenaAllocator`; `remove` returns it to a size-classed free list, from which
the next same-sized request takes it. Anything still holding a `*T` obtained
from `Registry.get()` across that point now writes into a different element's
state.

**What Happened**: Measured in a control worktree at one HEAD, 8 single-process
runs per column, only the state mechanism differing:

    textarea reverted to stubs               0 / 8 aborted
    state via InstanceRegistry.createIn    1-7 / 8 aborted
    same, registry allocation removed        0 / 8 aborted
    state in a by-value map                  0 / 8 aborted

The abort is SIGABRT from a SEGV in `Node.getFirstChild`, reading a corrupted
`node_base` **in a later test file** - so it does not reproduce on the file that
caused it. Which new code was present barely mattered; removing the arena block
fixed it in all four batches.

`gc_bench` has been printing the same hazard all along: *"instance->NodeBase
entries: 1 (keyed on a RECYCLED address, so a stale entry is inherited by the
next object there)"*.

**Fix**: `HTMLOptionElement.zig` and `HTMLTextAreaElement.zig` keep state BY
VALUE in a small `page_allocator` map, created lazily on first assignment - a
stale key then gives a wrong answer instead of corrupting a neighbour, and an
element script never touches allocates nothing.

**This is a workaround.** `HTMLInputElement.zig`, `HTMLFormElement.zig` and ~17
other impls still use `createIn`. `the-input-element/` measured 0 aborts in 4
runs, so do not churn them speculatively - find whoever holds a block past
`ArenaAllocator.destroy` first.

**Takeaway**: **A recycled address plus a recycled block is two aliasing bugs,
not one.** Keying on an address the allocator reuses is survivable; handing out
a pointer into memory the arena will reissue is not.

---

### Architecture: A module cannot be test-linked if it is its own dependency

**Date**: 2026-09-21
**Lesson**: `zig test` collects test blocks from the ROOT module only, and a module that is its own transitive dependency cannot be cloned into a test root.

**Why**: Two separate walls, both measured rather than guessed:

* **Cloning it** (same root file, own link objects) fails when the module
  appears twice in one compile. `build.zig:1850` does
  `impls_mod.addImport("html", html_mod)`, so `html_mod` depends on itself
  transitively and the command line carries both `-Mroot=src/html/full.zig` and
  `-Mhtml=src/html/full.zig`:
  `error: file exists in modules 'root' and 'html'`.
* **Linking V8 into it in place** produces **844** `duplicate symbol definition`
  errors, because a module's link objects belong to every artifact downstream of
  it, and four of them already compile `v8_wrapper.cpp`.
* A generated root doing `_ = @import("html")` does not help either: test blocks
  are collected from the root module only, never from an imported one.

**What Happened**: `src/html/`'s module-root test target has no V8 link. It is
GREEN today and stays green only while Zig's lazy analysis never walks from an
`src/html/` test block into a `v8_*` extern. The same latency applies to
`dom_mod`, `intl_mod` and `platform_mod`.

**Fix**: Either break the cycle - have `src/webidl/impls/**` reach HTML through
`html_core`, as it already does for DOMParser, innerHTML and Window - or keep
every V8-reaching HTML test under `tests/html/`, which IS V8-linked.

**Takeaway**: **"It has no V8 link" and "it is red" are different states.** The
gap is latent until something references across it - the same shape as the
re-export lesson above.

---

### Architecture: An impl's return value is the JS return value, verbatim

**Date**: 2026-09-21
**Lesson**: There is no marshalling layer between an impl and JavaScript. Whatever the impl returns is what script sees.

**Why**: `convertReturnValue` maps `JSValue.undefined` to `v8_Undefined` and
stops. Nothing wraps, promotes or validates.

**What Happened, twice**:

1. **`Promise<T>` in the IDL, `jsUndefined` in the impl.** The whole CookieStore
   API returned the literal `undefined`, not an unresolved promise. Every
   `.then` threw. An impl whose IDL says `Promise<T>` must BUILD the promise -
   the house pattern is `Blob.zig`: `v8_PromiseResolver_New` → `GetPromise` →
   `Resolve` → `JSValue.fromPromise`. Failures must REJECT, not throw
   synchronously, or `promise_rejects_js` cannot see them.

2. **`fromAnyopaque(@ptrCast(&zig_struct))`.** That produces a `.handle` with
   `handle_scope = .global`, and the return path reinterpret_casts it to
   `Global<Value>*` and dereferences it. A heap-allocated Zig struct is aligned
   and inside the heap range, so **every guard passes and the read goes
   through** - killing the process rather than failing the subtest, and taking
   every other test in the file with it.

**Fix**: Build real V8 values. Grep `fromAnyopaque(@ptrCast(&` before trusting
any getter; it should return nothing but comments.

**Takeaway**: **A wrong pointer that passes every guard is worse than one that
fails.** The bad answer dies loudly at the subtest; this one kills the process.

---

### Architecture: A network-error response is not a failed call

**Date**: 2026-09-21
**Lesson**: Fetch reports transport failure **in-band**, as a response object, not as an error return.

**Why**: `mainFetch` catches a transport error and *successfully returns*
`internal_response.networkError()` — type `error`, status 0, empty header list,
null body. Any caller written to expect `catch |err|` sees success.

**What Happened**: `src/browser/navigation.zig` read straight past it to
`getFirstValue("Content-Type") orelse "text/html"`. A network error has no
headers, so every failed navigation became an empty HTML document reported as a
successful page load, and the WPT runner then polled `window.__wpt_complete` for
the full 10-second ceiling. **Every transport failure was laundered into a
silent timeout** — DNS failure, refused connection, TLS error and a genuine hang
were indistinguishable in the journal. It hid an mbedTLS bug that broke all 192
`.https.` tests for a month.

**Fix**: Gate on `response_type == .@"error" or status == 0`, the same
predicate the fetch algorithms already apply. Do NOT test for an empty body or
missing content type — 204/205/304 legitimately have neither.

**Takeaway**: **When a subsystem signals failure in-band, every consumer must
check it explicitly; nothing will throw on their behalf.**

---

### Debugging: A diagnostic below the consumer's log level does not exist

**Date**: 2026-09-21
**Lesson**: Every curl diagnostic was `log.debug`; the WPT runner runs at `.warn`.

**What Happened**: A hard transport failure — connection refused, TLS
handshake failure, DNS failure — printed **nothing at all**. Diagnosing the
mbedTLS ABI mismatch took a 2,052-file journal analysis and four independent
experiments. With the error visible it would have taken one run: curl's own
message named it outright.

**Fix**: Transport failures log at `warn` with the curl code and
`CURLOPT_ERRORBUFFER` text. Per-request chatter stays `debug`. Note
`CURLOPT_ERRORBUFFER` was not even declared in the FFI, and
`curl_easy_strerror` is not a substitute — it gives "Couldn't connect to
server" where the error buffer gives the host, port and timing.

**Takeaway**: **Pick the level from the consumer's threshold, not the
author's.** A failure nobody can see costs more than the noise of one they can.

---

### Architecture: A re-export does not mean the code is compiled

**Date**: 2026-09-21
**Lesson**: `pub const x = @import("y.zig")` does not force semantic analysis of `y.zig`.

**Why**: Zig analyses what is *referenced*, not what is imported. A module can
re-export a namespace, and every declaration inside it stays unanalysed until
something actually calls one. `std.testing.refAllDecls(@This())` does not
recurse into imported namespaces either, so the usual "reference everything"
trick does not close the gap.

**What Happened**: `src/websocket/root.zig` imports and re-exports
`events.zig` and `send_buffer.zig`, and `connection.zig` re-implements
`buffered_amount` inline rather than using `SendBuffer`. So nothing referenced
either file, and **both sat out the entire Zig 0.16 migration** - still calling
`std.ArrayList(T).init(allocator)` - while `zig build` stayed green. Wiring
`tests/websocket/` into the build surfaced 14 compile errors at once, and a
real allocation-size bug in `curl_backend.zig` behind them.

**Fix**: Wire every directory into `zig build test`. An unreferenced module is
untested *and* untypechecked, which are not the same failure but arrive
together.

**Takeaway**: **In a tree with this many re-export roots, "it compiles" means
only "something referenced it".** If you cannot name the test target that
compiles a file, assume it does not compile.

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

---

### Architecture: A conversion that allocates nothing still looks allocated

**Date**: 2026-09-21
**Lesson**: `needsArgCleanup` called every slice "owned", including one that aliased V8's heap.

**Why**: `conv.convertAllowSharedBufferSource` discards its allocator on purpose
(`_ = allocator; // Not needed - we create a non-owning view`) and returns
`.{ .byte_slice = src_ptr[0..len] }` over `v8_ArrayBuffer_Data`. Nothing in the
type says so — the arm is a plain `[]const u8`, the same shape a string that
`fromV8String` allocated has.

**What Happened**: `freeConvertedArg` walked the union, found the slice, and
handed V8's backing store to `allocator.free`. `panic: Invalid free` on every
`new TextDecoder(label).decode(nonEmptyTypedArray)` — 67 of 149 `encoding/` WPT
files, all fifteen `textdecoder-*` among them. The empty case survived because
the cleanup path skips zero-length slices, so it read as "some decodes crash".

**Fix**: `argConversionIsNonOwning`, consulted *before* any structural rule
(the arm that carries the view is itself a slice, so every later rule claims
it). Pinned by `tests/v8/buffer_source_ownership_test.zig` — including the
default, which must stay "owned" or every string argument leaks.

**Takeaway**: **Ownership is a property of the conversion, not of the type.
Grep `conversions.zig` for "non-owning" before trusting a structural rule.**

---

### Spec Compliance: The decoder reports the error; the caller picks the mode

**Date**: 2026-09-21
**Lesson**: A decoder that substitutes U+FFFD itself makes `{fatal: true}` impossible.

**Why**: Encoding § 8.1.1 returns `error` from the handler and § 5.1.3 turns it
into a TypeError or a U+FFFD. Deciding inside the decoder throws away the only
information the caller needs.

**What Happened**: The UTF-8 decoder wrote U+FFFD at all three error sites and
returned `input_empty`, so `TextDecoder.zig`'s `if (result.status ==
.malformed) { if (fatal) ... }` was dead code — 35 of 36 subtests in
`textdecoder-fatal.any.js` failed on `assert_throws_js`, while
`textdecoder-fatal-single-byte.any.js` passed 64,512, because the single-byte
decoder reports. The contract was already written down, in that decoder's own
comment.

**Fix**: Return `.malformed` with the spec's error extent — step 4 RESTORES the
offending continuation byte, so it is not part of the error — and give
`Decoder` a `decodeReplacement` so replacement-mode callers substitute once
instead of four times by hand.

**Takeaway**: **When one decoder in a family passes a conformance file and its
siblings do not, diff their contracts before their algorithms.**

---

### Architecture: A null parent is not proof of ownership

**Date**: 2026-09-21
**Lesson**: `DomTreeAdapter.deinit` decided what to free by re-reading
`getParent(node) == null` over every node the parser had ever created.

**Why**: The adapter's map outlives the nodes in it. A node the parser attached
belongs to V8 from that moment - the wrapper cache holds it and a weak callback
can hand its Instance handle back to the slab whenever. And a recycled handle
still *looks* like an Instance: `SlabAllocator.free` overwrites only offset 0
(the vtable, with the free-list link) and `alloc` re-stamps `state` and `ctx`
with `undefined`, which is 0xAA bytes in a safe build. Nothing about the 24
bytes says "this is not the node you mapped".

**What Happened**: on a document big enough for one GC during the parse, the
sweep followed a recycled pointer into an instance belonging to a context that
had already been torn down, and `markInstanceCleanedUp` panicked at
`@ptrCast(@alignCast(cache_storage))` with `incorrect alignment` - the
`_v8_wrapper_cache_storage` it read came out of freed memory, and `0xAAAA…AAAA`
is not null, so `orelse return` passed it straight to `@alignCast`. Roughly 40
crashes in `encoding/*-encode-form-*` alone. The same sweep also freed nodes a
script had detached but still held, which is the same bug pointing the other way.

**Fix**: record membership when you take it. `unattached_nodes` gains a node in
`onNodeCreated` and loses it the instant `appendChild` succeeds; `deinit` sweeps
that set. An unattached node is unreachable from script, so nothing can have
wrapped or collected it, so its pointer is still valid.

**Takeaway**: **Ownership is a fact you record at the moment you take it, never
a predicate you re-evaluate later - by then the object may be someone else's.**

---

### Architecture: `var x = entry.field` is a copy, so clearing it clears nothing

**Date**: 2026-09-21
**Lesson**: `destroyChildContext` and `context_manager.deinit` both opened with
`var ctx_data = entry.runtime_ctx;` and then mutated `ctx_data`.

**Why**: `ContextEntry.runtime_ctx` is an inline `ContextData` and
`runtime.Context` is `*ContextData`, so every Instance created in that context
holds `&entry.runtime_ctx` - the entry's own field is the one everybody reads. A
`var` binding copies the struct, so `ctx_data.clearV8WrapperCacheStorage()`
cleared a stack copy that nothing else could see.

**What Happened**: after 4c freed the `WrapperCache`,
`entry.runtime_ctx._v8_wrapper_cache_storage` still pointed at it, and the realm
and context-data phases that run next can reach an Instance whose `ctx` is that
entry. Silent rather than loud, because a freed-but-aligned pointer sails past
`@alignCast`.

**Fix**: `const ctx_data = &entry.runtime_ctx;`. Nothing else changes - the
copy's `deinit()` was already freeing the original's buffers.

**Takeaway**: **A struct field read into a `var` is a copy; if you mean to clear
the original, bind a pointer. Grep for `var x = y.field` wherever a teardown
path "clears" something.**

---

### Architecture: A struct that hands out interior pointers cannot be freed on its own schedule

**Date**: 2026-09-21
**Lesson**: `ContextEntry` is heap-allocated *precisely* so that `instance.ctx` can
point into it - and then `removeContext` and `destroyChildContext` freed it while
those Instances were still alive.

**Why**: `Instance.ctx` is `*ContextData`, and the ContextData lives inline in
`ContextEntry`. The comment on `ManagerState.contexts` spells the dependency out:
entries are heap-allocated and stored by pointer so that "any pointer into
entry.runtime_ctx (like Window.ctx or Element.ctx)" survives a rehash. But
teardown deliberately does **not** destroy that context's Instances - "the slab
allocator will batch-free all instances during full teardown anyway" - so freeing
the entry leaves every one of them holding an interior pointer into freed memory.
The invariant was written down in the file and broken 800 lines later.

**What Happened**: `state.allocator` is a `DebugAllocator`, which poisons freed
memory with 0xAA. So `entry.runtime_ctx._v8_wrapper_cache_storage` read back as
`0xAAAA_AAAA_AAAA_AAAA` - non-null, so `orelse return` passed it through, and 2
mod 4, so `markInstanceCleanedUp` died in its `@alignCast` with `panic: incorrect
alignment`. Stack: navigate -> `Context.deinit` -> `removeContext` ->
`destroyChildContext` -> `Window.deinit` -> `Document.deinit` -> `Node.deinit`.
Every other reader of `instance.ctx` was reading the same poison, just quietly.

**Fix**: retire the entry instead of freeing it. Clear the fields that can dangle,
push it onto `ManagerState.retired`, and free the whole list in `deinit()`, where
the Instances are going away anyway. One entry per destroyed context for the
manager's lifetime, all of it freed at the end.

**Takeaway**: **A structure that hands out pointers to its interior must outlive
every holder. When you cannot enumerate the holders, retire rather than free -
0xAA is not null, so a poisoned read is a crash, not a null check.**

---

### Codegen: Callback FUNCTIONS cannot move to CallbackWrapper until the registry is real

**Date**: 2026-09-21
**Lesson**: `src/runtime/engines/v8/callback_registry.zig` is a 20-line stub whose
two functions are both no-ops, so every `CallbackWrapper` ever created leaks.

**Why**: WebIDL has two callback kinds and codegen treats them differently.
Callback *interfaces* (EventListener, NodeFilter) generate as
`?*runtime.CallbackWrapper` and work. Callback *functions* generate as a bare
`*const fn`, which `conversions.zig:1209` satisfies by TAGGING the V8 function
pointer. Nothing can be called through that, so
`CustomElementConstructor = *const fn () *runtime.Instance` means `super()` can
never work - `custom-elements/CustomElementRegistry.html` sits at 8/46.

Migrating callback functions onto `?*runtime.CallbackWrapper` is the right fix
and the generator change is ~10 lines. It was written, measured, and reverted
TWICE. The reason is not the 26 compile errors it surfaces - those are
mechanical, and `callback_wrapper.zig:53` exposes exactly the
`callback_function_global: ?GlobalHandle` that `extractEventHandler` needs.

**What Happened**: the blocker is ownership, and it is one level down.

    today   el.onclick = fn   tags a pointer. NO allocation. The impl owns
                              and disposes its one Global handle.
    after   el.onclick = fn   allocates a wrapper + 2 Global handles, and
                              `callback_registry.register` DISCARDS its
                              argument, so nothing frees any of it.

So the migration converts a correctly-disposed hot path into a per-assignment
leak. `cleanupForContext` is never called from anywhere in `src/`, and only 2
sites call `register` at all.

Fixing the registry first is the obvious move and runs straight into the other
wall: cleanup has to happen at context teardown, and added work in
deinit/onObjectFreed has cost 2-3 crashes per 6 WPT runs, proven three ways.
The 0.1 gate is ZERO crashes.

**Fix**: the ordering is registry -> teardown race -> migration, and the
teardown race is the real blocker. Do NOT reland the generator change before
`register` tracks and `cleanupForContext` frees. The reverted generator lives
at `.claude/jobs/2e30a6c4/tmp/generator-callbackwrapper.zig`.

**Takeaway**: **When a change is mechanical but keeps getting reverted, the
blocker is under it, not in it.** Two reverts were spent on the 26 compile
errors before anyone read the registry it was migrating onto.

---

### Codegen: Raw codegen output is not `zig fmt`-clean, so regeneration looks like a 1,419-file change

**Date**: 2026-09-21
**Lesson**: Running codegen and then `git status` shows ~1,419 modified files
under `src/webidl/` with no semantic change in any of them.

**Why**: the committed generated files were formatted; the generator's own
output is not. The diff is almost entirely whitespace:

    13,175 lines  trailing spaces on otherwise-blank lines
     3,896 x 2    `pub const x = .{};` re-emitted as `.{\n};`
       111        `type:` re-emitted as `@"type":` (redundant but legal)

**What Happened**: this buried a real 75-file callbacks change inside 1,419
files of noise, and made "did codegen change anything?" unanswerable by
inspection. It also makes AGENTS.md's advice to delete the generated dirs and
regenerate from scratch read as catastrophic when it is harmless.

**Fix**: `zig fmt src/webidl/` immediately after any `zig build codegen`, before
`git status`. The pre-commit `zig fmt src/ tests/ tools/` already covers it, but
by then the diff has already been read wrong. Only the `@"type"` lines are a
genuine generator difference.

**Takeaway**: **Format generated output before you diff it, or the diff is
unreadable and a real change hides in it.**

---

### Architecture: The live window globals are installed natively, not through WebIDL

**Date**: 2026-09-22
**Lesson**: `requestAnimationFrame` discarded its callback and returned 0, so ~90
worklist sources HUNG rather than failed - and the reason it was invisible is
that `impls/Window.zig` is not where window globals come from.

**Why**: `src/browser/Context.zig` installs the real window globals directly on
the global object via `FunctionTemplate`: `setTimeout`, `clearTimeout`,
`setInterval`, `clearInterval`, `addEventListener`, `removeEventListener`,
`dispatchEvent`, `fetch`, and now `requestAnimationFrame` /
`cancelAnimationFrame`. The WebIDL `call_setTimeout` in BOTH `impls/Window.zig`
and the `WindowOrWorkerGlobalScope` mixin returns `error.NotImplemented` and is
dead code.

**What Happened**: `call_requestAnimationFrame` ended with

    // TODO: Proper callback wrapping - for now return placeholder
    _ = callback;
    return 0; // Placeholder

It reads as half-implemented rather than absent, because it lazily constructs an
`AnimationFrameScheduler` first. There are also TWO unused rAF implementations
in the tree - `event_loop/rendering.zig`'s `AnimationFrameProvider` and
`window/animation_frame.zig`'s `AnimationFrameScheduler` - both only ever
re-exported, and `runAnimationFrameCallbacks` has no caller outside its own
module. Per the re-export lesson above, neither was even analysed.

The cost was not failures but TIMEOUTS: rAF is WPT's standard "wait one frame"
idiom. 90 of 4,323 worklist sources use it directly and more reach it through
support helpers; `html/dom/render-blocking/` alone was 57 blocking of 62, with
48 of its 64 files using rAF.

**Fix**: install it natively in `Context.zig` alongside the timers, driven by
one `setTimeout` at the frame interval. A frame is a BATCH: every callback
registered before it runs in registration order sharing ONE timestamp, and a
callback registered during the batch is deferred to a later frame - so one timer
per callback is wrong. `queueMicrotask` (in the mixin) and `requestIdleCallback`
were checked and are genuinely implemented; rAF was the only placeholder of this
shape.

**The same trap in the other direction.** Grepping `impls/` for stubs produces
false alarms, because many impls are dead code shadowed by a native
implementation. All 18 impls with `call_forEach` discard their callback -
`Headers`, `URLSearchParams`, `FormData`, `NodeList`, `DOMTokenList` - which
looks like `headers.forEach(cb)` silently doing nothing across the whole engine.
It is not: `interface.zig`'s `forEachCallback` implements the iterable methods
natively, validates its argument and iterates properly. The impls are never
called.

So there are at least three places a window/interface member can really live,
and `impls/` is the one least likely to be authoritative:

| Where | Examples |
|-------|----------|
| `src/browser/Context.zig` | setTimeout, setInterval, fetch, addEventListener, rAF |
| `src/runtime/engines/v8/interface.zig` | iterable methods: forEach, keys, values, entries |
| `src/webidl/impls/` | everything else |

**Takeaway**: **Before concluding anything from a stub in `impls/`, find the
binding that actually runs.** A stub there may be dead code (harmless) or the
live path (a hang); the two look identical in the file. And a stub that returns
a sentinel instead of throwing converts a failing test into a hanging one, which
costs the full timeout and reports as an engine defect rather than a missing
feature.

---

### Testing: A test file added while `wpt serve` is running 404s, and a 404 reads as TIMEOUT

**Date**: 2026-09-22
**Lesson**: `wpt serve` fixes its file routing at startup. The runner REUSES a
live server. So a test file you create now is not servable until that server is
killed - and the symptom is a timeout, not an error.

**Why**: `tests/wpt_runner/wpt_server.zig` checks for an existing server (via
`.wpt_serve.lock`, falling back to the port) and sets `we_spawned = false` when
it finds one. That server keeps serving for as long as it lives - 35 minutes in
the case that produced this note - and 404s anything created after it started.
The runner then loads the 404 body as the test page, `window.__wpt_complete`
never becomes true, and the file is journalled TIMEOUT at the 10s ceiling. This
is the same in-band-failure laundering as the network-error lesson above.

**What Happened**: measured, because it looked exactly like a code regression.

    crane/ce-get.html        (Sep 21 14:30, before the server)  HTTP 200  OK, 2 subtests
    crane/ce-get-copy.html   (byte-identical copy, 00:44)       HTTP 404  TIMEOUT, 0 subtests
    crane/bisect-trivial.html (`assert_true(true)`, 00:39)      HTTP 404  TIMEOUT, 0 subtests

Server PID start time 00:15:00. Same directory, same permissions, same bytes,
same load - only the creation time differed. Adding the files to MANIFEST.json
changed nothing; `wpt serve` is not consulting the manifest for this.

A new rAF test went from 5 subtests on its first run to 0 subtests afterwards,
and the 0 was pure 404. Most of an hour went into bisecting a change that was
never at fault, including a discarded worktree build.

**Fix**: before trusting ANY result from a test file you just added:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://web-platform.test:8000/crane/<file>.html
```

200 means it is servable. 404 means kill the server and re-run:

```bash
lsof -t -nP -iTCP:8000 -sTCP:LISTEN | xargs -r kill
```

**Takeaway**: **A brand-new test reporting TIMEOUT with ZERO subtests is a 404
until proven otherwise.** Zero subtests means the harness never ran at all,
which is a different failure from a test that hangs - a real hang still reports
the subtests it got through.
