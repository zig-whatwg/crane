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

### Keep the progress report current

`wpt-results/progress.html` is how the 0.1 gate is watched. It is regenerated
from journals, and only from `wpt-results/*.jsonl` and
`wpt-results/<label>/*.jsonl` - ONE directory deep: it keeps the latest record
per file, ordered by the journal file's mtime, and accumulates them in
`tmp/wpt-progress-state.json`. A run whose journal lands anywhere else - a
scratchpad, `tmp/sweepNN/`, `wpt-results/<label>/<area>/` - never reaches the
page, and nothing says so: the headline simply does not move.

After every feature commit:

1. **Put its WPT runs where the report reads them.** Point `--output` at
   `wpt-results/<label>/` (e.g. `wpt-results/ab-<short-sha>/`), or copy a run's
   `journal*.jsonl` there afterwards with `cp -p` - `-p` keeps the mtime, and
   the mtime decides which result is latest. Several runs under one label go
   side by side as `journal.<area>.jsonl`, never in subdirectories.
2. **Regenerate:** `zig build wpt-progress -j2 --cache-dir /tmp/crane-z16-cache`.
3. **Report the headline** - blocking files and passing subtests from the page -
   in your summary.
4. **Keep the roadmap current.** The same page renders the engine roadmap from
   `docs/roadmap.toml`: the shared infrastructure to finish before feature
   areas go to parallel agents, the prerequisites for that, and the areas to
   hand out. When a commit moves a roadmap item, flip its `status` and add the
   commit to its piece's `progress`. Write no numbers there - the page measures
   blocking files per area, retained heap per file and unpushed commits itself.

And at least once per working session, or every few feature commits: a full
worklist sweep at HEAD, from a frozen copy of the runner, into
`wpt-results/sweep-<short-sha>/`, then regenerate. Targeted runs keep the areas
you touched current; only a sweep catches what moved elsewhere.

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
zig build test       -j2 --cache-dir /tmp/crane-z16-cache   # includes lint-impls
```

`zig build test` runs `lint-impls`, the impls-boundary ratchet (see "The impls
boundary"), so it fails on any new reference into an impl from code that does
not own it.

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

**The macOS SDK is chosen by `build.zig`, not by you.** Zig 0.16's bundled
libcxx does not compile against the macOS 27 SDK:

    use of undeclared identifier 'INFINITY'
      zig/0.16.0/lib/libcxx/include/__random/clamp_to_integral.h:47
    error: sub-compilation of libcxx failed

The 27 SDK's `math.h` leaves `INFINITY` to `<float.h>` when clang modules are
on, and the clang `float.h` Zig ships defines it only for C23 or a non-strict
`-std`. `useBuildableMacosSdk` in `build.zig` detects a 27+ default SDK and
builds against the newest `MacOSX26.x.sdk` the Command Line Tools still ship,
through a libc file it writes into the cache root. So a plain
`zig build wpt-runner -j2` works; `--libc <file>` overrides it.

- **Do not put an `xcrun` shim on PATH.** Zig asks
  `xcrun --sdk macosx --show-sdk-path`, and `/tmp/sdkshim` broke the build
  twice by answering that with the wrong SDK. `SDKROOT` does not help either -
  `xcrun` ignores it when `--sdk` is given. The old iOS-aware shim is parked at
  `/tmp/sdkshim.disabled-2026-09-21`.
- **If `INFINITY` comes back**, the Command Line Tools dropped the 26.x SDK.
  The durable fix is a Zig whose libcxx is SDK-27 clean.

All three must pass. For changes to V8 handle ownership, they are not
sufficient — see the regression protocol above.

---

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

### Names are the binding map

The binding finds an impl's functions by the names its generated file gives
them. There is no separate table saying which Zig function backs which member,
and none may be added - so the prefixes mean "exposed to script" and nothing
else:

| Member | Impl function |
|--------|---------------|
| regular attribute | `get_<name>`, `set_<name>` |
| operation | `call_<name>`; a further overload `call_<name>__<k>` (optional: until it exists, overload 0 runs) |
| static attribute | `get_static_<name>`, `set_static_<name>` - accessors of the interface object |
| static operation | `call_static_<name>` |
| constant | none - the generated interface answers it (`get_<NAME>()`) |

- **A private function never takes one of those prefixes.** Name helpers in
  camelCase.
- **A public one the generated file never calls is a map entry pointing
  nowhere**: a stale copy, a member that belongs to another type - or a
  broken map. Find out which before deleting it - see
  [An API name nothing binds is a bug report](docs/lessons/codegen-an-api-name-nothing-binds-is-a-bug-report-not.md).
- **Mixin members are inherited.** WebIDL `includes` makes a mixin's members
  the includer's own: on its prototype, under its brand check, with its
  instance as `this`. So the includer's generated interface takes each one
  from the mixin's generated module by alias -
  `pub const get_onclick = mixins.GlobalEventHandlers.get_onclick;` - and the
  member is implemented ONCE, in the mixin's impl. Nothing calls a mixin on its
  own, and an includer's impl never implements or overrides a member it
  includes (WebIDL forbids redeclaring one); behaviour the spec keys on the
  receiver, like a body element's window-reflecting handlers, is written in the
  mixin impl. The move is under way: a mixin joins
  `src/webidl/codegen/inherited_mixins.zig` in the commit that moves its
  implementation out of its includers' impls, and until then its includers'
  delegates still call their own impls.

`zig build lint-impls` (part of `zig build test`) checks this: strictly for
interface, namespace and helper impls and for the impls of inherited mixins
(bound by their generated module), and as a ratchet over
`tools/impls_naming_baseline.txt` for the other mixin impls, whose unrouted
functions predate the rule.

---

## The impls boundary

One rule, applied strictly: **state is reached through the impl that owns it.**
How depends on where the caller stands relative to the owner:

```
Impl -> itself or an ANCESTOR  ->  the ancestor's impl, directly
Impl -> any other type         ->  interfaces; no IDL member -> a src/dom/ hook
External code                  ->  interfaces; no IDL member -> a src/dom/ hook
```

1. **Your own type and your ancestors: go through the impl.** An impl IS its
   ancestors, so it reaches their state through their impls - Text, Attr,
   Document and the ParentNode mixin set a node's document with
   `NodeImpl.setOwnerDocument`, because every one of them is a Node. A mixin's
   ancestors are the ones every type that includes it shares (ParentNode is
   included only by Node types, so Node is its ancestor; Element is not).
   **Never use a `src/dom/` hook, or read an ancestor's generated state, to reach
   state your own hierarchy owns** - that is a detour around the impl.
2. **Another type, with an IDL member: the interface.**
   `interfaces.Node.get_ownerDocument(n)` from Range, not
   `NodeImpl.getOwnerDocument(n)`. IDL constants too:
   `interfaces.Node.get_DOCUMENT_NODE()`. Interfaces are the stable API and may
   add CEReactions, validation and other cross-cutting concerns; a direct impl
   call bypasses all of it.
3. **Another type, no IDL surface: a hook the owner installs.** Setting a node's
   document from DOMImplementation or the HTML parsers, joining a live range to
   its document from Document, setting up a traverser, making a collection live -
   the owning impl installs the step into a hook module in `src/dom/`
   (`node_document.zig`, `range_boundaries.zig`, `traversal.zig`,
   `live_collections.zig`, `abort_algorithms.zig`), each declaring its owners on
   a `//! lint-impls: hook for <Owner>` line. Add a hook module for a new step
   rather than an import. An ANCESTOR that needs a descendant's state - the
   AbstractRange getters reading a Range's boundary points - is in this case too:
   a base type cannot depend on its subclasses, so that is dispatch through a
   hook the subclasses install.

