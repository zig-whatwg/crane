# Architecture: An errdefer and a free in the catch below it free twice

**Date**: 2026-10-01
**Lesson**: `errdefer allocator.free(x)` already runs on every error return after it. A later `catch |err| { allocator.free(x); return err; }` frees `x` by hand and then returns an error - so the errdefer frees it again.

**Why**: The catch block reads as local cleanup, written by someone thinking of the line in front of them; the errdefer is a few lines up and out of sight. Both are right on their own and wrong together, the compiler says nothing, and the path runs only when the step fails - which no ordinary test makes it do.

**What Happened**: The seam batch's attributed sweep ended with two such double frees, both on paths WPT reaches only by accident:
- Window.get_localStorage made its backend under `errdefer destroy(backend)` and destroyed it again in the catch of getLocalStorageBackend - every `localStorage` read in an opaque-origin document (a sandboxed frame without allow-same-origin) is that error (realms fixed it, c2feeb984).
- HTMLFormElement's submit held its target under `errdefer allocator.free(target)` and freed it in the catches of the entry-list FormData and the POST body; a text/plain body in windows-1252 with a lone surrogate fails there (form-submission-0/text-plain.window.js, after submit-file.sub.html).
A scan of src/webidl/impls for an errdefer'd variable freed again in a catch that returns an error found a third, Window's settingsIndexedDB (IDBFactory.init failing), on an out-of-memory path.

**Fix**: Delete the hand-written free from the catch; keep the errdefer, and say so in a comment where the catch still cleans up something else. A `deinit` of a struct's CONTENTS in the catch is fine when the errdefer frees only the struct itself.

**Takeaway**: **After an errdefer, a catch that returns an error must not free what the errdefer frees. Grep for the pair - `errdefer ... free(x)` followed by `catch { ... free(x); return err; }` - rather than wait for the error path to run in a sweep.**
