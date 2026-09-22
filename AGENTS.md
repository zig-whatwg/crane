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

**Stuck on HOW to implement something? Read an engine that already has.**
The specs say what; V8, WebKit, Blink and Gecko show how, and every problem
this engine meets - wrapper lifetime, handle ownership, teardown order, event
dispatch, parser state - was met and solved there first. Read them BEFORE
designing a mechanism, not after a theory has failed:

| Question | Where |
|----------|-------|
| V8's contract for an API (handles, weak callbacks, embedder roots, CHECKs) | `jsengines/v8/include/*.h` - V8 13.1, local; the doc comments ARE the contract. Source: `jsengines/v8/v8/` (full checkout, local) |
| How a browser binds the DOM to V8 | Blink: `third_party/blink/renderer/bindings/` and `platform/bindings/` (script_wrappable, dom_data_store, the GC controller) in https://github.com/chromium/chromium |
| The most readable DOM and bindings implementation | WebKit: `Source/WebCore/bindings/js/` (JSNodeCustom.cpp, JSDOMWrapper) and `Source/WebCore/dom/` in https://github.com/WebKit/WebKit |
| Implementations annotated with the spec's own step numbers | Gecko: `dom/base/`, `dom/bindings/`, `js/src/` via https://searchfox.org |

Fetch the file, read the function, cite it in the commit. Take the DESIGN,
never the code: the licences differ, and a copied function carries assumptions
about refcounting, tracing and threading that this engine does not share.

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
zig build wpt-runner -j2 --cache-dir /tmp/crane-z16-cache   # the one artifact WPT needs
zig build test       -j2 --cache-dir /tmp/crane-z16-cache
```

**Never run a bare `zig build`, and always pass `-j2`.** `build.zig` installs
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
8. **Inventing a mechanism?** Check how V8, WebKit, Blink or Gecko do it
   first - see "Stuck on HOW" above. If they have a name for it, use theirs.

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

---

### Testing: `--parallel` can manufacture ERROR results; confirm a surprising number serially

**Date**: 2026-09-22
**Lesson**: The same directory measured two ways disagreed completely, and the
sharded answer was the wrong one.

**What Happened**: `html/dom/render-blocking/` immediately after the rAF fix:

    --parallel=2   62 files   OK  2   TIMEOUT  0   CRASH 0   ERROR 60
    --parallel=1   62 files   OK 37   TIMEOUT 17   CRASH 5   ERROR  3

The 60 ERRORs carried `nav_ms 103, load_ms 728, wall_ms 833` and zero subtests -
the pages LOADED, in under a second, and reported nothing. Running one of them
on its own gave `OK in 51ms with 6 subtests`, so the file was fine and the
sharded run was inventing the result.

`html/webappapis/timers/` sharded at `--parallel=3` three times with no ERRORs
at all, so this is not every directory. Do not assume sharding is broken; do
assume a surprising result needs a serial confirmation.

**Fix**: take FINAL numbers at `--parallel=1`. Use higher parallelism for
sweeps and triage where the cost of a wrong cell is low, and re-measure anything
you are going to act on or report.

Per-file comparison against the previous state is stronger than comparing
totals, because it survives a change in parallelism or load:

    32  TIMEOUT -> OK        the actual win
    17  TIMEOUT -> TIMEOUT   still hanging, other causes
     5  CRASH   -> CRASH     untouched by this change
     5  OK      -> OK        no regressions

**Takeaway**: **An aggregate can move for reasons that have nothing to do with
the change; a per-file transition table cannot.** Three separate measurement
artefacts impersonated engine defects in one session - a 404 read as TIMEOUT,
`journal.jsonl` read as a missing `wptreport.json`, and this. A result that is
uniformly catastrophic across independent runs is the instrument, not the code.

---

### Testing: One file can hang the runner past its own per-file ceiling

**Date**: 2026-09-22
**Lesson**: `html/browsers/history/the-location-interface/per-global.window.js`
ran for **78 minutes** against a 10-second ceiling, and the sweep behind it made
no progress at all.

**Why**: the per-file timeout is enforced around the page load and the harness
poll. Whatever this file reaches is not covered by either, so the ceiling never
fires and the supervisor never moves on. A `--from-file` sweep is strictly
sequential per shard, so one such file stops everything behind it.

**What Happened**: a serial sweep of the 1,181 never-run worklist files stopped
at 327 and sat there. `pgrep` showed the process alive and busy, which reads as
"still working" - the journal's mtime is what gave it away:

    journal last written  02:37:12
    now                   03:54:56
    process age           2h15m

78 minutes for 0 files. Restarting from the remainder with that one path removed
resumed normally.

**Fix**: when a long run looks slow, check the JOURNAL's mtime, not the process.
A live process proves nothing.

```bash
stat -f "%Sm" -t "%H:%M:%S" <output>/journal.jsonl; date "+now:      %H:%M:%S"
```

To resume, diff the journal's paths against the worklist and re-run the
remainder, dropping the first not-done path - that is the one it hung on.

**Takeaway**: **A sweep's progress is what it has WRITTEN, not whether it is
running.** The per-file ceiling is not a guarantee; budget for one pathological
file stalling a batch indefinitely, and check liveness by output rather than by
process.

---

### Architecture: An empty `MaybeLocal` from a V8 callback is a promise, not a return value

**Date**: 2026-09-22
**Lesson**: `v8::Module::ResolveModuleCallback` returning empty means "I have
already thrown". Returning empty without throwing kills the process.

**Why**: V8 cannot represent "no module and no reason". Its internals `CHECK`
that an exception is scheduled whenever a resolve callback comes back empty, and
a failed `CHECK` is `IMMEDIATE_CRASH()` - SIGTRAP on arm64, with no Zig frame in
the trace because nothing Zig wrote is on the stack.

**What Happened**: `v8_Module_SetResolveCallback` is **never called from Zig**.
`moduleResolveCallback` exists in `script_execution.zig` and nothing installs
it, so `g_module_resolve_callback` was always null and
`V8ModuleResolveCallback` returned `MaybeLocal<Module>()` for every import in
the process. Every `<script type=module>` containing an `import` took the
runner down. In `html/semantics/scripting-1/` that was 47 of 59 measured
crashes, all in `the-script-element/module/`, plus `json-module/`,
`import-attributes/` and `microtasks/` - and it read as "modules crash",
which is a much larger-sounding problem than one missing `ThrowException`.

A `TryCatch` does NOT help here. It catches a thrown exception; it cannot catch
a `CHECK` inside V8.

**Fix**: throw before returning empty - a TypeError, which is also what the HTML
spec's "resolve a module specifier" produces on failure - and skip the throw if
`isolate->HasPendingException()` so a real cause is not clobbered. Separately,
`v8_Module_Compile`, `v8_Module_Instantiate` and `v8_Module_Evaluate` (the
non-`_Safe` trio) had no `TryCatch` at all, so a syntax error left an exception
pending that detonated at the next unrelated V8 call.

**Takeaway**: **Every V8 API that can return "empty" documents what it wants
alongside it. Read the contract, not the signature - the signature will compile
either way and the violation surfaces as a process death somewhere else.**

---

### Architecture: `event_utils.dispatchEvent` invokes no listeners, on purpose

**Date**: 2026-09-22
**Lesson**: `event_utils.fireSimpleEvent` cannot be used to fire an event that
script is supposed to hear.

**Why**: `fireEvent` synthesises a `ContextData` on the CALLER'S STACK when
handed a null context, and `Event.call_constructor` stores it in
`instance.ctx`. The only thing keeping that from becoming a dangling pointer is
that `dispatchEvent` runs no listener, so the event is never wrapped by V8 and
never outlives the frame. The file says so in capitals, and it is correct.

**What Happened**: `script_execution.fireLoadEvent` and `fireErrorEvent` both
went through it, so neither `script.onload = fn` nor
`script.addEventListener("load", fn)` had ever fired for a `<script>` element -
in either direction, for any script, ever. Tests that wait on a script's load
event waited out the full harness timeout, which is most of
`the-script-element/microtasks/` and a good part of `module/`. The symptom is a
hang, so it reads as a scheduling bug rather than a dispatch one.

**Fix**: a script element has a real context whose entry outlives every Instance
in it, so fire at it with `interfaces.EventTarget.call_dispatchEvent` instead -
that walks the event path, invokes listeners, and calls
`invokeIdlEventHandler` for the `on*` IDL attribute. Do NOT `defer
Event.deinit`: a listener can hand the event to script and V8 will hold a
wrapper. `errdefer` only, exactly as `HTMLParser.fireDOMContentLoadedEvent` does.

**Takeaway**: **A stub whose comment explains why it is safe is describing a
precondition, not a TODO. Check whether your caller meets it before reusing it.**

---

### Spec Compliance: "Prepare the script element" had no insertion-steps caller

**Date**: 2026-09-22
**Lesson**: `prepareScriptElement` was only ever called by the two parser paths,
so a script created by `document.createElement` and appended never ran.

**Why**: HTML lists "the script element becomes connected" as a trigger for
preparing a script that is *not* parser-inserted. `src/dom/mutation.zig` has the
registry for exactly this (`registerInsertionStepsCallback`), and only
`HTMLIFrameElement` had ever used it.

**What Happened**: `execution-timing/` builds 140 of its 153 files out of
`testlib.addScript()`, which is `createElement('script')` + `appendChild`. None
of those scripts ran. Three further defects were hiding behind that one, each
invisible until the one in front of it was fixed:

1. `handleScriptScheduling` tested `has_async` where step 35.1 says "has an
   `async` attribute **OR** force async is true", so a dynamically-inserted
   `<script src>` fell through all four cases onto a bare `return true`.
2. Nothing drained the "execute as soon as possible" queues - `executeScriptsAsap`
   and `executeScriptsInOrderAsap` existed and had no callers.
3. `Document.InternalState.base_uri` is assigned by nothing in the tree, so every
   relative `src` resolved to itself. An absolute URL in the same position
   worked, which is what isolated it.

**Fix**: register the insertion steps from `HTMLScriptElement.init`. The parser
is excluded by the spec's own condition and needs no extra flag: both tree
builders set the parser document on the element *before* appending it, so
`isParserInserted` is already true. That ordering is load-bearing - the parser
appends the script while it is still EMPTY and adds its text children
afterwards, so preparing it on insertion would mark a sourceless script
already-started and kill it.

**Takeaway**: **When a directory of tests all hang on the same idiom, look for
the algorithm that idiom triggers and ask who calls it. "No caller" is a
likelier answer than "wrong implementation", and grep answers it in one line.**

---

### Testing: A drain guard keyed on a boolean strands a second document

**Date**: 2026-09-22
**Lesson**: Re-entrancy guards over per-document queues must record the
document, not a flag.

**Why**: A script run from a drain can insert a script into *another* document -
an iframe's, or one from `createHTMLDocument`. A global "already draining"
boolean suppresses that document's drain while nobody is walking its queues, and
the outer loop only ever rescans the document it was given, so the script sits
in the queue forever. The failure is a hang, not a crash, and only on pages with
two documents.

**Fix**: `var draining_document: ?*runtime.Instance`, compared against the
document being asked for. A different document nests (bounded by an explicit
depth cap for the mutually-recursive case); the same document returns and lets
the outer loop pick the new entry up.

**Takeaway**: **A guard against re-entrancy has to be as fine-grained as the
state it protects, or it turns recursion into deadlock.**

---

### Debugging: `v8::Module` CHECKs its own preconditions, and a failed CHECK is SIGTRAP

**Date**: 2026-09-22
**Lesson**: `IsGraphAsync`, `GetModuleNamespace` and `Evaluate` all require a
module that is at least `kInstantiated`, and enforce it with a CHECK.

**Why**: The doc comments read as advice ("Must be called after module
instantiation"). They are not. V8 aborts:

    # Fatal error in v8::Module::IsGraphAsync
    # v8::Module::IsGraphAsync must be used on an instantiated module

**What Happened**: `script_execution.runModuleFromSource` asks
`engine.hasTopLevelAwait(module)` immediately after compiling, to choose between
the sync and async evaluation paths - before anything instantiates. So EVERY
module script killed the process, including inline ones with no imports, which
is why the first hypothesis (unresolvable imports) fit the failing set well
enough to be believed and was wrong. The journal only records
`.{ .signal = .TRAP }`; the message is on the child's stderr and the runner
swallows it unless you run the one file by hand.

**Fix**: guard at the FFI boundary, where "V8 will abort" becomes a value Zig
can see - `if (local_module->GetStatus() < Module::kInstantiated) return ...`.
False for `IsGraphAsync` is the safe answer, because the caller then evaluates
synchronously and `Evaluate()` on a top-level-await module returns a promise
anyway.

**Takeaway**: **Run the one crashing file by hand before theorising. A
`.{ .signal = .TRAP }` in the journal is V8 telling you exactly what is wrong on
a stderr nobody is reading.**

---

### Testing: A subtest count can go DOWN because a test started testing something

**Date**: 2026-09-22
**Lesson**: `xhr/access-control-and-redirects.any.js` went from 4 passing
subtests to 3, and the change that did it was an improvement.

**Why**: its async cases read

    xhr.onerror = test.unreached_func("Network error");
    ...
    test.done();

with the `done()` synchronous. While `send()` never reached the network, no
request went out, `onerror` never fired, `unreached_func` was never called, and
the subtest passed **by doing nothing**. Once `send()` actually dispatched, the
cross-origin request was denied by CORS, `onerror` fired, and the subtest failed
on its merits. The file is measuring CORS for the first time.

**What Happened**: it appeared in a per-file diff as the single regression in an
otherwise clean sweep - `OK 40 -> 67`, `TIMEOUT 29 -> 7`, `subtests timed out
50 -> 9`. Reported as a regression it would have been chased; reported with the
reason it is a line item.

The same sweep showed a FLAT crash column that was not flat: the baseline's one
crash became OK and a different file crashed once, non-reproducibly. A totals
row said "crashes unchanged" and two real transitions were hiding under it.

**Fix**: when a subtest count drops, read the test before assuming a defect.
`unreached_func`, `assert_unreached` and a synchronous `done()` are the shapes
that pass while an engine does nothing at all.

**Takeaway**: **Subtest counts are not a monotone quality signal.** An engine
that starts performing an operation will fail tests that used to pass by
skipping it, and the honest report says which of the two is happening. Diff per
FILE and per SUBTEST NAME; a totals row can hold two opposite movements that
cancel.

---

### Architecture: A codegen-stub `init` silently produces a stateless node

**Date**: 2026-09-22
**Lesson**: `CDATASection.zig` and `ProcessingInstruction.zig` still had the
generated stub `init` - `runtime.Instance.init(...)` plus `// TODO: Initialize
your instance state here if needed` - so they never chained through
`CharacterDataImpl.init` -> `NodeImpl.init` -> `EventTargetImpl.init`.

**Why**: An impl's `init` IS the inheritance chain. Skipping it produces an
instance with the right vtable and the right `State` type - so it wraps, it
passes every pointer guard, and `instanceof` is correct - but with none of the
state its parents own. Its data, node type, parent, owner document and listener
list are all simply absent, and every accessor returns `InvalidStateError`.

**What Happened**: `document.createCDATASection()` and
`createProcessingInstruction()` had never returned a usable node. That is not
niche, because `dom/ranges` and much of `dom/nodes` build their fixtures in
`dom/common.js`, which calls both inside `setup()` - and testharness rethrows
out of `setup()`, so ONE DOMException there turns the whole file into a harness
ERROR with zero subtests. 20 of 30 `dom/ranges` files reported ERROR for this,
and the runner shows only `Error: [object DOMException]`, naming neither the
call nor the file.

The same shape hid elsewhere: `Event.init` allocates the instance but leaves
`_internal` null, and only `Event.call_constructor` creates it. So
`Event.init` + `initEvent` took `initEvent`'s `getInternal(...) orelse return`
early exit, the initialized flag was never set, and `dispatchEvent` rejected the
event per DOM 2.8 step 1 - which is why DOMContentLoaded never fired on any
document.

**Fix**: Chain `init` to the parent impl. To find the rest:

```bash
grep -rn "TODO: Initialize your instance state" src/webidl/impls/
grep -rln "runtime.Instance.init" src/webidl/impls/   # should be rare
```

Then check the constructor, not just `init`: if `X.call_constructor` creates
`_internal` and `X.init` does not, every engine-side caller of `init` gets a
stateless object.

**Takeaway**: **A stub `init` fails as `InvalidStateError` from somewhere else
entirely, long after construction. When a whole directory ERRORs with zero
subtests, suspect one throwing call in a shared `setup()` before suspecting the
tests.**

---

### Architecture: Interface getters clone and hand you the memory

**Date**: 2026-09-22
**Lesson**: `Element.get_localName`, `get_namespaceURI`, `get_prefix`,
`Attr.get_name`/`get_value` and friends all end in
`try x.clone(instance.ctx.allocator)` with the comment "transfer ownership to
caller (interface layer will free)".

**Why**: That comment is written for the SCRIPT caller. When JS reads the
property, the binding layer frees the returned `DOMString`. A Zig caller has no
such layer, so it owns the allocation.

**What Happened**: Writing `cloneNode` against the interfaces - the direction
the impls boundary asks for - leaked the element's local name, namespace and
prefix plus three strings per attribute, on every clone, in a path that runs for
every `cloneNode`, `importNode` and `Range.cloneContents`. Invisible to
`std.testing.allocator`, because it is the context allocator.

**Fix**: `defer x.deinit(node.ctx.allocator)` on every getter result. Free with
**`ctx.allocator`**, which is what the getter cloned into -
`node_internal.allocator` is not necessarily the same one. `DOMString.deinit`
is a no-op for `.empty` and `.interned`, so it is safe unconditionally.

**Takeaway**: **"The interface layer will free it" means the JS binding will.
Calling a `get_*` from Zig makes you the owner.**

---

### Architecture: A value the spec calls COMPUTED must not be cached

**Date**: 2026-09-22
**Lesson**: Four getters in a row returned null or "" because they read a field
somebody had to remember to set, where the spec defines the value as derived
from the tree.

**Why**: the caches are filled by the PARSER paths only - `HTMLParser`,
`dom_tree_adapter`, `scripted_parser`, `context_manager`. Anything built through
the DOM API skips all four, so the field stays null and every getter downstream
of it answers null too.

    documentElement   read internal.document_element   -> null for DOM-built docs
    body / head       derived from documentElement     -> null with it
    doctype           read internal.doctype            -> null
    nodeName          read Node's internal.local_name  -> "" for EVERY element

`nodeName` is the same shape as the CharacterData bug fixed in c36582d40: an
element's local name lives in ELEMENT's state, not Node's, so Node's copy is
always null. It now delegates to `Element.tagName`, which DOM 4.9 already
defines as the HTML-uppercased qualified name `nodeName` is supposed to return.

**What Happened**: `document.implementation.createHTMLDocument("")` returned a
document whose `.body` was null, even though the constructor had correctly
created and appended html/head/body. The cost was not one API: `dom/common.js`
builds its fixtures inside `setup()`, and testharness RETHROWS out of `setup()`,
so a single null turns the whole FILE into a harness ERROR with zero subtests.

**Fix**: compute from the tree, keep the cache only as a fallback so paths that
set it without linking the tree still work. A cache also goes stale - removing
or replacing the root left the old pointer in place.

**Takeaway**: **When a spec says "the first X child", store nothing.** Walking a
document's children costs nothing; a cache that only one code path fills is a
null waiting for the other paths to find it. Grep for `internal.<thing> orelse
return null` in a getter whose spec text begins "the first".

---

### Spec Compliance: Tree construction never received an EOF token

**Date**: 2026-09-22
**Lesson**: `TreeBuilder.parse` broke out of its loop when the tokenizer returned
`null`, so no `.eof` token was ever dispatched and the `.eof` branch of every
insertion mode was dead code.

```zig
while (true) {
    const token = try self.tokenizer.nextToken();
    if (token == null) break;        // end of input exits HERE
    ...
    if (tok == .eof) break;          // unreachable
}
```

**Why it matters**: HTML §13.2.6 gives EOF real work. "In head" at EOF pops the
head element and reprocesses in "after head", which inserts an implied `<body>`.
Every "stop parsing" step is an EOF step.

**What is FIXED**: EOF is now synthesised and processed when the tokenizer
signals end of input. Verified no regressions - dom/nodes 40 files per-file:
23 OK->OK, 14 TIMEOUT->TIMEOUT, 2 ERROR->OK, 1 CRASH->OK, 0 regressions.

**What is NOT fixed, and is the next thing to look at**: `document.body` is
STILL null for a document whose content is entirely head-level, which is most
WPT files. Do not re-derive the following - it is all measured:

* The tree builder DOES create the implied body -
  `handleAfterHeadAnythingElse` builds it and calls `insertAtAppropriatePlace`,
  the SAME path that successfully inserts `<head>`.
* `in_head`, `after_head` and `text` EOF handlers are each individually correct,
  including text mode's reprocess.
* `tree_builder.parse` is the ONLY tokenizer driver outside document_write's
  tests, so there is no second parser path to blame.
* With an explicit `<body>` tag the element appears:
  `html children: [HEAD, BODY]`. Without one: `[HEAD]`.

So the gap is between the tree builder creating that node and the DOM adapter
receiving it. Instrument `dom_adapter_on_child_appended` for the body node next.

**Takeaway**: **"The loop ended" and "the parser finished" are different
claims.** A tokenizer that reports end-of-input out-of-band leaves every
end-of-input rule in the consumer unreachable, and nothing fails loudly - the
document is simply missing the parts that only EOF would have added.

---

### Architecture: An inline-capacity string cannot be a hash-map key

**Date**: 2026-09-22
**Lesson**: `SmallString` keeps 31 bytes INSIDE the struct, so `toSlice()` on any
by-value copy returns a pointer into a temporary.

**Why**: `TagToken.finishCurrentAttribute` switches from a linear scan to a
`StringHashMapUnmanaged` once a tag carries more than four attributes, and keyed
it on `Attribute.name.toSlice()`. Every Attribute reachable there is a copy:
`for (slice) |existing|` binds a stack slot the NEXT iteration reuses, and
`if (self.current_attribute) |attr|` binds the optional's payload into a frame
that ends when the function returns.

**What Happened**: the seeding loop handed the set N keys that all aliased ONE
address. They hash correctly at insert - the slot holds the right bytes right
then - so nothing goes wrong until the table rehashes. Then every stored key
reads back as the last name written, `grow` finds them all equal, and
`putAssumeCapacityNoClobber` asserts:

    panic: reached unreachable code
      hash_map.HashMapUnmanaged([]const u8,void,...).putAssumeCapacityNoClobberContext
      hash_map.HashMapUnmanaged([]const u8,void,...).grow
      parser.tokens.TagToken.finishCurrentAttribute
      parser.tokenizer.Tokenizer.emitCurrentTag

Seven attributes is the threshold - seeded at the sixth, overflows at the
seventh - so it looked like "one odd WPT file" rather than "the tokenizer".
`<input type min max step value style id>` is an ordinary tag.

**Fix**: the set owns its keys (`allocator.dupe`, freed in `deinit`). A pointer
into `self.attributes` would not have worked either: `infra.List.append`
reallocates.

**Takeaway**: **Before storing a slice as a key, ask what it points INTO, not
what it contains.** Small-string optimisation turns every by-value copy into a
new address for the same text, and the failure surfaces one rehash later, in a
function that looks unrelated.

---

### Architecture: Whoever ends a weak arm inherits V8's Reset obligation

**Date**: 2026-09-22
**Lesson**: `v8_Global_ClearWeak` is the only `releaseWeakArm` caller that hands
the `Global` back, and it was treated like the ones that delete it.

**Why**: when V8 has already queued a first-pass callback (node NEAR_DEATH,
`IsWeak()` false), the callback WILL run. `releaseWeakArm` detached the record
and nulled its back-pointer so the callback would do nothing. That is right for
a disposer - `Reset(); delete;` is on the next line, and the caller's own Reset
discharges V8's obligation. `ClearWeak` has no such next line, so nothing ever
reset that node.

**What Happened**:

    # Fatal error in , line 0
    # Check failed: Handle not reset in first callback.
    #   See comments on |v8::WeakCallbackInfo|.
      GlobalHandles::InvokeFirstPassWeakCallbacks
      Heap::PerformGarbageCollection

`wrapper_cache.zig` disarms on six paths on every DOM wrapper, so all this needs
is a GC landing between V8 queuing the callback and running it. What made that
reliable was creating a child context: `registerAllTemplatesOnly` instantiates
1,263 interface templates and forces a collection in the middle of
`appendChild`. Four `template/additions-to-the-in-body-insertion-mode/ignore-*`
files died on it, all of them via `testInIFrame`.

**Fix**: `releaseWeakArm` takes a `WeakArmEnd`. `handle_survives` keeps the
back-pointer so the queued callback resets the node, and leaves the record in
`armedWeakData` under that handle - not as an arm (`callback` is nulled, so the
Zig finalizer cannot run on state the disarmer is tearing down) but so a LATER
dispose of the same handle can still find it and cut the pointer. Without that
second half, ClearWeak-then-Dispose in one tick puts `Reset()` on freed memory.

**Takeaway**: **"Release the arm" is two different operations depending on
whether the handle outlives the call.** V8 verifies the difference and aborts
the process, so the parameter is not optional documentation.

---

### Testing: A directory argument is filtered through the runner's allowlist, and three 0.1 areas were not on it

**Date**: 2026-09-22
**Lesson**: `wpt_runner custom-elements/` printed "No tests found. Check your
filter paths." and exited 0. The 0.1 worklist had 167 custom-elements files.

**Why**: a directory argument is intersected with `in_scope_categories` in
`tests/wpt_runner/config.zig`, which listed url, urlpattern, encoding, console,
mimesniff, streams, fetch, xhr, dom, html, cookiestore and webidl - and not
`custom-elements` (167 files), `websockets` (200) or `navigation-api` (414).
781 worklist files, 18% of the corpus, were invisible to every directory run.
An explicit file path works, and `--from-file` bypasses the filter entirely,
which is the only reason the sweep ever measured them.

**What Happened**: "No tests found" reads as an empty area, not as a filter, and
the exit code is 0. An agent told to work `websockets/` by directory would have
baselined nothing and reported a clean run. `tools/wpt_subset.py` is the
authority on scope; the runner's list had drifted from it without anything
noticing, because nothing compares the two.

**Fix**: the three areas are on the list now. When adding an area to the
worklist's INCLUDE table, add it here too - or run the area with
`--from-file=<list>`, which is what the sweep does.

**Takeaway**: **"No tests found" with exit 0 is a filter, not a fact.** Any
runner answer that involves zero of something - zero tests, zero subtests, zero
crashes - deserves one question before it is believed: what would this look like
if the input had simply been dropped? This is the sixth distinct way this harness
manufactures a result; the other five are above.

---

### Testing: The runner adopted a zombie as its server, because a zombie answers `kill(pid, 0)`

**Date**: 2026-09-22
**Lesson**: `checkExistingServer` decided "a server is running" by probing the
lockfile's pid with signal 0. A `<defunct>` process passes that probe.

**What Happened**: a runner spawned `wpt serve` while another process already
held :8000. The child died at bind, its parent never reaped it - it was blocked
in `wait4` on a different child - and it had already written
`.wpt_serve.lock` with its pid. From then on every runner "adopted" pid 49683,
a zombie, as the server. It was harmless only because an unrelated `wpt serve`
(53135) happened to be serving the port. Whenever it was not, a run reported

    Page load error: error.NetworkError    (0ms)

with no curl diagnostic - curl never ran, there was nothing to connect to. Eight
of twelve files in one timers run went that way, and the same signature turned
up standalone.

**Fix**: adopt by probing the PORT with a TCP connect (`isServerReady`), which is
the question the code was actually asking; keep the lockfile's pid only if it is
a live, non-zombie process, otherwise adopt with no pid. A lockfile whose port
does not answer is stale whatever its pid says.

**Takeaway**: **"The process exists" and "the process is doing its job" are
different claims, and a zombie satisfies only the first.** Probe the resource,
not the pid. Seventh way this harness manufactures a result.

---

### Debugging: A two-subtest page took 37 seconds to exit, and none of it was the test

**Date**: 2026-09-22
**Lesson**: `wpt_runner` ran a 2-subtest page in 50ms and then spent 37 seconds
exiting. A binary built before the day's changes took 31 seconds on the same
page, so this was never new - nobody had ever timed a runner's exit.

**Why**: the runner used `init.gpa`, a `DebugAllocator(.{})` whose Debug-mode
default is `stack_trace_frames = 6`. Every allocation and every free captures a
six-frame trace, and Zig 0.16's unwinder parses DWARF CFI byte by byte from a
138 MB debug binary to do it. Tearing down one page frees hundreds of thousands
of objects. `sample` showed 99% CPU in `Io.Reader.takeLeb128` under
`captureCurrentStackTrace`, after the test had finished.

**What it cost**: standalone runs pay it once at exit, so any `timeout` under
~40s reported "NO REPORT" for a run that had actually finished - which is how
`custom-elements/connected-callbacks.html` was misread as still crashing after
its crash was fixed. The runner's own "Duration" line is test time, not process
time, which is why this never showed in a log.

**Fix**: the runner owns a `DebugAllocator(.{ .stack_trace_frames = 0 })`.
Leak detection - the count and the addresses - survives; the per-operation
unwinding does not. `CRANE_LEAK_TRACES=1` selects the six-frame allocator for a
run where the traces are the point.

**Takeaway**: **Time the process, not the test.** A debug allocator that
captures a trace per operation turns teardown into the dominant cost of a
short run, and it hides behind every generous timeout.

---

### Testing: The report was written after teardown, so a teardown crash erased the run

**Date**: 2026-09-22
**Lesson**: `run()` wrote `wptreport.json` after `executeTests` returned, and
`executeTests` ends with a deferred `browser.deinit()`. Every result a run
produced therefore lived only in memory while the browser tore down.

**What Happened**: `custom-elements/connected-callbacks.html` ran all of its
tests, then died in `Browser.deinit -> cleanupAllDomRegistries ->
Element registry sweep -> NamedNodeMap.deinit -> stateAs` reading an Instance
the wrapper cache had already freed. The process exited 134 and there was no
report at all - "NO REPORT", which reads as "the test never ran", the opposite
of what happened. Before the allocator fix above it took 21 seconds to get
there, so it read as a hang.

The sharded path is different: `runShard` journals per file and declines to
blame a file when the child dies after the last one is journalled, so a sweep
loses nothing to a teardown crash. It was the standalone path - the one used
to reproduce and fix things - that lost everything.

**Fix**: `executeTests` finishes and writes the report before returning, inside
the frame whose defer tears the browser down. `run()`'s later write overwrites
it with identical results.

**Takeaway**: **Persist results before teardown; teardown is engine code and
crashes like any other.** "NO REPORT" now means the run never produced one,
not that the exit destroyed it - and a crash in teardown still exits non-zero,
so it is not hidden either, only no longer paid for with the data.

---

### Architecture: A timer callback has no HandleScope

**Date**: 2026-09-22
**Lesson**: Any code path that reaches V8 without being called FROM JavaScript must open its own `HandleScope`.

**Why**: V8 opens a scope around a callback it invokes, so an impl reached from
script always has one. A libuv timer callback is entered from the event loop,
not from V8, and `HandleScope::CreateHandle` does not fail politely without one:

    # Fatal error in v8::HandleScope::CreateHandle()
    # Cannot create a handle without a HandleScope

That is an abort. The journal records one CRASH row with zero subtests and no
message pointing anywhere near the cause.

**What Happened**: `WebSocket`'s pump runs as a self-rearming one-shot timer so
that frames are drained on each turn of the event loop. Nothing in the pump asks
V8 for a Local directly - `EventTarget.dispatchEvent` does, several frames down,
when it wraps the event to hand to a listener. So the code read as pure Zig and
died on its first dispatch.

**Fix**: one scope at the timer entry point, wrapping the whole turn:

```zig
const isolate = ffi.v8_Isolate_GetCurrent() orelse ...;
const scope = ffi.v8_HandleScope_New(isolate) orelse ...;
defer ffi.v8_HandleScope_Dispose(scope);
```

Nested scopes (`invokeIdlHandler` opens its own) are fine, and Globals created
inside outlive it, so wrapping the whole turn costs nothing.

**Takeaway**: **Ask who called you, not what you touch.** If the answer is "the
event loop" rather than "script", the scope is yours to open - and grep for
`setTimeout(` with a Zig callback before trusting any impl that reaches V8.

---

### Spec Compliance: A stub that returns `undefined` takes unrelated suites down with it

**Date**: 2026-09-22
**Lesson**: An impl that returns `undefined` where its IDL says `sequence<T>` breaks every script that chains off the result, not just its own tests.

**Why**: There is no marshalling layer - an impl's return value IS the JS return
value. `undefined` has no `.indexOf`, no `.length`, no iterator, so the caller
gets a TypeError at a line that has nothing to do with the stub.

**What Happened**: `URLSearchParams.call_getAll` was

```zig
// For now return undefined - full array support requires V8 array creation
// TODO: Create V8 array with string values
return .undefined;
```

`websockets/constants.sub.js` line 27 is
`params.getAll("wpt_flags").indexOf(flag)`, inside `url_has_flag`, which line 6
calls - eleven lines BEFORE `const SCHEME_DOMAIN_PORT`. The TypeError aborted
the script with that binding created but uninitialised, so every
`websockets/*.any.js` that includes it then died in `CreateWebSocket` with
`ReferenceError: Cannot access 'SCHEME_DOMAIN_PORT' before initialization`.

45 files, window AND worker, none of which ever constructed a WebSocket. The
whole WebSocket surface read as "untested"; it was unreachable. The one test
that named the real defect, `url/urlsearchparams-getall.any.js`, was sitting at
`passed 0, failed 4` in a different directory.

Note the two shapes it presented as: the worker runs reported ERROR, because
`importScripts` propagates the throw to the harness, while the window runs
reported TIMEOUT, because a failed `<script>` tag does not - same cause, two
statuses, neither naming it.

**Fix**: build the array (`v8_Array_New` + `v8_Array_Set`, disposing each
element Global after `Set` takes its own reference). The no-match case returns
an EMPTY array, not undefined - that is what the spec's "empty list" means.

**Takeaway**: **A stub returning `undefined` is not a smaller version of the
feature, it is a trap for its callers.** When a whole directory fails before
reaching the code under test, read the failing SCRIPT top to bottom and find the
first call that leaves the file - the defect is usually in another subsystem
that has its own quietly-failing test.

---

### Architecture: A stale weak callback's `Registry.remove` evicts the LIVE entry at a recycled address

**Date**: 2026-09-22
**Lesson**: The `InstanceRegistry.createIn` hazard above has a named actor now,
and it is not the arena - it is a weak callback for an instance that died
earlier, running `Registry.remove` on an address that a new instance has since
taken.

**What Happened**: `custom-elements/Document-createElement.html` died with SEGV
at 0x0 in `mem.Allocator.rawAlloc` under `Node.init`, at the bottom of an
iframe's insertion steps. Instrumented, with the iframe document's
InternalState pointer printed at each step:

    A  after Document.init:            internal=@124d31490  alloc.vtable=@106311018
    B  before the second createElement: internal=@124d31490  alloc.vtable=@0

Same block, allocator zeroed in between. Between A and B is the `appendChild`
of the new document's `<html>`, and `createChildContext` forces a GC there.
That GC runs the wrapper cache's weak callback for an EARLIER iframe document
that had already died - its slab slot reissued to this one. `Document.deinit`
on that stale instance calls `Registry.remove(address)`, the registry is keyed
on the address, so it removes the live document's entry and returns its block
to the arena, whose free-list write zeroes the allocator field. The next
`getInternal` still finds the block (the pointer was cached) and hands the
zeroed allocator to `Node.init`.

It was not `ArenaAllocator.get()`: that pointer was identical on every one of
the 106 logged calls, before and after. The `|*g|` rewrite stays because it
cannot be less correct, but it fixed nothing and the commit says so.

**Fix**: the slab stamps a generation per slot and the wrapper cache refuses a
mismatch (644f5e44d) - that closed connected-callbacks' teardown crash.
Document-createElement's SEGV survived it: its actor was a size-mismatched
state free (next lesson but one), not a stale callback. The reasoning below is
kept as written. It needs identity, not an address: either the slot records a
generation the slab stamps on every alloc and `remove` refuses a mismatch, or
weak callbacks for bulk-freed instances are cancelled when the slot is freed.
Both are registry/slab design changes. `custom-elements/connected-callbacks.html`'s
exit crash is the same hazard from the other side - the exit sweep reading
`named_node_map` out of a registry block the arena already reissued.

**Takeaway**: **An address is not an identity, and a registry keyed on one will
act on whoever lives there now.** The order of failures is: bulk-freed slot ->
reissued -> stale weak callback -> `remove` on the newcomer. Any fix has to
break that chain at the callback, not at the allocator.

---

### Testing: An exclusion pattern is a substring rule over the whole path

**Date**: 2026-09-22
**Lesson**: `config.isExcluded` matches with `indexOf`, so a short pattern silently deletes whole directories from the corpus.

**Why**: `exclusion_patterns` entries are tested with
`std.mem.indexOf(u8, path, pattern) != null`. There is no anchoring, no path
segmentation, and nothing that distinguishes "a directory named X" from "any
path containing X".

**What Happened**: The entry `"browsers/"` was written to drop WPT's own
`infrastructure/browsers/` browser-driver test - exactly one source. That
substring also occurs in all **701** `html/browsers/` sources, so the entire
browsing-contexts corpus was out of scope: `wpt_runner html/browsers/windows/`
answered `Found 0 test files ... Scope: 0 of 36594 testharness URLs (0.0%)`.
Nothing in that area could be run except by naming each file on the command
line, and `isInScope` looked correct the whole time because the `html`
category matched.

Note that `isInScope` has a careful whole-segment matcher, with tests, so the
category side of the same decision cannot make this mistake. The exclusion
side has no such guard.

**Fix**: Anchor the pattern - `"infrastructure/browsers/"`. Tests pin both
directions: the 701 sources are in scope, the 1 source is not.

**Takeaway**: **Anchor every exclusion pattern at a directory that can only
mean what you meant.** Before adding one, grep the manifest for it and count
what it takes with it.

---

### Testing: The per-file ceiling does not bound the file

**Date**: 2026-09-22
**Lesson**: `waitForCompletion`'s timeout covers only the wait for `__wpt_complete`; the navigation, the parse and every script the parser runs are unbounded.

**Why**: `runHTMLTest` is three phases - `loadTestHarness`,
`loadPageWithOptions`, `waitForCompletion` - and only the third has a
deadline. `fetch()` is synchronous down to `curl_easy_perform`, and
`CURLOPT_TIMEOUT` is 0, so a script that polls in a loop never returns to the
phase that could stop it:

    loadPageWithOptions -> parseHTMLWithScripting -> runClassicScript
      -> PerformCheckpoint -> AsyncFunctionAwaitResolveClosure
        -> fetchCallback -> curl_easy_perform -> poll()

**What Happened**: `common/dispatcher/dispatcher.js` - loaded by **251**
`html/` sources - is `while(1) { try { await fetch(...) } catch {} }`.
`history-traversal/pagereveal/order-in-prerender-activation.https.html` sat in
that stack against a 10s ceiling and never came back, and every file queued
behind it waited too. Another file has run **78 minutes** this way. A sampled
stack named it in one command; reasoning about it from the journal did not,
because a hung sweep and a slow sweep look identical there.

**Fix**: `tests/wpt_runner/stall_watchdog.zig`. The supervisor cannot see
inside the child, but the journal grows by one record per finished file, so a
journal that has not grown is a child that has not finished one - a signal
that needs no cooperation from whatever is stuck. SIGKILL past 150s (more than
double the longest legal per-file budget) and record the file as TIMEOUT: a
hang is not a crash, nothing faulted.

**Takeaway**: **Check liveness by the journal's mtime, not by the process -
and give any unbounded phase an external deadline, because an in-process one
cannot fire while the process is inside a blocking C call.**

---

### Testing: testharness.js reads its own timeout out of a document that does not exist yet

**Date**: 2026-09-22
**Lesson**: `<meta name="timeout" content="long">` was invisible, so every `long` file ran on a sixth of its budget.

**Why**: `WindowTestEnvironment.test_timeout()` walks
`document.getElementsByTagName("meta")` for `name=timeout`. In a browser that
runs as part of the document, so the meta above the `<script>` is there. The
runner installs testharness.js *before* the page is fetched -
`loadTestHarness(ctx)` then `loadPageWithOptions` - so the walk has always run
over an empty document and always returned
`settings.harness_timeout.normal` (10s).

**What Happened**: Two clocks disagreed on every `long` file: 60s from the
runner, which parses the same meta out of the source and has a test proving
it, and 10s from the harness. The harness always won, because it fires first
and calls `complete()`. The file was recorded TIMEOUT with whatever had run,
usually nothing. Measured on
`back-forward-cache/eligibility/inflight-fetch-1.html`: 9,925ms of a 60,000ms
ceiling. 68 of the 664 sources under `html/browsers` declare `long`.

The parser test passed the whole time. The bug was not in what the runner
parsed but in what it never told the harness.

**Fix**: inject `setup({timeout_multiplier: N})` after testharness.js loads -
testharness's own knob for a slow host, applied to exactly the value the meta
lookup should have produced. `config.Timeout.harnessMultiplier` keeps the two
in step, with a test that walks the enum so a third budget cannot drift.

**Takeaway**: **When a library derives a setting from state the host supplies
out of order, the host has to hand it over explicitly. Two components each
reading the same input is not the same as them agreeing.**

---

### Architecture: A synchronous navigation still owes its load event

**Date**: 2026-09-22
**Lesson**: `iframe.src = <http url>` loaded the document and fired nothing.

**Why**: `IFrameIntegration.navigateToSrc` fetches, parses and commits before
it returns - Crane has no async navigation. Both places that set an iframe's
src fired `load` only for `data:` and `javascript:`, guarded by a comment
reading "HTTP URLs are async and would need async load event firing". That was
true of the spec and false of this engine: by the time `setSrc` returns, the
HTTP document is already committed.

**What Happened**: every page waiting on an iframe hung to the ceiling. The
WPT helpers are all written as `iframe.addEventListener("load", ...)` around
a src assignment - `waitForIframe`, `setupSentinelIframe`, `insertIframe` -
so this was not a corner. On a 52-file slice of
`navigating-across-documents/replace-before-load/` and
`origin-keyed-agent-clusters/1-iframe/`: **45 TIMEOUT / 7 OK before, 15
TIMEOUT / 37 OK after**.

**Fix**: queue the event as a MICROTASK rather than firing it inline, and
open a `JsScope` before dispatching. Three deferral shapes were tried; the
measurement picked the winner, not the spec:

1. **Synchronous** - wrong. The event arrives before any listener exists:
   `setupSentinelIframe` sets `src`, appends, and only then awaits, and a
   parser-created `<iframe src>` is appended during tree construction, before
   the document's scripts have run at all.
2. **A task**, which is what §4.8.5 actually says - measured WORSE. On the same
   52-file slice, more files in `replace-before-load/location-setter-*` looped
   under the task form than under the microtask form, because delivering later
   let those tests re-navigate. Its supposed advantage - that
   `waitForCompletion` pumps the loop in <=50ms slices against the per-file
   deadline - does not exist either: `V8EventLoop.runOnceBlocking` drains with
   `while (self.tasks.items.len > 0)`, so a task that queues a task never
   returns to the deadline. HTML §8.1.7.3 runs *one* task per turn; this runs
   the transitive closure. **Bounding that drain by the queue length at entry
   would put every runaway task loop back under the per-file ceiling** - left
   alone here only because that queue is shared with worker startup, whose
   comment says it depends on the cascade completing in one call.
3. **A microtask** - what shipped. It drains at the end of the current script,
   by which point the listener is attached. One file
   (`location-setter-during-pageshow.html`) still loops; the supervisor's
   stall watchdog bounds it.

The task attempt also produced a lesson of its own: a callback reached from
the event loop rather than from V8 has **no HandleScope and no entered
context**, so `Event.call_constructor` died in `HandleScope::CreateHandle` -
a **SIGTRAP**, not an error return, so the whole file went CRASH rather than
failing a subtest. 20 of 52 files crashed that way. `v8.JsScope.init` fixes
it, and is kept in the microtask path too: it costs a nested scope and makes
the callback correct wherever it is called from.

Fire on a failed navigation too: §4.8.5 fires load for the error document, and
not firing leaves the page hung.

The deferral token comes from a process-wide counter, not a per-instance one.
The slab recycles instance addresses, so a callback holding a
`*runtime.Instance` can find a different element's state there; a
zero-initialised per-instance counter would match that stale state and
dispatch at an unrelated iframe.

**Takeaway**: **When an engine does synchronously what the spec does
asynchronously, the events still have to fire - and which deferral to use is a
measurement, not a reading of the spec. Whatever you pick, a callback reached
from the event loop rather than from V8 must open its own HandleScope before it
touches a Local, or it SIGTRAPs the whole file instead of failing a subtest.**

---

### Testing: The WebSocket servers are on EPHEMERAL ports, so `lsof :9001` proves nothing

**Date**: 2026-09-22
**Lesson**: `tests/wpt/config.json` pins the http and https ports and omits
`ws`/`wss`, so wptserve assigns those two at random on every start - one run
had `ws on port 62088` and `wss on port 62089`. Tests reach them through
`constants.sub.js` substitution, so that is not a defect. What it defeats is
the obvious probe: `lsof -iTCP:9001` is empty, and reads as "no WebSocket
server".

**What Happened**: two working websockets sweeps were killed as "doomed -
nothing is listening on the WebSocket port", on that probe alone. The runner
also spawns the server with `.stdout = .ignore, .stderr = .ignore`, so the
lines that would have shown the real ports were thrown away. Running
`python3 wpt.py serve --config config.json` by hand for thirty seconds with
its output kept showed them at once.

**Fix**: ask the server, not the port: `lsof -nP -a -p <pid> -iTCP
-sTCP:LISTEN`; any two ports outside 8000-9000 are ws and wss. Pin `ws`/`wss`
in `config.json` if a fixed port ever matters.

**Takeaway**: **A negative probe on a port you assumed is not evidence.** Run
the server by hand with its output visible before concluding a component is
missing.

---

### Workflow: `pgrep -f` matches the shell that is running it

**Date**: 2026-09-22
**Lesson**: `until ! pgrep -f wpt_runner_frozen; do sleep 30; done` can never
exit: `pgrep -f` matches the FULL command line of every process, and the
loop's own shell has "wpt_runner_frozen" in its command line.

**What Happened**: an agent wrote seven of these, sleeps from 30 to 120s, each
started because the previous one "had not finished yet". Its sweep had been
done for hours, its journals were final, its four commits were on its branch.
It reported nothing, was stopped, and its work was merged from its commit
messages. Then the command written to reap those loops -
`grep "[u]ntil ! pgrep"` - matched ITS OWN shell's command line and killed
the session's command mid-run. Same trap, minutes apart, from the other side.

**Fix**: match on the process name (`pgrep -x name`), or build the pattern at
runtime so the joined string is not in your own command line
(`pat='until ! pgrep -f wpt_runner_'; pat="${pat}frozen"`), and always
exclude `$$`. Better: wait on the artefact - a sweep is done when its journal
stops changing, a build when its output has an exit line.

**Takeaway**: **Wait on what the process WRITES, not on whether a string is
in the process table - the string is in yours too.**

---

### Testing: A subtest total is a count of RESULTS until you divide the fan-out out

**Date**: 2026-09-22
**Lesson**: Summing `passed+failed+timed_out+notrun` over the journal counts each
variant-partitioned file's subtests once PER VARIANT, not once.

**Why**: The runner executes a file once per implemented global **times** once per
declared `<meta name="variant">`, and `FileTally.add` sums every one of those runs
into a single journal line - by design, because a variant is not a resumable unit.
Separately, the variant never reaches `location.search`, so
`/common/subset-tests.js` computes `subTestStart=0, subTestEnd=Infinity` and
`subsetTest` registers EVERY test instead of the slice the variant names. The two
combine: a 24-variant file reports 24 tallies of its whole set.

**What Happened**: asked for "how many subtests are we targeting", the naive sum
gave **3,298,886**. The honest figure is **272,851** - 12x smaller. 25 files of
4,323 held 98.6% of the raw number, all of them `encoding/legacy-mb-*` codepoint
sweeps: `euckr-encode-href-errors-han.html` declares 23,097 subtests and reports
554,328, which is 23,097 x 24 exactly. A "% passing" built on that denominator
would have been 99% governed by 25 files, and one fix to one of them would have
swung it 17 points.

**Fix**: divide the reported total by the variant count. Variants *partition* a
file's subtests - `?1-1000` plus `?1001-2000` is one set split in two - so they
must not multiply it; globals DO multiply it, since `foo.any.html` and
`foo.any.worker.html` are separate URLs in MANIFEST.json with separate results.
The check that this is right rather than plausible: the division comes out EXACT
for **250 of the 251** multi-variant files that have reported anything, including
all 104 partial ones. `tools/wpt_progress.py:subtest_model` does it and the
report states the composition on the page.

**Two things this also means**, neither fixed here:

* Every variant-partitioned file is doing its whole sweep N times. That is why
  `euckr-encode-href-errors-han.html` charges 2,615s of wall time, and it is a
  plausible contributor to the ~1,090 TIMEOUTs.
* `location.search` is empty inside a test document. `Location.get_search` is
  correct, so the document URL is being set without its query - which silently
  disables every test that filters on its own variant, not just the subset ones.

**Takeaway**: **Before a tally becomes a denominator, ask how many times the thing
was counted. A sum over runs is a count of RESULTS; a denominator needs a count of
THINGS, and the ratio between them was 12x here with a green report either way.**

---

### Architecture: `Instance.init` sizes the state by the caller's type; `onObjectFreed` frees it by the vtable's

**Date**: 2026-09-22
**Lesson**: `Instance.init(allocator, StateType, vtable, ctx)` allocates
`@sizeOf(StateType)`; `gc_integration.onObjectFreed` frees
`vtable.state_size`. Pass a subtype's vtable with a parent's State and the
arena's size-class free list is poisoned, not leaked.

**Why**: `Node.cloneSingleNode` fell through, for every node type it did not
handle, to `Instance.init(allocator, State, node.vtable, ...)` - Node's State
under the node's own vtable. A cloned Document therefore had a `Node.State`
sized block (small class) that was later returned to the arena as Document's
1080 bytes (the 1024 class). The next `Document.InternalState` was carved from
that block and overlapped whatever lived after the small one; its neighbours'
ordinary writes zeroed the new document's allocator, and `Node.init` faulted
at 0x0 under `createElement`. The clone also had no registry state, so
`createElement` on it could only throw.

**What Happened**: three rounds of instrumentation, each ruling out a
theory that fit the symptom:

1. The generation stamp (previous lesson) - correct, and closed a different
   crash, but this document's callback saw its own generation.
2. Tagging `Document.init/deinit` and the Document registry - between the
   new document's init and the fault there was no deinit, no `remove`, no
   double free. The registry was not the actor.
3. Logging every arena pop and push with the block address named it in one
   run: `[onObjectFreed] DOC ... state=@X state_size=1080`, `push class=7 @X`,
   `pop class=7 @X`, `createIn ... block=@X`, then `[createElement]`
   `alloc_vtable=0x...` followed by `alloc_vtable=0x0` with **no allocator
   event between**. A block that changes with no allocator event is being
   written through somebody else's pointer, and "somebody else" is whoever
   owns the memory the undersized block overlaps.

A `dumpCurrentStackTrace(.{})` at `Instance.init` for `vtable.name ==
"Document"` then grouped 15 creations into 6 stacks; the 3 that never
reached `Document.init` were all `Node.cloneSingleNode`. Note the Zig 0.16
signature takes a `StackUnwindOptions` struct, not a start address.

**Fix**: DOM §4.4 "clone a single node" step 3 - the copy implements the same
interfaces as node - as typed branches: Document via `interfaces.Document.init`,
DocumentType via the owner's `DOMImplementation.createDocumentType`, Attr via
`createAttributeNS` + `set_value`, DocumentFragment via
`createDocumentFragment`. The fallthrough now returns `error.NotSupported`
rather than sizing a State it cannot know. Stated deviation: a cloned
Document keeps `Document.init`'s defaults for encoding, content type, URL,
origin, type and mode - those are Document internals with no interface
delegate to set them, and an impl-to-impl call is not allowed in new code.
`custom-elements/Document-createElement.html`: CRASH -> OK.

**Takeaway**: **A block that changes with no allocator event is being written
through a pointer that was never yours. Trace the BLOCK - every pop and push
of its address - before theorising about the object; and never hand
`Instance.init` a State type that is not the vtable's own.**

---

### Spec Compliance: The top-level `Location` and `document.URL` were never set

**Date**: 2026-09-22
**Lesson**: In every top-level test page `location.href` read `"about:blank"`,
`location.pathname` `"blank"`, `location.search` `""`, and `document.URL` `""`.

**Why**: `Context.zig` creates the window's Location at context init, and
`Location.init` parses `about:blank` into it; nothing ever updated it on
navigation (`Context.setUrl` ends in `_ = self.location_instance;`). Only
iframes called `Location.setURLFromString`. `document.URL` read
`Document.InternalState.url`, which the parser never set; the navigation
recorded its URL in the context entry (`context_manager.setDocumentUrl`) and
that is where it stayed - XHR read it from there, the DOM did not.

**What Happened**: it hid in plain sight because nothing threw. Two costs
were measured before anyone looked at the value: (1) every
`<meta name="variant">` file ran ALL of its tests on every variant, because
`/common/subset-tests.js` reads `location.search` to pick its slice - a
24-variant encoding file reported 554,328 subtests for 23,097 declared and
cost 2,615s of wall clock; (2) the progress report's "subtests passing" was
inflated 12x by the same fan-out. Every test deriving a URL from
`location.href` was running against nothing.

**Fix**: spec-shaped, no new impls-boundary calls. HTML §7.10.1: a Location's
url is its relevant Document's URL - so `Location.getURL` refreshes from
`interfaces.Window.get_document` -> `interfaces.Document.get_URL` (re-parsing
only when the string changes; the getter clones into the DOCUMENT's context
allocator, free it with that). HTML "create and initialize a Document object":
the document's URL is the navigation's, so a document that HAS a default view
takes the URL the context recorded (`instance.ctx.getEngineContextAs` -
its own context, not the current one, so `iframe.contentDocument.URL` is the
iframe's). A document with no view (createHTMLDocument, DOMParser) keeps its
own. Probe `tests/wpt/crane/location-probe.html?probe=1`: 0/4 -> 4/4.

**Takeaway**: **Probe the values a whole class of tests depends on before
reading their failures.** One four-line test page answered what a 2,000-file
scoreboard could not: the tests were not failing, they were never asked the
question.

---

### Workflow: When the design is in doubt, an engine that shipped it is one fetch away

**Date**: 2026-09-22
**Lesson**: Read how V8, WebKit, Blink or Gecko solved a problem before
inventing a mechanism for it. The specs say what; the engines say how.

**What Happened**: V8 collecting the wrapper of an unreferenced node destroyed
a node that was still in the tree (`tests/wpt/crane/gc-keeps-connected-nodes.html`
- `getElementById` returned null after two collections), and that dangling
child is what the teardown crashes in `location-protocol-setter-non-broken.html`
and `Node-cloneNode.html` were walking into. The first fix written was an
ad-hoc guard: "if the node has a parent, drop only the wrapper and keep the
instance". Ten minutes of reading gave the actual design:

- WebKit, `Source/WebCore/bindings/js/JSNodeCustom.cpp`:
  `JSNodeOwner::isReachableFromOpaqueRoots` keeps a node's wrapper alive while
  its tree root is an opaque root (`containsWebCoreOpaqueRoot(visitor, node)`),
  so a connected node's wrapper is NEVER collected, and a disconnected one
  survives only while held by a `GCReachableRef` or a custom-element reaction
  queue.
- Blink reaches the same outcome by tracing the wrapper through the node.
- V8's own `jsengines/v8/include/v8-embedder-heap.h` and `v8-traced-handle.h`
  document the roots API built for exactly this decision.

So the policy is "strong while connected, weak once removed" - identity and
expandos survive a GC, as they do in every browser - and the guard is the
safety net behind it, not the design. The two theories and three rounds of
instrumentation spent on the crash before that were spent on WHAT was
happening; none of them could have said what the right behaviour was.

**Fix**: the "Stuck on HOW" rule and its table, above.

**Takeaway**: **When you are naming a mechanism yourself, stop and check
whether Blink or WebKit already has a name for it. They usually do, and the
name comes with ten years of edge cases.**

