# Architecture: A page's end must not reset what all of its Browser's tabs share

**Date**: 2026-11-23
**Lesson**: Code that ends one page (browser `Context.deinit`) by resetting a container the agent or the event loop owns - the agent's pending mutation observers, the loop's animation frame state - throws away every other tab's entries with it; a page's end must take out only what is its own.

**Why**: Before host-opened tabs, a Browser had one page: "the page" was every window of the agent, and "reset the agent's pending observers" or "empty the loop's frames" at its end was exactly "drop the page's". With tabs (lane cdph's `Browser.createTab`) and fresh traversables per WPT file (`Browser.navigate`), several pages share one agent and one event loop, and the same reset reaches across tabs. Nothing fails loudly: the other tab's callback just never runs.

**What Happened**: Lane tab1 (instances "tab state") read `Context.deinit` while moving the frame clock under the tab. It ran `rendering.endPage(realm)`, which emptied the loop's one `Frames` - every tab's pending `requestAnimationFrame` callbacks released unrun, so the host page's rAF loop died when a host-opened tab closed - and `mutation_observer_algorithms.resetAgent(realm)`, which rebuilt the agent's whole `MutationObserverAgent`, so another tab's observer with an undelivered record was never notified. Red tests: close a host-opened tab, then expect the first page's rAF loop to keep ticking and its pending MutationObserver to be called (tests/html/tab1_tab_scope_test.zig).

**Fix**: Scope each reset to the page's own objects. `resetPage(realm)` removes only the pending observers and signal slots whose relevant realm is of the page's tab (`runtime.TabScope.ofRealm`), leaving the agent's queued flag - its notify microtask is an agent microtask no realm's end drops. The frame clock became per tab (the tab scope's `frames` slot), so `endPage` empties only the ending tab's. The other steps of `Context.deinit` were checked: timers, fetch abort, the unloading cleanup steps and the realm's end all act on the page's realm.

**Takeaway**: **When a teardown says "the page's X", check who owns X: if it is the agent's or the loop's, several tabs share it, and the teardown must filter to the page's own entries (by realm or tab) instead of resetting the container.**
