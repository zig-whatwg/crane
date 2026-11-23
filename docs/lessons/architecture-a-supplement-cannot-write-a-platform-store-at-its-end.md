# Architecture: A supplement cannot write a platform store at its end - flush before the platform state ends

**Date**: 2026-11-21
**Lesson**: Browser.deinit ends the platform state (and with it every `*platform.Store`) BEFORE the scope's supplements end, so a supplement that persists to a store must have written everything by an explicit flush that runs earlier, and must never hold a store handle across the Browser's life.

**Why**: `html.platform_state.destroy(scope)` runs just before `scope.deinit()` in Browser.deinit ("Its platform state ends first"). kit/sqlite's stores live in the platform state: a handle a supplement kept is dangling by the time the supplement's `deinit` runs.

**What Happened**: Lane prof1 (D6 steps 2-5) moved localStorage, cookies, the HTTP cache and IndexedDB onto the profile's stores. Each batches its writes (Chromium's StorageAreaImpl CommitBatch, SQLitePersistentCookieStore's 30 s / 512 ops, the disk cache's off-path writes), so something has to write the last batch. Doing it in the supplement's `deinit` would touch freed platform state.

**Fix**:
1. Open the store per operation (`platform.openStore` is a lookup under a mutex in both kits) - never keep a `*platform.Store`.
2. Give each persisting part a `flush`, called from one place - src/browser/profile_stores.zig `flush(scope)` - which Browser.deinit calls after the pages end and BEFORE the event loop and the platform state end (Chromium's LocalStorageImpl::ShutDown does the same: "Flush any uncommitted data").
3. Commit timers are owned timers on the Browser's loop; their drop (the loop ending first) does nothing, because the flush already wrote the batch.
4. A supplement's `deinit` only frees memory.

**Takeaway**: **In Crane a Browser's platform state dies before its supplements: persist through an explicit flush that runs before it, and open stores per operation.**
