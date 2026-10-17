# Architecture: An isolate borrows its snapshot blob - find the owner that outlives it, never copy it per isolate

**Date**: 2026-10-17
**Lesson**: `v8_Isolate_NewFromSnapshot` copied the 2.6 MB snapshot blob into a `new char[]`, plus a `new StartupData`, for every isolate "because we don't own the input buffer", and nothing freed either: one leak per Browser. The bytes it was handed were already the process's, lent until after every agent's end.

**Why**: V8 keeps a POINTER to `CreateParams::snapshot_blob` for the isolate's life and reads the bytes again for every context it restores (`Snapshot::NewContextFromSnapshot`); "The embedder owns the blob" (v8-isolate.h). The copy answered "who owns this?" by making a new owner - and gave that owner no end. Freeing the copy at `Isolate::Dispose` would have fixed the leak but kept a 2.6 MB copy (and its memcpy) per Browser; the real answer was already in the code: crane.Process reads the snapshot once and frees it after its last Browser, and the protocol lends it (`EngineOptions.snapshot`, BORROWED until `deinitializeEngine`, which comes after every agent is destroyed). Chromium does the same - every isolate's StartupData points into the one snapshot mapping, which is never unmapped (gin/v8_initializer.cc, `GetMappedFileData`).

**What Happened**: Lane sw1-b3's leaks --atExit over fetch/api/ went from 5 to 98 `ROOT LEAK: <malloc in v8_Isolate_NewFromSnapshot>` roots once the runner made a fresh Browser after every file that left a service worker registration (lesson testing-a-leak-total-that-grows-with-the-browsers-a-run-makes-is-a-per-browser-leak). Lane snapleak removed the copy: the StartupData lives by value in the isolate's adapter record (`IsolateData`, kIsolateDataSlot), made before `Isolate::New` and deleted by `v8_Isolate_Dispose` only after `Isolate::Dispose` returns, and points at the caller's bytes. `tests/v8/snapshot_blob_in_place_test.zig` checks that the bytes V8 restores each agent from are the engine's blob itself (red on the copy), that a realm restored later still works, and that no agent restored from the blob outlives it; `deinitializeEngine` logs an error if one does.

**Fix**:
1. Before copying a buffer an engine keeps a pointer to, find every caller and how long its buffer lives. If one owner already outlives every consumer, borrow from it and write the borrow into the contract (BORROWED until ...).
2. Keep what the engine points at (here the 16-byte StartupData) inside a record whose end you control, and end that record AFTER the engine's object, not before.
3. Check the borrow where the lender lets go (deinitializeEngine: no agent restored from the snapshot may still be alive), so a host that breaks the order hears it there, not as a crash in a later realm.

**Takeaway**: **A copy made because "we don't own it" is a second owner; find the first owner's lifetime and borrow from it - and if you do copy, give the copy an end.**
