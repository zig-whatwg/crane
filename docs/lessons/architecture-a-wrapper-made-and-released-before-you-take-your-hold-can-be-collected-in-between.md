# Architecture: A wrapper made and released before you take your hold can be collected in between

**Date**: 2026-09-29
**Lesson**: Take the hold in the same step that makes the wrapper. `Realm.wrap(x)` then `clone(w)` leaves a window in which nothing holds `x`'s wrapper, and any allocation inside it can collect it.

**Why**: `streams_js.Realm.wrap` makes an object's wrapper and releases its own hold at once. That is correct for a streams-graph object, because the wrapper cache keeps that wrapper strongly for the realm's life (`wrapper_cache.isStreamsGraphObject`). An AbortController's or an AbortSignal's wrapper is weak. streams_writable.setUpController did `if (realm.wrap(ac)) |w| controller.abort_keepalive[0] = js.clone(w)`. The clone is the hold, and its own cache-hit path allocates (`v8_GetGlobalPrototype`), so a collection could land between the two calls, free the AbortController, and leave the clone's `SetPrototype` loading through a freed Global.

**What Happened**: encoding/streams/decode-bad-chunks.any.js went from OK 0/10 to CRASH, but only in its worker variant, on the reflection lane. It bisected to da2d7ee90, "every attribute is a real accessor", a change with nothing to do with streams. It had removed the lazy getter's leaked Context Globals and changed allocation patterns enough to move a collection into the window, deterministically. Main, still leaking, did not crash. Two theories went first: a stale realm and a borrowed context disposed. A trace of every wrapper return and context-manager entry settled it: one live ContextData throughout, and the crash inside the clone of a just-wrapped AbortController. An in-process repro (a worker realm, 64 rounds of streams, `--stress-compaction`) stayed green: a release V8 has no `--gc-interval` (it needs `V8_ENABLE_ALLOCATION_TIMEOUT`), so the WPT file, run serially, is the red. This is the fourth leak-hides-a-use-after-free in the lane's batch.

**Fix**:
1. Take each keepalive in one step: `js.clone(.{ .value = .{ .instance = ac }, .realm = realm.ctx })`, the same for the signal.
2. `Realm.wrap` refuses anything outside `streams_js.streams_graph_classes` (`error.NotAStreamsGraphObject`, a checked branch in every build), and `wrapper_cache.isStreamsGraphObject` reads that same list. The next caller can't reopen the gap. tests/v8/streams_wrap_test.zig pins it.

**Takeaway**: **A wrapper nobody holds can be collected at the next allocation. Make the wrapper and take the hold in one step, and make any "make and release" helper refuse the objects it cannot hold.**
