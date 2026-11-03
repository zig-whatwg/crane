# Working on Crane: the details behind AGENTS.md

Moved verbatim from AGENTS.md (2026-11-03). The core keeps each rule as one line and points here.

## What Crane is: the details

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

So **"framework X does not use this" is not a reason to leave something out**,
and neither is it a reason to stop halfway through an algorithm. That criterion
was used by mistake early in this work and produced two real defects: an
`addEventListener` options flatten that handled only the boolean form because
"React passes booleans", which made `addEventListener(t, fn, 2.3)` register as
a bubble listener when the spec says capture; and `navigation-api/` excluded
from the WPT worklist on the grounds that React and Phoenix do not need it.
When in doubt, implement what the spec says and let WPT report the gap - and
where the spec text and the browsers disagree, golden rule 2 decides: the
browsers win, unless they are only behind a newer spec.

**Stuck on HOW to implement something? Read an engine that already has.**
The specs say what; V8, WebKit, Blink and Gecko show how, and every problem
this engine meets - wrapper lifetime, handle ownership, teardown order, event
dispatch, parser state - was met and solved there first. Read them BEFORE
designing a mechanism, not after a theory has failed:

| Question | Where |
|----------|-------|
| V8's contract for an API (handles, weak callbacks, embedder roots, CHECKs) | `jsengines/v8/include/*.h` - V8 13.1 (the linked prebuilt), local; the doc comments ARE the contract. Source: `jsengines/v8/v8/` is a full checkout at a NEWER V8 (14.6 on 2026-10-19): read the linked version with `git -C jsengines/v8/v8 show 13.1.99:<path>` |
| How a browser binds the DOM to V8 | Blink: `third_party/blink/renderer/bindings/` and `platform/bindings/` (script_wrappable, dom_data_store, the GC controller) in https://github.com/chromium/chromium |
| The most readable DOM and bindings implementation | WebKit: `Source/WebCore/bindings/js/` (JSNodeCustom.cpp, JSDOMWrapper) and `Source/WebCore/dom/` in https://github.com/WebKit/WebKit |
| Implementations annotated with the spec's own step numbers | Gecko: `dom/base/`, `dom/bindings/`, `js/src/` via https://searchfox.org |

Fetch the file, read the function, cite it in the commit. Take the DESIGN,
never the code: the licences differ, and a copied function carries assumptions
about refcounting, tracing and threading that this engine does not share.

## Engine work

**Engine work** (V8 handle ownership, allocator lifetimes, teardown order, the
FFI boundary, build/codegen): there is no spec. Read the code, and prefer a
measurement over an assumption — `gc_bench`, `leaks --atExit`, the live-handle
counters. Guessing at ownership here has shipped use-after-frees twice.

## Doing a task: batching the gates

### Batch the expensive gates (the user, 2026-11-01)

Wall-clock time matters as much as tokens. A full `zig build test` is 30-45 minutes on a shared host, a
ReleaseSafe runner build about 12, and a sweep over an hour. Never pay those for a two-line change on its own.

- **Each change still gets its own cheap proof:** its targeted test fails first, then passes
  (`-Dtest-file=`, `--repeat`, a few WPT files).
- **Changes whose files and WPT directories don't overlap share ONE native gate, ONE runner build and ONE
  A/B** over the union of their directories. The directories keep the attribution, and each change is
  still its own commit.
- **Before starting any gate or run over 20 minutes,** look at what else is about to land, and batch it in
  instead of starting the next long job the moment this one ends.
- **Merge current main into your branch before you report.** If your gated tip's tree is the tree the
  integrator would merge, your gates stand and the merge needs no re-run.

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

## Clean up as you go: the details

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
