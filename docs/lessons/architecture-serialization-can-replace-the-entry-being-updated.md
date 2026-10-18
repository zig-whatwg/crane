# Architecture: Serialization can replace the entry being updated

**Date**: 2026-10-17
**Lesson**: Capture an operation's target before serialization, keep its script-visible object alive, and reacquire mutable container state after serialization returns.

**Why**: Structured serialization invokes getters. A getter can navigate, replace a history entry, detach a frame and collect objects before the original API call resumes. Reading "current" again changes the target; retaining a raw history pointer or entry wrapper can outlive its owner.

**What Happened**: `navigation.updateCurrentEntry()` captured its current entry, serialized the supplied state, then wrote whichever entry was current afterward. A getter that pushed or replaced an entry therefore overwrote the new entry's state. A getter that removed its frame reached `NoCurrentEntry`. The entry list can also drop its wrapper edge during replacement, before `currententrychange.from` is dispatched.

**Fix**: Capture the entry id and allocator, and take an existing engine Owned root for the captured wrapper. Serialize, reacquire the live navigation scope, and write by id. The setter consumes the serialized state even when the entry has gone; a missing scope frees it too. Dispatch `currententrychange` with the captured object before releasing its root. Keeping a disposed entry's serialized state remains separate work.

HTML's [updateCurrentEntry algorithm](https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-navigation-updatecurrententry) keeps the captured entry through serialization and dispatch. Blink's [NavigationApi::updateCurrentEntry](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/navigation_api/navigation_api.cc) likewise calls `SetAndSaveState` on the captured entry after serialization.

**Takeaway**: **A serializer is a script boundary: keep the captured object, then look up its surviving container again.**
