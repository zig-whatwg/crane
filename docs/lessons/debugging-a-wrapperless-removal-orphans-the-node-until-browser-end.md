# Debugging: A Wrapperless Removal Orphans the Node Until Browser End

**Date**: 2026-10-10
**Status** (2026-10-23, lane unwrapped1): on an engine that declares `wrap_tracking` (V8), an orphan now lives until its REALM ends, not its Browser: the removal records its root (`runtime.orphan_roots`) and the realm's end frees it through its own deinit. The sweeps stay - for an orphan made after its realm's end began, and for engines that do not track wraps - and so does the advice not to free at the removal site. See architecture-a-page-end-frees-what-no-wrapper-reached-only-on-proof.md.
**Lesson**: A node removed while it has no JS wrapper is freed by nobody before the browser ends, so any InternalState that owns non-arena memory needs a teardown sweep until reference counting lands.

**Why**: Until refcount step 7, a detached node with no wrapper has no owner: the collector never sees it and the tree no longer holds it. dom/teardown_sweeps.zig is the net, but only for node types that install a sweep. Final cleanup frees registries wholesale, so a type without a sweep never runs its InternalState.deinit, and gpa memory it owns leaks.

**What Happened**: Merge round 4's sweep showed 89 exit `leaked:` lines against 21 in every earlier round. Lane leak89 mapped the 68 new ones to one file, shadow-dom/declarative/declarative-shadow-dom-attachment.html, which parser2 had just made pass (0 -> 654 subtests). Its re-attachShadow runs Element step 4.3 (remove the declarative root's children); the removed `<slot>` had no wrapper, and SlotState's assigned_nodes buffer (slot_helpers.zig setAssignedNodes) leaked once per slot. Each lane's own A/B had shown no change, because the leaking path did not run before parser2 and the slot code merged earlier.

**Fix**: bb309b2e00: HTMLSlotElement installs `dom.teardown_sweeps.install(&sweepRemaining)` calling `Registry.deinitAllAndClear()`, with a tests/html test that orphans a slot wrapperless and ends the browser under std.testing.allocator. Do NOT free the removed children at the removal site: a MutationObserver record can still hold them.

**Takeaway**: **A feature that starts passing can expose a leak in code merged rounds earlier; attribute exit-leak jumps per chunk and per file, and any InternalState owning non-arena memory needs a teardown sweep until refcounting.**