Never `@import("Other.zig")` a type that is not your ancestor in new code, and
never cast another impl's `_internal` to its `InternalState` and write through it.

**Both halves are checked, and `zig build test` runs the check:**

```bash
zig build lint-impls -j2 --cache-dir /tmp/crane-z16-cache                # fails on any new reference into an impl
zig build lint-impls -j2 --cache-dir /tmp/crane-z16-cache -- --update    # after paying debt down: record the lower baseline
```

`tools/lint_impls_boundary.zig` reads each impl's ancestry from the generated
interfaces (`ParentInterface`, `MixinTypes`) and enforces:

- **Strictly, with no baseline:** a hook used from inside the hierarchy that
  owns it - Text calling `node_document.set` - fails, naming file and line. The
  owner installing it, and naming its types (TitleCase members), are fine.
- **As a ratchet:** references into any impl that is not the file's own type or
  an ancestor, per file AND per `Impl.member`, against
  `tools/impls_boundary_baseline.txt`. A count that rises fails; so does a pair
  the baseline lacks - which is what catches a swap, one reference traded for a
  new one at the same total. Calling a non-ancestor's `init` counts: creating
  another type through its impl is a reference into it.

The generated layers (interfaces, mixins, namespaces, codegen) are skipped:
delegating to impls is their job.

The baseline only goes down. `--update` refuses to record an increase, and
editing the file by hand to make the check pass defeats the only thing that
stops this debt growing. The count is whatever the baseline says - **do not
write it down here.** The last hardcoded figure said "53 files, 245 instances"
and was 138/434 by the time anyone checked.

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
- Calling impls across the boundary in **new** code - `zig build lint-impls`
  (part of `zig build test`) enforces it
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

## Known debt — do not add to it

- References into impls from code that does not own them - recorded in
  `tools/impls_boundary_baseline.txt`, which may only go down
- API-named functions in mixin impls that nothing calls - recorded in
  `tools/impls_naming_baseline.txt`, which may only go down
- Non-Zig tools outside the WPT exception: `tools/update_impl_signatures.py`
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

## ⚠️ Record what you learn

When you learn something new or find a better way to do something, you **must**
record it. Add a lesson when you: discover a bug pattern that could recur, find
a better approach to a common task, learn from user feedback about correct
methodology, identify a systemic issue rather than a one-off, or establish a new
best practice.

A lesson is two things, committed with the work that taught it:

1. **A file**, `docs/lessons/<category>-<slug>.md`, in this shape:

   ```markdown
   # Category: Brief Lesson Title

   **Date**: YYYY-MM-DD
   **Lesson**: One-sentence summary.

   **Why**: The underlying issue.

   **What Happened**: Context, what went wrong, how it manifested.

   **Fix**: Step-by-step, with code if relevant.

   **Takeaway**: **Bold key insight** for future work.
   ```

2. **One line in the index below**, under its category:
   `- [Title](docs/lessons/<file>.md) - <the takeaway>`.

Categories: Architecture, Spec Compliance, Codegen, Testing, Debugging, Workflow.

Keep this file a rulebook. When a lesson becomes a rule, write the rule in its
section above and keep the lesson as the reason. When a lesson is superseded,
update its file with a dated **Status** line rather than leaving advice that
contradicts current practice.

---

## Lessons index

One line per lesson: its title and takeaway. The full write-up - why, what
happened, the fix - is the linked file. Open it when your work touches that
area; grep `docs/lessons/` for a symptom before theorising.

### Architecture

