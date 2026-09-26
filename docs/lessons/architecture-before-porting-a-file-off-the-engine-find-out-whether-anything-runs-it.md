# Architecture: Before porting a file off the engine, find out whether anything runs it

**Date**: 2026-09-26
**Lesson**: 279 of the runtime-impls lane's starting engine-boundary references were in code nothing called; deleting it was cheaper and safer than porting it.

**Why**: The engine-boundary lint counts text, not reachable code, and Zig analyses lazily - a file full of `v8_*` calls compiles and counts whether or not anything reaches it. `v8_promise_chaining`, the readable-stream async iterator, `iterator_record`, `from_iterable_algorithm`, `v8_resources`, `reader_ops` and `v8/async_iterator.zig` had no caller that led to a binding or a test.

**What Happened**: The lane grepped every public name in each candidate file and followed each caller until it reached a binding, a test, or nothing (bfc9224db, 4515 -> 4236). One grep piped through `| head` hid two `populateIntrinsics` callers - in context_manager.zig and Context.zig - and the second broke a gate build once the method moved.

**Fix**: For each file: list its public names; grep each one untruncated across src/, tests/ and tools/; follow every caller to a root (a generated binding, a test block, a build artifact's main) or to nothing. Delete what reaches nothing, with its re-exports; port the rest.

**Takeaway**: **Port code that runs; delete code that doesn't - and never truncate the grep that decides which.**
