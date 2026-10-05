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

**Specs are cached in `specs/`, and kept fresh** (the user, 2026-10-02). A spec
you need that is not there: fetch it and save it (`specs/get <url> <dir>`:
`specs/w3c/` for W3C, WICG and CSSWG drafts, `specs/whatwg/` for WHATWG), as its
own commit. A cached spec six months old or more: compare it with upstream before
relying on it, and update it when a newer version exists, as its own commit.
`specs/whatwg/` is gitignored (local only; worktrees link it). `specs/idl/` is
different: a pinned webref snapshot that codegen depends on, updated only by the
procedure in specs/idl/WEBREF.md.

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

**A sweep-only crash is fixed only when counts say so.** A plausible mechanism with a green unit test is
not proof that it caused a crash seen only in sweeps. Claim it fixed with a same-list comparison: main's
runner crashing k of N single-process runs of the list that preceded the crash, yours 0 of N, N at least 6.
Otherwise it is unproven and stays open (2026-09-30: the WebSocket pump-token use-after-free was real, fixed,
and not the sweep crash - main 1/6, the fixed tip 4/6).

### Keep the progress report current

**The 0.1 gate: no file in the worklist blocks.** A file blocks when it times
out, errors or crashes, or when its harness finishes (OK) but none of its
subtests passes (`NONE-PASSED`, `gate_status` in `tools/wpt_progress.py`). "OK"
says only that the page ran to its end; 1,053 files were OK with nothing passing
when this rule was added (2026-09-30). Report blocking files by this rule, and
beside the headline subtest rate report the rate outside `encoding/` and the mean
per-file rate, which the page prints: `encoding/` holds most of the subtests.

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
2. **Regenerate:** `zig build wpt-progress -j2 --cache-dir ~/Library/Caches/crane-z16-cache`.
   `wpt-progress` also regenerates Crane's public results site
   (tools/wpt_site/generate.zig, published at https://zig-whatwg.github.io/crane/) into
   `wpt-results/site/`, and when that is the `gh-pages` worktree it commits there as
   "results: generation <n>, Crane <sha>". Push `gh-pages` with main
   (`git push origin main gh-pages`). `zig build wpt-site -- --out=<dir> --no-commit` writes
   a copy anywhere.
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

**A test directory is one executable.** `zig build test` compiles each
`tests/<dir>/` as ONE test binary, from a root build.zig generates
(`tests/<dir>/.all_tests.zig`, gitignored) - a new `*_test.zig` joins it with
no list to edit. So a test file shares its process with its directory's other
files: never assume yours is the first to start V8, initialise a per-thread
manager, leave no isolate entered, or set a V8 flag (V8 freezes its flags when
it starts; setting one after is a fatal CHECK). A test that needs a fresh
per-thread state runs its body on a `std.Thread` of its own. One file alone,
for a quick red/green:
`zig build test -Dspec=<dir> -Dtest-file=tests/<dir>/foo_test.zig -j2`.

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
zig build wpt-runner -j2 --cache-dir ~/Library/Caches/crane-z16-cache   # the one artifact WPT needs
zig build test       -j2 --cache-dir ~/Library/Caches/crane-z16-cache   # includes lint-impls
```

`zig build test` runs `lint-impls`, the impls-boundary ratchet (see "The impls
boundary"), so it fails on any new reference into an impl from code that does
not own it.

**Local builds use `--cache-dir ~/Library/Caches/crane-z16-cache`, never a cache in `/tmp`.** macOS
deletes `/tmp` files untouched for three days (`com.apple.tmp_cleaner`, nightly at 00:00), and Zig trusts a
cache hit without re-checking its output, so a half-pruned cache entry stays a "hit" with files missing: on
2026-10-02 it made the iOS build fail with `'mbedtls/version.h' file not found` and looked like a build.zig
regression ([lesson](docs/lessons/workflow-a-zig-cache-in-tmp-is-pruned-by-macos-and-zig-still-trusts-it.md)).

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
specs/idl/            334 webref .idl files, committed, pinned (specs/idl/WEBREF.md)
specs/supplementary/  Crane's own definitions (7 files)
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

Regenerate - **one invocation, both sources, one model**:

```bash
zig build codegen -- --dest-root src/webidl/
```

With no source named, codegen reads `specs/idl` and `specs/supplementary`
together, so a name in one resolves against the other (`typedef Window
WindowProxy` needs Window) and every `root.zig` lists both. Its output is
`zig fmt`-clean, so `git status` after a regeneration shows only real changes.
Never regenerate from one source alone: that run resolves against that source
only and rewrites every root with its entries.

The model does not depend on the order files are read in (`ir.zig`,
"Merging"): every partial definition merges into its definition, members go
definition first, then partials by (file name, position), and overloads are
numbered in that order. Two non-partial definitions of one name are an error
unless `src/webidl/codegen/duplicates.zig` names the definer (from webref's
curated idlnames); codegen stops and says so.

**`zig build codegen-check`** (part of `zig build test`) regenerates the whole
tree from scratch into a temporary directory and compares it byte for byte with
the committed generated directories. A hand-edited generated file, an IDL or
codegen change committed without its regeneration, and a stale generated file
all fail it, and it prints the command above. `specs/idl` is a pinned webref
snapshot: update it only by the procedure in specs/idl/WEBREF.md.

When codegen behaviour is in question, **delete the generated directories and
regenerate from scratch.** Partial regeneration hides systemic issues — that is
how a parent-vs-child signature bug stayed hidden behind 12 "unrelated" type
mismatches. `codegen-check` does exactly that against the committed tree; then
build (`zig build wpt-runner -j2`) to confirm no interface/impl signature drift.

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

**An interface's impl is reached ONLY through that interface's own generated
file. Nothing else references it - no other impl, not an ancestor's impl, not
src/dom, src/html, src/browser, the engine adapter, tools or tests.** (The
user's rule, 2026-09-29. It replaces the old exception that let an impl call its
ancestors' impls directly.)

```
Anything -> an IDL member of any type  ->  interfaces.X.<member>
Anything -> a step with no IDL member  ->  a src/dom hook the owning impl installs
The generated interface X.zig          ->  its own impl (the one allowed reference)
```

1. **IDL members: the interface.** `interfaces.Node.get_ownerDocument(n)`, never
   `NodeImpl.getOwnerDocument(n)` - from Range, from Text (Node's own
   descendant), from anywhere. IDL constants too: `interfaces.Node.get_DOCUMENT_NODE()`.
   Interfaces are the stable API and carry CEReactions, validation and the other
   cross-cutting concerns; a direct impl call bypasses all of it.
2. **No IDL member: a hook the owner installs.** Setting a node's document,
   joining a live range to its document, setting up a traverser, making a
   collection live, an element's form reset steps - the owning impl installs the
   step into a hook module in `src/dom/` (`node_document.zig`,
   `range_boundaries.zig`, `traversal.zig`, `live_collections.zig`,
   `abort_algorithms.zig`, ...), each declaring its owners on a
   `//! lint-impls: hook for <Owner>` line. Callers call the hook and never name
   the impl. Add a hook module for a new step rather than an import. This holds
   for a type's own descendants too: Text sets its node document through the
   hook, not through NodeImpl.
3. **Shared helpers do not live in `src/webidl/impls/`.** A helper that serves
   several types goes in `src/dom/`, `src/html/` or its subsystem, and reaches
   types through interfaces and hooks like any other code.

Never `@import("impls")` or name an `XImpl` outside the generated layers in new
code, and never cast another type's `_internal` to its `InternalState`.

**Existing references are debt, not precedent.** About 200 files outside the
generated layers still reference impls (most of them impls reaching ancestors,
which the old rule allowed). A change that touches such a line converts it.

**Checked by `zig build lint-impls`** (part of `zig build test`), counting ancestors since 1a94e0043:

```bash
zig build lint-impls -j2 --cache-dir ~/Library/Caches/crane-z16-cache                # fails on any new reference into an impl
zig build lint-impls -j2 --cache-dir ~/Library/Caches/crane-z16-cache -- --update    # after paying debt down: record the lower baseline
```

`tools/lint_impls_boundary.zig` counts references into impls per file AND per
`Impl.member` against `tools/impls_boundary_baseline.txt`. A count that
rises fails; so does a pair the baseline lacks - which catches a swap. The
`//! lint-impls: hook for <Owner>` line is documentation - it names who installs
the hook; the tool does not parse it (its in-hierarchy hook check went with the
ancestor exception, 1a94e0043). The
generated layers (interfaces, mixins, namespaces, codegen) are skipped:
delegating to impls is their job. `--rebase-for-rule-change` exists for one purpose: re-recording the
baseline when the RULE changes (it was used once, when ancestors started to count); a code change
never uses it.

The baseline only goes down. `--update` refuses to record an increase, and
editing the file by hand to make the check pass defeats the only thing that
stops this debt growing. The count is whatever the baseline says - **do not
write it down here.**

---

## The engine boundary

**Crane's JavaScript engine is an adapter, and the protocol is the only way to
reach it.** V8 is one implementation, statically linked on desktop and server;
on iOS Crane links the system JavaScriptCore dynamically instead. Behaviour may
differ between targets only where the difference is declared - never by
accident.

The protocol is the `engine` module, `src/runtime/engine_protocol.zig`. Its
signatures and doc comments are the contract; build.zig binds it, as
`engine_impl`, to the adapter `-Dengine=v8|jsc|quickjs` selects, so dispatch is
static. Whether an adapter links its engine statically (V8) or dynamically
(JavaScriptCore on iOS) is the adapter's business; the protocol does not change.
What it is: [docs/engine-protocol.md](docs/engine-protocol.md). How to move code
onto it: [docs/engine-protocol-recipes.md](docs/engine-protocol-recipes.md), a
recipe per intent.

```
src/runtime/engine_protocol.zig      THE PROTOCOL: module "engine", one pub inline fn per operation
src/runtime/engines/v8/              the V8 adapter: protocol.zig and protocol_*.zig (the operations),
                                     v8_wrapper.cpp, ffi.zig, conversions, the wrapper cache, context_manager
src/runtime/engines/{jsc,quickjs}/   the other adapters' protocol.zig
tests/runtime/protocol_test_adapter.zig   the engine-less adapter the runtime-tier tests bind
tests/v8/                            the V8 adapter's tests
everything else                      `const engine = @import("engine");`, runtime.Instance,
                                     runtime.JSValue, runtime.Context
```

1. **V8 types and calls live only in the adapter.** Outside
   `src/runtime/engines/v8/` and `tests/v8/` - impls, src/html, src/dom,
   src/fetch, src/browser, src/websocket, streams, the parsers, tools - there
   is no `@import("v8")`, no `v8_*`, and no Isolate, Global, Local or
   HandleScope. The generated WebIDL interfaces are engine-neutral comptime
   tables the adapter consumes; codegen never emits an engine call.
2. **Everything else reaches the engine through the protocol:** `engine.op(...)`,
   no function pointers, no optional unwrapping. **Every `pub inline fn` in
   engine_protocol.zig is an operation**, and a comptime check makes each
   adapter declare each one with exactly its types - a missing or mis-typed
   operation is a compile error. Helpers built over operations are plain
   `pub fn`s.
3. **Ownership is in the types.** A `JSValue` parameter is borrowed for the
   call. What the caller must release has an owning type - `engine.Owned`
   (`release()` or `take()`, exactly once), `Completion`, `CallbackFunction`,
   `CallbackInterface`, `PromiseCapability` - and its declaration says so.
   Nothing crosses the seam as an untyped engine pointer or with a flag saying
   who frees it. "Every `v8_*` return is owned" is an adapter-internal rule.
4. **A platform object converts in its relevant realm.** Every operation turns
   an `.instance` into its wrapper in `instance.ctx`, whichever realm it
   entered. Results are made in the current realm, `engine.currentRealm()` -
   null outside script, never "whatever context is entered".
5. **Capabilities are tri-state comptime constants.** `engine.capabilities.X`
   is `.native`, `.emulated` or `.unsupported`. A gated operation compiles only
   inside `if (engine.capabilities.X != .unsupported)`, and the host implements
   the declared fallback for the rest; nothing assumes V8. The no-snapshot
   startup path keeps working, because JavaScriptCore runs on it.
6. **A new engine need is a new protocol operation, named after the spec
   concept** - an ECMAScript abstract operation, a WebIDL or HTML algorithm -
   or, where there is no spec, after the engine concern. Never a pass-through
   with a V8-shaped signature: if the JavaScriptCore C API could not implement
   it, it is shaped like V8. The integrator owns engine_protocol.zig; request
   the operation the way you request a grant. It lands with its V8
   implementation, entries in the JavaScriptCore, QuickJS and test adapters
   (`error.NotSupported` where they cannot answer), a tests/v8 test with values
   made the way the binding makes them, and its line in docs/engine-protocol.md.
7. **The runtime Engine table is gone** (deleted with the final cleanup, f84096c88).
   Nothing reaches the engine through a function-pointer table: the runtime
   tier itself imports `engine` and calls the protocol (releasing an unwrapped
   instance is `engine.hasWrapper`, [PutForwards] is the protocol's Set). Do
   not bring a table back to break an import cycle - the runtime <-> engine
   cycle is the same shape as the facade <-> adapter one and builds.
8. **Existing debt is paid file by file.** Editing a file that makes direct V8
   calls or table calls means moving that file onto the protocol in the same
   change, by its recipes.

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
[Crane's JavaScript engine is an adapter](docs/lessons/architecture-the-javascript-engine-is-an-adapter.md);
why the seam is a protocol designed whole:
[Design the protocol before migrating](docs/lessons/architecture-design-the-protocol-before-migrating.md).

---

## Global state

**Crane runs isolated instances (Browsers) and every worker on their own threads, so state has an
owner: the process, a Browser, a Tab, an agent or a realm** - never a thread, never "whoever got
here first". The model and the rules for new state are in [docs/instances.md](docs/instances.md);
read it before adding state.

1. **No new `threadlocal` and no new container-level `var`** (function statics included). Put the
   state on the object that owns it, or reach it through the realm you run in.
2. **A hook is installed once, at process start**, from its owner's `installHooks()` - never lazily
   in `init`, never on first use, never by making a throwaway object.
3. **Checked by `zig build lint-global-state`** (part of `zig build test`;
   tools/lint_global_state.zig) against `tools/global_state_baseline.txt`, per file and qualified
   name. A count that rises fails, a key the baseline lacks fails, and the baseline only goes down
   (`-- --update` records a lower count). Two narrow exceptions, both reviewed at merge: a NEW key
   whose declaration has a `// process-wide: <why>` line directly above it (state that genuinely
   is one per process - say why it holds with many instances on many threads), and
   `-- --rename '<old>' '<new>'` for a same-file rename with the same kind, declaration and count.
   Never edit the baseline by hand. Report its total beside the engine-boundary total.

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

Build caches are the big one. `~/Library/Caches/crane-z16-cache` reached **31 GB** in a
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

---

## When in doubt

1. **Have you committed recently?** If you have working changes, commit them now.
2. **Creating files?** `tmp/`, unless asked otherwise.
3. **Which subsystem?** Check the file path and imports.
4. **Spec work?** Read the complete section from `specs/whatwg/<spec>.md` or `specs/w3c/<spec>.md` (fetch it there first if it is missing or six months old).
5. **Engine work?** Read the code and measure.
6. **Check dependencies** in `src/` before mocking anything.
7. **Look at existing tests** for patterns in similar subsystems.
8. **Inventing a mechanism?** Check how V8, WebKit, Blink or Gecko do it
   first - see "Stuck on HOW" above. If they have a name for it, use theirs.

---

## WHATWG specifications

| Spec | URL | Local |
|------|-----|-------|
| URL | https://url.spec.whatwg.org/ | `specs/whatwg/url.md` |
| Encoding | https://encoding.spec.whatwg.org/ | `specs/whatwg/encoding.md` |
| Streams | https://streams.spec.whatwg.org/ | `specs/whatwg/streams.md` |
| Infra | https://infra.spec.whatwg.org/ | `specs/whatwg/infra.md` |
| WebIDL | https://webidl.spec.whatwg.org/ | `specs/whatwg/webidl.md` |
| Console | https://console.spec.whatwg.org/ | `specs/whatwg/console.md` |
| MIME Sniff | https://mimesniff.spec.whatwg.org/ | `specs/whatwg/mimesniff.md` |
| Fetch | https://fetch.spec.whatwg.org/ | `specs/whatwg/fetch.md` |
| DOM | https://dom.spec.whatwg.org/ | `specs/whatwg/dom.md` |
| HTML | https://html.spec.whatwg.org/ | `specs/whatwg/html.md` (parsing chapter alone: `specs/whatwg/html/parsing.md`) |

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

2. **One line in [docs/lessons/README.md](docs/lessons/README.md)**, under its category:
   `- [Title](<file>.md) - <the takeaway>` (the README's links are relative).

Categories: Architecture, Spec Compliance, Codegen, Testing, Debugging, Workflow.

Keep this file a rulebook. When a lesson becomes a rule, write the rule in its
section above and keep the lesson as the reason. When a lesson is superseded,
update its file with a dated **Status** line rather than leaving advice that
contradicts current practice.

---

## Lessons index

The index - one line per lesson, its title and takeaway - is
[docs/lessons/README.md](docs/lessons/README.md). It is kept out of this file
because every agent re-reads this file on every call.

- **Starting a batch:** your brief names the lessons chosen for its work. Read
  those files before you design anything.
- **Stuck on a symptom:** grep `docs/lessons/` for it before theorising, and
  read your area's section of the index.
