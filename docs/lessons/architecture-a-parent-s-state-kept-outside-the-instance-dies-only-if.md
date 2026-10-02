# Architecture: A parent's state kept outside the instance dies only if the impl chains to the parent's deinit

**Date**: 2026-10-01
**Lesson**: EventTarget keeps every target's listeners in a process-wide
registry keyed by instance address, and only EventTarget's deinit removes an
entry. An impl that makes its instance with `runtime.Instance.init` instead of
chaining to its parent's init never runs that deinit either, so the listeners
outlive the object: they leak for the realm's life, the next object the slab
puts at that address inherits them, and a worker's are released at the
browser's end into the worker's disposed isolate.

**Why**: `call_addEventListener` makes the entry lazily for a target that has
none, so a stub "works" until its object goes. 236 impls of EventTarget's
descendants were stubs or hand-written impls of that shape (EventSource,
OffscreenCanvas, Performance, the IDB requests, MediaQueryList, Notification,
the Audio, Sensor and Bluetooth stubs ...).

**What Happened**: a sweep shard (chunk aac of the 10,035-file baseline) died
at its EXIT - `Browser.deinit` -> `cleanupAllDomRegistries` ->
`EventTarget.cleanupAllRemainingInternal` -> `NodeSpace::Release` on garbage -
after every one of its files had been journalled, so no journal record showed
it; only sweep.log did. Bisecting the shard's 63-file tail under
`MallocScribble=1` (which turns the read of freed V8 node memory into a
deterministic SIGSEGV at 0x5555...556d, or V8's "Check failed:
node->IsInUse()") named eventsource/format-bom.any.js, whose worker half adds a
listener to an EventSource. Without scribble the crash came and went with
whether the slab had handed the EventSource's address to a chained
EventTarget, whose init overwrote the stale entry.

**Fix**: EventSource chains through `interfaces.EventTarget.initWithState` and
`interfaces.EventTarget.deinit` (Keyboard.zig's pattern). For the rest, an
entry made lazily records its realm and slab generation: its realm's end
releases it (an unloading cleanup step, while the agent lives), and a stale one
is dropped before a new object at the address can see it - the generation part
INTERIM until every EventTarget impl chains. Red tests:
crane/c4-worker-listener-on-stub-target.html and
crane/c4-lazy-event-target-entries.html.

**Takeaway**: **An impl that does not chain to its parent's init and deinit
leaves the parent's out-of-instance state behind. And a crash at a process's
end is in no journal: grep the sweep log for Segmentation, Check failed and
panic, and replay the shard under MallocScribble=1.**
