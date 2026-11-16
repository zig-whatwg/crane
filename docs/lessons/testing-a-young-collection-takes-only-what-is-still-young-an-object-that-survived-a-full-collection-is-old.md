# Testing: A young collection takes only what is still young - an object that survived a full collection is old

**Date**: 2026-11-16
**Lesson**: A test that holds an object through collections and then expects a young-generation collection to take it after the release will fail whatever the code under test does: the object was promoted while it was held.

**Why**: V8 moves an object that survives young collections - and everything a full collection finds alive - to the old generation. A scavenge processes the weak handles of young objects only (15.7.112.43 src/handles/global-handles.cc `ProcessWeakYoungObjects` walks `young_nodes_`), so an old object is taken by a full collection alone, however weakly it is held.

**What Happened**: Lane wrap2 changed how the wrapper cache arms a record's weak v8::Global and wrote a test for the re-arm after pending activity ends: keep an Event, run young and full collections (it survives), release it, run four young collections, expect it gone. It failed at that line. Two explanations fitted: the new code had not re-armed the handle (a leak until the realm's end), or the expectation was wrong. The same job's run with the change reversed failed at the same line on main's code, which pointed at the test; the test had exercised the only path that proved the re-arm, so the change still could not be called green.

**Fix**: Assert the state the code is responsible for, directly, and ask each collection only for what it can do:
- read the handle itself (`v8_Global_IsWeak`: not weak while a keep remains, weak after the last release);
- after a release that follows a full collection, expect a FULL collection to take the object;
- for the young case, keep and release with no collection in between (compare the collection counters before and after, and try again if one ran), then expect a young collection to take it.

**Takeaway**: **Before a test expects a young collection to take something, ask whether the test itself made it old. Pin the handle's state directly; a collection's outcome mixes your code with V8's generations.**
