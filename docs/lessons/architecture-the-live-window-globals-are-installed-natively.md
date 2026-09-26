# Architecture: The live window globals are installed natively, not through WebIDL

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
module. Per the re-export lesson ([architecture-a-re-export-does-not-mean-the-code-is-compiled](architecture-a-re-export-does-not-mean-the-code-is-compiled.md)), neither was even analysed.

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
