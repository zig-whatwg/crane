# Architecture: A "has script seen it" check must ask every world

**Date**: 2026-11-23
**Lesson**: Once an object can have a wrapper per isolated world, every question of the form "is it wrapped?" - before freeing it, before hanging an edge on it, before keeping it - must ask every world, and every set traced from "its wrapper" must reach each of its wrappers.

**Why**: Isolated worlds (lane cdpw: CDP's Page.createIsolatedWorld, Puppeteer's and Playwright's utility worlds) give an object one wrapper per world, each world's in that world realm's wrapper cache. Code written before worlds asked one cache - the object's own realm's - and read "no wrapper there" as "script never saw it". With worlds, that is no longer true: a world's script can hold the object while the page's realm has no wrapper of it, or has lost the one it had.

**What Happened**: Lane rc8 (refcount step 8) merged main after cdpw and found three faces of the same gap:
- `engine.hasWrapper` (V8) read the own realm's cache alone. Of its 37 callers, most free an instance "if unwrapped" after handing it to script (events, IDB requests, records, template contents, parser orphans): any of them could free an object under a world's wrapper - a use-after-free class.
- Step 8 traces an owner's listeners, handlers and observer callbacks from its wrapper (`engine.traceValues`) and holds them weakly. The set hung on the own realm's wrapper only. A NODE's wrappers keep each other (a world's node wrapper is a holder whose walk reaches the main-world slot), but a non-node EventTarget's do not: the page's listener died with the page's wrapper while a world still held the target. And for a node only a world ever wrapped, the set waited STRONGLY in the main cache for a main wrapper script might never make - a world's closure over its own target was a root again.
- MutationObserver's registration trace returned early on `!engine.hasWrapper(node)`, so a world's observer of a node only the world wrapped was kept by nothing.

**Fix**: (main's rulings of 2026-11-23 11:53 AM and 12:17 PM ET)
- V8 `hasWrapper` answers for any world: the own realm's cache, then - once the Browser made a world, one atomic load until then - each realm of the group (`protocol_worlds.hasWrapperInOtherWorld`). For a free-if-unwrapped caller that is the safe answer. A caller that needs the own realm's wrapper (to keep it: `node_holds.TaskHold`) makes it with `retainValue`.
- `traceValues` sets the set on every wrapper the owner has (`protocol_worlds.traceValuesInWorlds`), and a wrapper made later in any realm copies it from a sibling (`drawTracedValuesOnWrap`, `v8_Object_CopyTracedValues` over the isolate's traced values keys) or draws the values waiting in the own realm's cache. An owner another world wrapped no longer waits strongly for its own realm's wrapper. This is Blink's model: listeners are traced from the C++ EventTarget, which any world's wrapper keeps.

**Takeaway**: **When a feature adds a second place a wrapper can live, grep every "has a wrapper" and every "the wrapper" in the code it lands on: a check that reads one place answers "unwrapped" for objects script still holds, and the safe default for a free is "it may be wrapped somewhere".**