- [Local vs Global at the FFI seam](docs/lessons/architecture-local-vs-global-at-the-ffi-seam.md) - Every `v8_*` call returning a pointer allocates.
- [InstanceRegistry.createIn destabilises the DOM](docs/lessons/architecture-instanceregistry-createin-destabilises-the-dom.md) - A recycled address plus a recycled block is two aliasing bugs, not one.
- [A module cannot be test-linked if it is its own dependency](docs/lessons/architecture-a-module-cannot-be-test-linked-if-it-is-its-own.md) - "It has no V8 link" and "it is red" are different states.
- [An impl's return value is the JS return value, verbatim](docs/lessons/architecture-an-impl-s-return-value-is-the-js-return-value.md) - A wrong pointer that passes every guard is worse than one that fails.
- [A network-error response is not a failed call](docs/lessons/architecture-a-network-error-response-is-not-a-failed-call.md) - When a subsystem signals failure in-band, every consumer must check it explicitly; nothing will throw on their behalf.
- [A re-export does not mean the code is compiled](docs/lessons/architecture-a-re-export-does-not-mean-the-code-is-compiled.md) - In a tree with this many re-export roots, "it compiles" means only "something referenced it".
- [Allowlist, never blocklist, for ownership predicates](docs/lessons/architecture-allowlist-never-blocklist-for-ownership.md) - A blocklist over an open set of types is wrong by default — every type nobody thought of falls on the dangerous side.
- [A conversion that allocates nothing still looks allocated](docs/lessons/architecture-a-conversion-that-allocates-nothing-still-looks.md) - Ownership is a property of the conversion, not of the type.
- [A null parent is not proof of ownership](docs/lessons/architecture-a-null-parent-is-not-proof-of-ownership.md) - Ownership is a fact you record at the moment you take it, never a predicate you re-evaluate later - by then the object may be someone else's.
- [`var x = entry.field` is a copy, so clearing it clears nothing](docs/lessons/architecture-var-x-entry-field-is-a-copy-so-clearing-it.md) - A struct field read into a `var` is a copy; if you mean to clear the original, bind a pointer.
- [A struct that hands out interior pointers cannot be freed on its own schedule](docs/lessons/architecture-a-struct-that-hands-out-interior-pointers-cannot.md) - A structure that hands out pointers to its interior must outlive every holder.
- [The live window globals are installed natively, not through WebIDL](docs/lessons/architecture-the-live-window-globals-are-installed-natively.md) - Before concluding anything from a stub in `impls/`, find the binding that actually runs.
- [An empty `MaybeLocal` from a V8 callback is a promise, not a return value](docs/lessons/architecture-an-empty-maybelocal-from-a-v8-callback-is-a.md) - Every V8 API that can return "empty" documents what it wants alongside it.
- [`event_utils.dispatchEvent` invokes no listeners, on purpose](docs/lessons/architecture-event-utils-dispatchevent-invokes-no-listeners.md) - A stub whose comment explains why it is safe is describing a precondition, not a TODO.
- [A codegen-stub `init` silently produces a stateless node](docs/lessons/architecture-a-codegen-stub-init-silently-produces-a.md) - A stub `init` fails as `InvalidStateError` from somewhere else entirely, long after construction.
- [Interface getters clone and hand you the memory](docs/lessons/architecture-interface-getters-clone-and-hand-you-the-memory.md) - "The interface layer will free it" means the JS binding will.
- [A value the spec calls COMPUTED must not be cached](docs/lessons/architecture-a-value-the-spec-calls-computed-must-not-be.md) - When a spec says "the first X child", store nothing.
- [An inline-capacity string cannot be a hash-map key](docs/lessons/architecture-an-inline-capacity-string-cannot-be-a-hash-map.md) - Before storing a slice as a key, ask what it points INTO, not what it contains.
- [Whoever ends a weak arm inherits V8's Reset obligation](docs/lessons/architecture-whoever-ends-a-weak-arm-inherits-v8-s-reset.md) - "Release the arm" is two different operations depending on whether the handle outlives the call.
- [A timer callback has no HandleScope](docs/lessons/architecture-a-timer-callback-has-no-handlescope.md) - Ask who called you, not what you touch.
- [A stale weak callback's `Registry.remove` evicts the LIVE entry at a recycled address](docs/lessons/architecture-a-stale-weak-callback-s-registry-remove-evicts.md) - An address is not an identity, and a registry keyed on one will act on whoever lives there now.
- [A synchronous navigation still owes its load event](docs/lessons/architecture-a-synchronous-navigation-still-owes-its-load.md) - When an engine does synchronously what the spec does asynchronously, the events still have to fire - and which deferral to use is a measurement, not a reading of the spec.
- [`Instance.init` sizes the state by the caller's type; `onObjectFreed` frees it by the vtable's](docs/lessons/architecture-instance-init-sizes-the-state-by-the-caller-s.md) - A block that changes with no allocator event is being written through a pointer that was never yours.
- [A node's wrapper lives as long as its tree, and so does the node](docs/lessons/architecture-a-node-s-wrapper-lives-as-long-as-its-tree-and.md) - "JS no longer references the wrapper" and "nothing references the object" are different claims.
- [Named access on the Window object was dead three ways at once](docs/lessons/architecture-named-access-on-the-window-object-was-dead-three.md) - When a feature is fully implemented and still does nothing, look for more than one break in the path.
- [An object graph without tracing lives and dies as a unit](docs/lessons/architecture-an-object-graph-without-tracing-lives-and-dies.md) - Only allowlist a class whose own teardown touches nothing but its own slots.
- [No FFI returned the value a call threw](docs/lessons/architecture-no-ffi-returned-the-value-a-call-threw.md) - A catch you open after the throw catches nothing.
- [One handle kind per layer](docs/lessons/architecture-one-handle-kind-per-layer.md) - Know which handle kind you hold; the types will not tell you.
- [libcurl's CUSTOMREQUEST changes the method NAME, not the transfer](docs/lessons/architecture-libcurl-s-customrequest-changes-the-method-name.md) - A TIMEOUT with 0 ms wall time is the stall watchdog: the whole process was stuck, usually in a blocking C call.
- [A redirect is followed from the response in hand](docs/lessons/architecture-a-redirect-is-followed-from-the-response-in-hand.md) - A signature missing the spec's argument means the code is doing something else.
- [`on*` content attributes had never been implemented](docs/lessons/architecture-on-content-attributes-had-never-been-implemented.md) - When a directory hangs on an event, check that the handler is stored before checking that the event fires.
- [load and DOMContentLoaded were each fired twice](docs/lessons/architecture-load-and-domcontentloaded-were-each-fired-twice.md) - A handler that tolerates running twice hides a double fire.
- [V8 13.1 resolves static imports synchronously](docs/lessons/architecture-v8-13-1-resolves-static-imports-synchronously.md) - There is no HostLoadImportedModule for static imports in V8 13.1: imports resolve during `InstantiateModule`, so the loader (`src/html/module_script.zig`, 0a3e4fac4) walks and fetches the whole...
- [A timer's user_data must be cancelled by whoever frees it](docs/lessons/architecture-a-timer-s-user-data-must-be-cancelled-by-whoever.md) - A crash that moves between files in a sharded run and never reproduces alone is a callback from the previous file.
- [Every iframe had no event loop and no timer](docs/lessons/architecture-every-iframe-had-no-event-loop-and-no-timer.md) - A "no loop, run it now" fallback is a silent mode switch.
- [A build artifact tracked in git shadows the one the build makes](docs/lessons/debugging-a-tracked-build-artifact-shadows-the-build.md) - When a result makes no sense, check which artifact the process actually loaded, and from where.
- [Brand-check the receiver once, in the binding layer](docs/lessons/architecture-brand-check-the-receiver-once-in-the-binding.md) - An impl cannot tell it was handed another interface's state; only the binding can.
- [`SuppressMicrotaskExecutionScope` must live on the C++ stack](docs/lessons/architecture-suppressmicrotaskexecutionscope-must-live-on-the.md) - When a V8 scope object keys off its own address, the FFI takes a callback, not a handle.
- [A timer that keeps a Global<Context> keeps the whole page](docs/lessons/architecture-a-timer-that-keeps-a-global-context-keeps-the.md) - Growth that crosses pages is a leaked handle to something the next page does not need; a file that crashes only after N others is accumulated state, not the file.
- [`std.Random` is a view, not a generator](docs/lessons/architecture-std-random-is-a-view-not-a-generator.md) - Any `{ptr, vtable}` interface (Random, Allocator) must be built over state that outlives it.
- [Spec-internal hooks go through a dom module, not another impl](docs/lessons/architecture-spec-internal-hooks-go-through-a-dom-module-not.md) - No IDL member adds an abort algorithm to an AbortSignal, so pipeTo reaches it through `src/dom/abort_algorithms.zig`, which AbortSignal installs into - the same shape as `mutation.zig`'s...
- [A proxy with a `get` trap pays an invariant check on every read](docs/lessons/architecture-a-proxy-with-a-get-trap-pays-an-invariant-check.md) - Profile before optimising a binding: the cost was in V8's proxy semantics, not in our code.
- [An inherited attribute's impl reads state only its own interface writes](docs/lessons/architecture-an-inherited-attribute-s-impl-reads-state-only.md) - When a parent interface declares an attribute, check who writes the state its impl reads.
- [Inside a hierarchy, go through the impl - a hook there is a detour](docs/lessons/architecture-inside-a-hierarchy-go-through-the-impl-a-hook.md) - "Impls are private" is about other types.
- [Every frame ran the WebIDL stubs for setTimeout, rAF and fetch](docs/lessons/architecture-every-frame-ran-the-webidl-stubs-for-settimeout.md) - A hook with no installer is a feature with no caller.
- [An event the engine fires and nobody hears must still be freed](docs/lessons/architecture-an-event-the-engine-fires-and-nobody-hears-must.md) - Run one ordinary page under `CRANE_LEAK_TRACES=1` after any change that fires events.
- [A frame's load event has exactly one owner, and `window.document` is script's getter](docs/lessons/architecture-a-frame-s-load-event-has-exactly-one-owner-and.md) - Engine code asking about a frame must not use the getters script uses.
- [One event loop turn runs the tasks queued before it, and no more](docs/lessons/architecture-one-event-loop-turn-runs-the-tasks-queued-before.md) - A drain loop's bound is the queue length on entry, never "until empty." The second is a promise that nothing it runs will ever queue more.
- [A task fired into a worker from outside must end the worker's turn](docs/lessons/architecture-a-task-fired-into-a-worker-from-outside-must-end.md) - In a worker, "the callback ran" is not "the page heard about it." A worker's turn has an end, and every entry point into worker script has to reach it.
- [V8 owns WebAssembly, and it finishes work only when the embedder pumps](docs/lessons/architecture-v8-owns-webassembly-and-it-finishes-work-only.md) - An IDL file for a JavaScript-engine API is documentation, not something to bind.
- [The parser mirrored every character into the DOM, and a run of text cost O(N^2)](docs/lessons/architecture-the-parser-mirrored-every-character-into-the-dom.md) - When a file is slow, sample it before blaming the network or the test.
- [A threadlocal hook installed by the first owner makes results depend on process history](docs/lessons/architecture-a-threadlocal-hook-installed-by-the-first-owner.md) - Before trusting a lazily installed hook, ask whether its consumer can run before any owner exists.
- [A worker realm has no event loop, and a retired context marks a dead window realm](docs/lessons/architecture-a-worker-realm-has-no-event-loop-and-a-retired.md) - Before holding a realm across turns, find out who tells you it ended, and whether its isolate outlives that moment.
- [V1 SetPrototype on a global proxy replaces the global object](docs/lessons/architecture-v1-setprototype-on-a-global-proxy-replaces-the.md) - Use only the V2 prototype calls on a global proxy.
- [Before disposing an isolate, find everything the process keeps for one isolate at a time](docs/lessons/architecture-before-disposing-an-isolate-find-everything-the.md) - When a sweep-only crash follows a worker test, look for a process-wide cache that held the worker isolate's handle.
- ["Cleanup complete" must not forget that cleanup happened](docs/lessons/architecture-cleanup-complete-must-not-forget-that-cleanup.md) - A guard that forgets on completion guards nothing against a second caller.
- [Anything with network activity pending must hold its own wrapper](docs/lessons/architecture-anything-with-network-activity-pending-must-hold.md) - When moving work off the call stack, ask what keeps the object alive until the work finishes.
- [Single-threaded networking must send the request before the script ends, and let the timer decide timeouts](docs/lessons/architecture-single-threaded-networking-must-send-the-request.md) - "In parallel" in a spec means the network makes progress while script runs.
- [A defer that frees `self` runs before the earlier defers that read it](docs/lessons/architecture-a-defer-that-frees-self-runs-before-earlier-defers.md) - When a function frees its own receiver in a defer, every other defer that touches the receiver must be declared after it - or read what it needs into a local first.
- [An object wrapped in two realms must outlive both wrappers](docs/lessons/architecture-an-object-wrapped-in-two-realms-outlives-both.md) - Ask how many wrappers an object can have before freeing it when one dies.
- [An asynchronous frame navigation must hold its container's load event](docs/lessons/architecture-an-asynchronous-frame-navigation-must-hold-its-container-s.md) - Any engine work moved off the caller's stack that a document's load depends on must register as delaying the load event.
- [A feature reached only through its IDL setter never runs for markup](docs/lessons/architecture-a-feature-reached-only-through-its-idl-setter-never-runs-for.md) - If a behaviour lives behind an IDL setter, test it with markup before trusting it.
- [curl's header callback delivers every header block](docs/lessons/architecture-curl-s-header-callback-delivers-every-header-block.md) - Track header-block boundaries in the callback; a header line alone does not say which block it belongs to.
- [An object the engine makes for a Zig holder must be wrapped or pinned](docs/lessons/architecture-an-object-the-engine-makes-for-a-zig-holder-must-be-pinned.md) - Before you store a pointer to an Instance, decide whether the wrapper cache or a pin keeps it alive.
- [Erroring or closing a stream frees its source mid-call](docs/lessons/architecture-erroring-or-closing-a-stream-frees-its-source.md) - Any controller call can free the source that made it. Copy what you pass in first.
- [A [SameObject] cache is a native pointer V8 cannot see](docs/lessons/architecture-a-sameobject-cache-is-a-native-pointer-v8-cannot.md) - Any native pointer from one GC-managed object to another needs an edge V8 can see.
- [A setter and an operation converted the same type through different code](docs/lessons/architecture-a-setter-and-an-operation-converted-through-different-code.md) - When one WebIDL type is converted in two places, test the same value through both.
- [After DetachGlobal, the old context's Global() is the new Window's proxy](docs/lessons/architecture-after-detachglobal-the-old-context-s-global-is-the-new-window-s-proxy.md) - Take the handles you'll need for cleanup before you detach.
- ["Is this still its Window's document?" stops working once navigations make new Windows](docs/lessons/architecture-ask-the-document-whether-it-is-fully-active-not-its-window.md) - Ask the document whether it is fully active, not its Window.
- [A cache keyed on its source string must update the source on every write path](docs/lessons/architecture-a-cache-keyed-on-its-source-string-must-update-it-on-every-write.md) - Every writer of the value must also write its key.
- [A USVString getter's result is freed by the binding](docs/lessons/architecture-a-usvstring-getter-s-result-is-freed-by-the-binding.md) - A USVString getter returns memory the binding will free - always a copy, never a view.
- [A named setter interceptor on a prototype never runs for an instance](docs/lessons/architecture-a-named-setter-interceptor-on-a-prototype-never-runs-for-an-instance.md) - An interceptor on a prototype can serve reads; it cannot serve writes.
- [A task run into a worker needs the worker's isolate entered](docs/lessons/architecture-a-task-run-into-a-worker-needs-the-worker-s-isolate-entered.md) - A dead end written in a comment is a hypothesis; grep `docs/lessons/` for the symptom first.
- [A blocking handshake inside a timer turn stops the whole page](docs/lessons/architecture-a-blocking-handshake-inside-a-timer-turn-stops-the-whole-page.md) - Anything "in parallel" must advance one non-blocking step per turn.
- [A short `curl_ws_send` is the middle of a frame](docs/lessons/architecture-a-short-curl-ws-send-is-the-middle-of-a-frame.md) - A partial write is state, not an error.
- [An errdefer that outlives the handoff frees what the new owner will free](docs/lessons/architecture-an-errdefer-that-outlives-the-handoff-frees-what-the-new-owner-will-free.md) - End the errdefer scope where ownership moves.
- [An EventTarget subclass must init and deinit through EventTarget's impl](docs/lessons/architecture-an-eventtarget-subclass-must-init-and-deinit-through-eventtarget-s-impl.md) - An address-keyed side table needs its owner's deinit.
- [Frames and the top-level page parse through different drivers](docs/lessons/architecture-frames-and-the-top-level-page-parse-through-different-drivers.md) - When a feature works in a frame but not at top level, compare the two parser drivers first.

### Spec Compliance

- [The decoder reports the error; the caller picks the mode](docs/lessons/spec-compliance-the-decoder-reports-the-error-the-caller-picks.md) - When one decoder in a family passes a conformance file and its siblings do not, diff their contracts before their algorithms.
- ["Prepare the script element" had no insertion-steps caller](docs/lessons/spec-compliance-prepare-the-script-element-had-no-insertion.md) - When a directory of tests all hang on the same idiom, look for the algorithm that idiom triggers and ask who calls it.
- [Tree construction never received an EOF token](docs/lessons/spec-compliance-tree-construction-never-received-an-eof-token.md) - "The loop ended" and "the parser finished" are different claims.
- [A stub that returns `undefined` takes unrelated suites down with it](docs/lessons/spec-compliance-a-stub-that-returns-undefined-takes-unrelated.md) - A stub returning `undefined` is not a smaller version of the feature, it is a trap for its callers.
- [The top-level `Location` and `document.URL` were never set](docs/lessons/spec-compliance-the-top-level-location-and-document-url-were.md) - Probe the values a whole class of tests depends on before reading their failures.
- [No code path can fire a trusted event](docs/lessons/spec-compliance-no-code-path-can-fire-a-trusted-event.md) - "Fire an event" needs its own interface-level entry point, distinct from the script-facing `dispatchEvent`.
- [window.postMessage had never delivered a message](docs/lessons/spec-compliance-window-postmessage-had-never-delivered-a-message.md) - When a whole directory hangs on one API, call that API with the four plainest arguments before reading any test.
- [A relative iframe `src` never loaded, and three bugs hid behind it](docs/lessons/spec-compliance-a-relative-iframe-src-never-loaded-and-three.md) - Test a feature with the URL shapes the corpus actually uses.
- [A frame's parse skipped "the end" step 5, so no module script ran in a frame](docs/lessons/spec-compliance-a-frame-s-parse-skipped-the-end-step-5-so-no.md) - Every parser driver owes the whole of "the end".
- [A body that is always a pipe needs main fetch step 20](docs/lessons/spec-compliance-a-body-that-is-always-a-pipe-needs-main-fetch-step-20.md) - When bytes become a stream, "no body" and "empty body" become different states.
- [Evaluate a spec condition when the spec does](docs/lessons/spec-compliance-evaluate-a-spec-condition-when-the-spec-does.md) - A queued task sees the world after the event that queued it; record what the spec reads at the moment it reads it.
- [Infra's ASCII whitespace is not `std.ascii.isWhitespace`](docs/lessons/spec-compliance-infra-ascii-whitespace-is-not-std-ascii-iswhitespace.md) - Use Infra's whitespace set for web microsyntaxes; the standard library's includes VT.
- [A union argument reaches the impl in every JSValue shape](docs/lessons/spec-compliance-a-union-argument-reaches-the-impl-in-every-jsvalue-shape.md) - An impl that takes a raw JSValue owns the whole union conversion.
- [When removing a serialization, check which spec rule it was quietly satisfying](docs/lessons/spec-compliance-when-removing-a-serialization-check-which-rule-it-satisfied.md) - When removing a serialization, check which spec rule it was quietly satisfying.
- [A result the spec hands over from onComplete arrives in a task](docs/lessons/spec-compliance-a-result-handed-over-from-oncomplete-arrives-in-a-task.md) - A synchronous fetch does not make the spec's task synchronous; deliver the result where the spec does.
- ["Child text content" means Text children only](docs/lessons/spec-compliance-child-text-content-means-text-children-only.md) - Read the Infra/DOM definition of each text accessor; "child text content", "descendant text content" and textContent are three different things.

### Codegen

- [Callback FUNCTIONS cannot move to CallbackWrapper until the registry is real](docs/lessons/codegen-callback-functions-cannot-move-to.md) - When a change is mechanical but keeps getting reverted, the blocker is under it, not in it.
- [Raw codegen output is not `zig fmt`-clean, so regeneration looks like a 1,419-file change](docs/lessons/codegen-raw-codegen-output-is-not-zig-fmt-clean-so.md) - Format generated output before you diff it, or the diff is unreadable and a real change hides in it.
- [Check generated data against a second copy](docs/lessons/codegen-check-generated-data-against-a-second-copy.md) - The index generator hardcoded each encoding index's last pointer; jis0208 stopped at 7,939 of 11,103 and euc-kr at 17,919 of 23,749, so ~5,800 hanja could be neither encoded nor decoded.
- [An extended attribute the generator detects and never emits is silently ignored](docs/lessons/codegen-an-extended-attribute-the-generator-detects-and.md) - Grep the generator for every `is<ExtAttr>` helper's callers.
- [An API name nothing binds is a bug report, not only dead code](docs/lessons/codegen-an-api-name-nothing-binds-is-a-bug-report-not.md) - Before deleting an unbound function, ask why the map does not reach it.
- [WebIDL identifiers drop a leading underscore](docs/lessons/codegen-webidl-identifiers-drop-a-leading-underscore.md) - Grep the generated tables for names starting with `_` after any parser change.
- [Deduplicating operations by name deleted every overload](docs/lessons/codegen-deduplicating-operations-by-name-deleted-every.md) - Dedupe by signature, not by name, and read a hand-unrolled arity switch's `else` branch - it is an undocumented limit.
- [Generated behaviour is only as complete as the IDL](docs/lessons/codegen-generated-behaviour-is-only-as-complete-as-the-idl.md) - Before trusting generated behaviour, read the prose the IDL summarises.

### Testing

- [Regression-check handle changes with timers, not DOM](docs/lessons/testing-regression-check-handle-changes-with-timers-not.md) - Pick the regression suite that exercises the lifetime you changed, not the one that touches the same file.
- [`--parallel` can manufacture ERROR results; confirm a surprising number serially](docs/lessons/testing-parallel-can-manufacture-error-results-confirm-a.md) - An aggregate can move for reasons that have nothing to do with the change; a per-file transition table cannot.
- [One file can hang the runner past its own per-file ceiling](docs/lessons/testing-one-file-can-hang-the-runner-past-its-own-per.md) - A sweep's progress is what it has WRITTEN, not whether it is running.
- [A drain guard keyed on a boolean strands a second document](docs/lessons/testing-a-drain-guard-keyed-on-a-boolean-strands-a.md) - A guard against re-entrancy has to be as fine-grained as the state it protects, or it turns recursion into deadlock.
- [A subtest count can go DOWN because a test started testing something](docs/lessons/testing-a-subtest-count-can-go-down-because-a-test.md) - Subtest counts are not a monotone quality signal.
- [A directory argument is filtered through the runner's allowlist, and three 0.1 areas were not on it](docs/lessons/testing-a-directory-argument-is-filtered-through-the.md) - "No tests found" with exit 0 is a filter, not a fact.
- [The runner adopted a zombie as its server, because a zombie answers `kill(pid, 0)`](docs/lessons/testing-the-runner-adopted-a-zombie-as-its-server.md) - "The process exists" and "the process is doing its job" are different claims, and a zombie satisfies only the first.
- [The report was written after teardown, so a teardown crash erased the run](docs/lessons/testing-the-report-was-written-after-teardown-so-a.md) - Persist results before teardown; teardown is engine code and crashes like any other.
- [An exclusion pattern is a substring rule over the whole path](docs/lessons/testing-an-exclusion-pattern-is-a-substring-rule-over.md) - Anchor every exclusion pattern at a directory that can only mean what you meant.
- [The per-file ceiling does not bound the file](docs/lessons/testing-the-per-file-ceiling-does-not-bound-the-file.md) - Check liveness by the journal's mtime, not by the process - and give any unbounded phase an external deadline, because an in-process one cannot fire while the process is inside a blocking C call.
- [testharness.js reads its own timeout out of a document that does not exist yet](docs/lessons/testing-testharness-js-reads-its-own-timeout-out-of-a.md) - When a library derives a setting from state the host supplies out of order, the host has to hand it over explicitly.
- [The WebSocket servers are on EPHEMERAL ports, so `lsof :9001` proves nothing](docs/lessons/testing-the-websocket-servers-are-on-ephemeral-ports-so.md) - A negative probe on a port you assumed is not evidence.
- [A subtest total is a count of RESULTS until you divide the fan-out out](docs/lessons/testing-a-subtest-total-is-a-count-of-results-until-you.md) - Before a tally becomes a denominator, ask how many times the thing was counted.
- [Attribute a sweep-only difference with a side-by-side HEAD sweep](docs/lessons/testing-attribute-a-sweep-only-difference-with-a-side-by.md) - Run the control under the same conditions as the experiment.
- [A crash that only appears in a sweep is the previous file's teardown](docs/lessons/testing-a-crash-that-only-appears-in-a-sweep-is-the.md) - A `--from-file` sweep runs many files in one process, so a file's teardown code - sweeps that a single-file run exits before reaching - runs while the next file loads.
- [A subtest that passes because an earlier step throws the expected exception](docs/lessons/testing-a-subtest-that-passes-because-an-earlier-step.md) - When fixing one step turns `assert_throws_*` subtests red, they were testing a later step that does not exist yet - the drop is a map of it.
- [Reporting an exception turns a swallowed failure into a harness ERROR](docs/lessons/testing-reporting-an-exception-turns-a-swallowed-failure.md) - An OK that depended on an exception being dropped was never an OK.
- [Past the harness timeout, a file's status is a race; name each build](docs/lessons/testing-past-the-harness-timeout-a-file-s-status-is-a.md) - A file that blocks past the harness's 10 s (a 26 s synchronous fetch) reads OK in some runs and TIMEOUT in others - compare its subtests, not its status.
- [Only `tests/codegen/*_test.zig` runs](docs/lessons/testing-only-tests-codegen-test-zig-runs.md) - A red test you have never seen go red is not a test.
- [A test block runs only in a file the build collects](docs/lessons/testing-a-test-block-runs-only-in-a-file-the-build-collects.md) - Before trusting a test block, name the build target that runs it.
- [`timeout_multiplier` also stretches the test's own waits](docs/lessons/testing-timeout-multiplier-also-stretches-the-test-s-own.md) - A knob that scales one clock usually scales others with it.
- [Synchronous I/O behind an async API reorders script against the parser](docs/lessons/testing-synchronous-i-o-behind-an-async-api-reorders.md) - Before chasing a feature a whole file seems to lack, check what an API that should be asynchronous is doing synchronously.
- [A polyfill hides its impl's bugs until the day it is removed](docs/lessons/testing-a-polyfill-hides-its-impl-s-bugs-until-the-day.md) - When a native or polyfill gives way to a bound impl, read each of its getters twice before trusting it.
- [wpt serve: a file added after it starts 404s, and stopping it means stopping all of it](docs/lessons/testing-wpt-serve-a-file-added-after-it-starts-404s-and.md) - `lsof -t -iTCP:8000 | xargs kill` (the advice in the 404 lesson above) kills only the :8000 child.
- [A relative URL assigned to another window's location resolves against the caller](docs/lessons/testing-a-relative-url-assigned-to-another-window-s-location-resolves-against-the-caller.md) - Write the URL relative to the script doing the assigning.
- [A new Window per navigation multiplies whatever leaks per realm](docs/lessons/testing-a-new-window-per-navigation-multiplies-whatever-leaks-per-realm.md) - Compare the heap and native_contexts columns between the two binaries at the same file index before crediting a memory fix.
- [With synchronous fetches, no ordering model satisfies every timing test](docs/lessons/testing-with-synchronous-fetches-no-ordering-model-satisfies-every-timing-test.md) - When timing tests contradict each other under a synchronous engine, choose the common case and write the deviation down.

### Debugging

- [A diagnostic below the consumer's log level does not exist](docs/lessons/debugging-a-diagnostic-below-the-consumer-s-log-level-does.md) - Pick the level from the consumer's threshold, not the author's.
- [An instrument can confound its own result](docs/lessons/debugging-an-instrument-can-confound-its-own-result.md) - Keep the perturbation independent of the reporting cadence, and prefer a slope between adjacent samples over any per-unit average.
- [`leaks --atExit` is the tool; attaching never works](docs/lessons/debugging-leaks-atexit-is-the-tool-attaching-never-works.md) - If a memory tool looks broken, suspect your own teardown before the tool.
- [`v8::Module` CHECKs its own preconditions, and a failed CHECK is SIGTRAP](docs/lessons/debugging-v8-module-checks-its-own-preconditions-and-a.md) - Run the one crashing file by hand before theorising.
- [A two-subtest page took 37 seconds to exit, and none of it was the test](docs/lessons/debugging-a-two-subtest-page-took-37-seconds-to-exit-and.md) - Time the process, not the test.
- [Xcode updated itself mid-session and took the build's SDK with it](docs/lessons/debugging-xcode-updated-itself-mid-session-and-took-the.md) - An error that names a missing SDK file is about the machine, not the tree.
- [`ctx.getEngineContextAs(Isolate)` is a context cast to an isolate](docs/lessons/debugging-ctx-getenginecontextas-isolate-is-a-context-cast.md) - Three more impls survived the WebSocket and XHR fixes still casting a context pointer to an isolate (046399d52).
- [Redirect the runner's output into a pipe, never a file](docs/lessons/debugging-redirect-the-runner-s-output-into-a-pipe-never-a.md) - Before concluding instrumentation did not run, pipe the output.
- [Find what keeps a page alive: count native contexts, snapshot, attribute handles by site](docs/lessons/debugging-find-what-keeps-a-page-alive-count-native.md) - Every owned handle to anything in a page pins the whole page, and a page is released only when the last one goes.
- [A 101 response's headers are filed under `CURLH_1XX`](docs/lessons/debugging-a-101-response-s-headers-are-filed-under-curlh-1xx.md) - A header curl says is missing may be filed under another origin bit.
- [When one subtest in a file hangs and its siblings pass, compare what triggers each one](docs/lessons/debugging-when-one-subtest-hangs-compare-what-triggers-it.md) - Before blaming the feature, diff what triggers the passing and the hanging subtests.

### Workflow

- [`pgrep -f` matches the shell that is running it](docs/lessons/workflow-pgrep-f-matches-the-shell-that-is-running-it.md) - Wait on what the process WRITES, not on whether a string is in the process table - the string is in yours too.
- [When the design is in doubt, an engine that shipped it is one fetch away](docs/lessons/workflow-when-the-design-is-in-doubt-an-engine-that.md) - When you are naming a mechanism yourself, stop and check whether Blink or WebKit already has a name for it.
- [Run a sweep from a frozen copy of the runner](docs/lessons/workflow-run-a-sweep-from-a-frozen-copy-of-the-runner.md) - A sweep's result belongs to the binary its children exec.
- [Freeze the tree while a test run compiles](docs/lessons/workflow-freeze-the-tree-while-a-test-run-compiles.md) - Under load, `zig build test` reads sources for ~20 minutes - an edit landing in that window is compiled into some test binaries and not others.
- [A rule with no check that passes today is a suggestion](docs/lessons/workflow-a-rule-with-no-check-that-passes-today-is-a.md) - A rule needs a check that passes today and fails on regression.
- [Tools are Zig, and so are their gates](docs/lessons/workflow-tools-are-zig-and-so-are-their-gates.md) - Write the tool in the language the repo builds with, tests first.
- [WindowOrWorkerGlobalScope is inherited; its includer state goes through `dom.global_settings`](docs/lessons/workflow-windoworworkerglobalscope-is-inherited-its.md) - A mixin with includer state is still implemented once.
- [Never overwrite a binary macOS has already run; remove it first](docs/lessons/workflow-never-overwrite-a-binary-macos-has-already-run.md) - Exit 137 before the first line of output is code signing, not the engine.
- [Build after each lane merge - two clean merges can make a broken tree](docs/lessons/workflow-build-after-each-lane-merge.md) - "Each branch is green" says nothing about their merge.
- [lint-impls counts every usage once per local alias](docs/lessons/workflow-lint-impls-counts-every-usage-once-per-alias.md) - Before binding a non-ancestor impl in one more function, count the file's existing bindings.
