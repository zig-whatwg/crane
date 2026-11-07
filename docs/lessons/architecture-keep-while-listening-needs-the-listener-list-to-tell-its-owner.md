# Architecture: An object kept "while it has listeners" needs its listener list to tell its owner - and the flag that asks must cost ordinary targets nothing

**Date**: 2026-11-07
**Lesson**: A spec rule like "MUST NOT be garbage collected if it has an event listener whose type is change" needs two things Crane lacked. EventTarget has to report changes to its listener list, and the owner has to keep exactly while the rule holds and release at every step that ends it. Report only to targets whose owner asked, through a flag that fits in the space the state already has. An optional struct field spends a whole word on its tag, and a null inside it can carry "absent" instead.

**Why**:
- Crane's counted keep (`engine.keepPlatformObjectAlive`) is pushed by its owner. WebKit's `virtualHasPendingActivity` and Blink's `HasPendingActivity`, by contrast, are polled at collection time.
- A pushed keep needs an event at each edge, and the edge here is a change of EventTarget's private list.
- WebKit reports it through the virtual `EventTarget::eventListenersDidChange`, called after `addEventListener` adds, after a `removeEventListener` that removed, and after `removeAllEventListeners`. The event handler setter, the once removal in `innerInvokeEventListeners` and the abort-signal removal all reach those three. Blink reports it through `AddedEventListener` / `RemovedEventListener`.
- Without the report, PermissionStatus could not keep itself, and nothing else kept it.
- A virtual call per change costs every target. A per-instance field costs every node the bytes.

**What Happened**:
- permissions/permissions-cg.https.html went OK -> TIMEOUT in generation 208. This was its second flip; the first got a flake disposition at generation 183.
- The test adds a change listener, drops the status, collects, then changes the permission. Crane collected the status, and its registration with the permission store went with it.
- PermissionStatus.deliverChange's own comment named the missing piece ("the separate EventTarget lifetime task", feature queue 2026-10-18).
- A Crane test that leaves the task before collecting, with a no-listener control status beside each case, failed 4/4 kept cases on the base.
- EventTarget's InternalState is in every node and measured 64 bytes, of which a `?LazyEntry` took 24: 16 of payload and 8 for its tag and padding.

**Fix** (lane listen1):
1. `src/dom/event_listener_changes.zig`:
   - an owner calls `watch(target)` from its construction steps, which sets `listeners_watched` in EventTarget's state;
   - EventTarget calls `changed(target)` after each list change only when that flag is set;
   - owners install their steps at process start.
2. EventTarget's call sites are those of WebKit. None is made from a teardown.
3. `LazyEntry` stopped being optional: its `realm: ?Context` being null now means "not made lazily". The bool sits in the freed room, and a comptime pin keeps the state at 64 bytes or less.
4. PermissionStatus keeps once on the "has a change listener" edge, and only once its wrapper exists. Its keep ends:
   - when the last change listener is removed, whichever way;
   - at its global's teardown (a global teardown step, so a reused Window keeps it).
   It never ends in its own teardown. A separate scoped keep covers its own change dispatch, as WebKit's ActiveDOMObjectEventDispatchTask does.

**Takeaway**: **When a spec keeps an object "while it has listeners", give the listener list a way to tell the owner who asked, and copy WebKit's call sites. A flag on every target belongs in space the state already has: check what an optional's tag costs before adding a word to every node.**
