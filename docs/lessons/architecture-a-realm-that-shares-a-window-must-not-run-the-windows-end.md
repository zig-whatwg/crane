# Architecture: A realm that shares a Window must not run the Window's end

**Date**: 2026-11-21
**Lesson**: An isolated world realm's global wraps its MAIN realm's Window, so every host step keyed "by realm" that reaches the realm's Window (WindowOperations.windowDestroyed, the unloading cleanup steps, the context manager's Window teardown, timer maps) acts on the page's Window when it is handed a world realm.

**Why**: Crane's host code finds a realm's Window as `realm.getRealm().global_object` (browser/Context.zig realmWindow, Window.zig windowOfRealm). A world realm records the same Window there - it must, so that `document`, `location` and the settings resolve to the page's - so a step that "clears this realm's Window state" clears the page's.

**What Happened**: Lane cdpw's first world-realm end called the host's `windowDestroyed` for the world realm, as a frame's end does. That runs `clearDiscardedWindowState`: the unloading cleanup steps (the page's idle callbacks ended, its deferred fetches processed, its blob URLs revoked) and the timer map - all the page's. The context manager's end would likewise have run `Window.deinit` on the shared Window (fixed with `ContextEntry.world`).

**Fix**: Give every per-Window structure ONE owner, the main realm (`engine.mainRealmOf` where the host keys a Window's state: browser/Context.zig `TimerMap.of`), and make each end step tell a world realm from its main realm (`engine.worldOf`): a world's end clears only what that world set (`clearWorldState`: its timers, by their record's realm, and its animation frame callbacks) and never the Window's own end steps.

**Takeaway**: **When two realms share one platform object, audit every "by realm" lookup for the realm's global: each must either key the shared object's owner (the main realm) or act only on what the other realm itself made - never both, never the shared object's teardown.**
