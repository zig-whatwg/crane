# Architecture: A slot goes back only when every holder kind is on an allowlist

**Date**: 2026-10-25
**Lesson**: A type's slab slot can be returned only once every kind of holder that can outlive the object reads it through a generation check, is cleared at the object's teardown, or keeps something else, such as the WindowProxy instead of the Window. Inventory the holders, gate the return on an allowlist of converted kinds whose default is unsafe, and flip it in one commit. A Window converted to JS after its teardown is the other half: it must answer null, never get an ordinary wrapper.

**Why**: While a torn-down object keeps its slot, a stale holder reads a live generation and a null state, and fails safely. Return the slot, and the next allocation of any type lands there, so every unchecked holder becomes a type confusion. That covers a field, a task payload, a generated state field, an engine internal field or a browsing context. The holders live in many layers: about 60 sites for a Window, in impls, dom, html, browser, fetch and the engine adapter.

**What Happened**: Lane winslot1 found the Window's holders with three parallel read-only searches, by layer, each told where Window pointers come from. Four groups came out: unchecked and outliving the Window (13), the engine adapter (9), already generation-checked (29), and same-realm owned (9). On the way, three bugs that were live on main:
- E3: a torn-down Window converted to JS had no bound global, so it was wrapped as an ordinary object in the current realm's cache. That cache's sweep ran the Window's destructor a second time and freed its slot.
- E4: after a detached realm was collected, its Window still named the disposed handle of its global, until the realm's end ran.
- E9: an inner realm teardown cleared the thread's cleanup coordinator instead of restoring the outer one, so the outer teardown freed storage inline.

The three-browser probe then changed the holder design. Firefox, and the majority mechanism by mechanism, answers the SAME WindowProxy after the frame navigates and after it is removed (closed). So MessageEvent.source, UIEvent.view and the opener keep the proxy through a traced edge and read the Window it shows now. A generation link to the old Window would have read null.

**Fix**:
1. runtime.window_holders: a `Holder` enum, one member per kind, and an allowlist `safe` that starts with nothing but the fixed engine bugs. `reusable` (the slot may go back) is true only when every member is listed. Tests pin the default: an empty table makes every kind unsafe, and leaving any one member out keeps every slot.
2. Each kind's conversion lands as its own commit with a forced-reuse test:
   - tear the realm down;
   - give the slot back by hand while the switch is off;
   - reissue the slot to an impostor that announces itself;
   - read the holder: red reads the impostor, green reads null or the proxy.
3. Engine: sever every global (proxy, hidden global, WindowProperties) BEFORE the Window is freed, on every end kind. Mark the Window's cleanup so Link-style checks read "gone" between its teardown and its slot's release.
4. The last commit lists the last kinds, and the realm's end then returns the slot. A frame navigated twelve times went from 15 live Windows to 2.

**Takeaway**: **Do not return a slot that holders can still name. Inventory every holder kind, gate the return on an allowlist whose default is unsafe, convert one kind per commit with a forced-reuse test, and flip the switch last. Where the platform object is a proxy for something that outlives it (a WindowProxy), keep the proxy, not the object.**
