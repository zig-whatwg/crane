# Architecture: A namespace operation's realm is the current realm, not the first caller's

**Date**: 2026-10-12
**Lesson**: The binding handed every namespace operation that takes a `runtime.Context` one process-wide context, made by the first call - so console's per-realm state was one map shared by every realm on every thread.

**Why**: namespace.zig kept `global_context` (with a TODO, "should be stored per-isolate"), made by
the first namespace call that took a `runtime.Context` and kept for the process. Its mutex covered
only the context's creation; the operation then mutated the context unlocked. The Console Standard
gives each console namespace object its own count map and timer table, and WebIDL runs a namespace
operation in the current realm - which V8 has already entered (the callback's creation context).

**What Happened**: Every realm's `console.count('x')` counted on one map, and a realm's own
`console_state` was never touched. With agents on their own threads, two agents timing at once grew
one `std.StringHashMap` from two threads: Zig's `SafetyLock` panicked ("reached unreachable",
hash_map.zig getOrPutContextAdapted) in tests/v8/namespace_current_realm_test.zig on base. The same
context's logger also printed every binding TypeError to stderr once any page had called console.

**Fix**: the operation gets `context_manager.get(context)` - the current realm's ContextData - and a
context no realm was made for (a binding test's bare context) gets one made for the call and ended
with it (namespace.zig `CallRealm`). The arguments' call-scoped arena stays over the C allocator:
over the realm's (the runner's DebugAllocator) every console.log and CSS.escape was half again as
slow in gc_bench.

**Takeaway**: **A per-realm algorithm reaches its state through the realm the engine has entered,
never through a value cached by whoever called first - "first caller wins" is a global in disguise.**
