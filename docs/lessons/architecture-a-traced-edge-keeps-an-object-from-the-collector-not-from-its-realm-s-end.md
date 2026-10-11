# Architecture: A traced edge keeps an object from the collector, not from its realm's end

**Date**: 2026-10-11
**Lesson**: An object one realm keeps through a traced edge (`engine.traceChild`) can belong to another realm's wrapper cache, and that realm's end frees it whatever still holds it - so the holder must check the slab generation on every read, not only at its own teardown.

**Why**: A platform object that is not a node is wrapped in the cache of the realm that made it. `WrapperCache.deinit` - a realm's end - frees every such instance that no other live cache wraps (`wrappedElsewhere`), and a traced edge from another realm's object is not a wrapper in another cache. The edge keeps the WRAPPER reachable, and the wrapper keeps its creation context, so the end waits while the page lives: a removed or navigated frame's realm is only detached (`protocol_realms.detach`) and ends when the collector takes it. But it still comes - with the page's end, which ends a frame's realm before its parent's, and wherever a realm ends without detaching (a top-level realm, a detach that cannot allocate its record). From then on the holder's pointer names a freed slot the slab may reissue.

**What Happened**: Review of Codex row 17 (S1) asked whether `new frame.contentWindow.Range()`, moved into the top document by setStart and added to the top selection, could be freed under the selection. Measured, not reasoned:
- `crane/sf2-selection-frame-realm-range.html` (removal, navigation, GC between turns): the Range is kept, 3/3 on main.
- `tests/html/selection_range_realm_end_test.zig` ends the detached frame realm while the page lives: the Range's slot generation changes at once. On main, the selection's getters then read the freed slot - `direction` answered "forward" for a range that no longer existed, and the other getters answered "empty" only by luck of what the freed memory held.
Selection kept `range_generation` but consulted it only in `deinit` and `setRange`.

**Fix**: `Selection.liveRange(internal)` returns null when the range's generation changed, and every reader goes through it (boundaries, direction, getRangeAt, removeRange, deleteFromDocument, serialize, the mutation hook, setRange, deinit). A dead range reads as an empty selection; setRange drops it without dissociating, since its slot may hold another object.

**Takeaway**: **A traced edge is a reason for the collector to keep an object, not a guarantee that it lives: if the object can come from another realm, its realm's end frees it - read it through a generation check everywhere, and find out by ending that realm in a test, not by reading the edge code.**
