# Debugging: A tag in the low bits of an aligned pointer type is UB, and the optimizer may drop the untag

**Date**: 2026-10-02
**Lesson**: A value of a pointer type must be aligned for that type. A tag
stored in the low bits of a function pointer (4-aligned on aarch64) is illegal
behaviour, and an optimized build is entitled to assume those bits are zero -
so it deletes the `& ~3` that removes the tag, and the tagged address reaches
the engine.

**Why**: Codegen types a WebIDL callback function as a Zig function pointer
(`callbacks.EventHandlerNonNull = *const fn (...) JSValue`) that is never
called: it carries the converted function's `Global<Value>*`.
`conversions.fromV8Value` stored that Global with `.global_handle` (1) in its
low bits, byte-copied into the function-pointer type because no cast would
accept a misaligned function pointer. Zig gives a pointer parameter LLVM's
`align` attribute, so wherever `takeCallbackFunction` (which untags) was
inlined after a parameter of the callback type, LLVM knew the low bits were
zero and folded the untag away.

**What Happened**: a ReleaseSafe wpt_runner crashed 578 worklist files that
pass in Debug, with SIGTRAP (`brk #0x5516`, the C sanitizer's alignment trap)
in `v8_Global_Clone` under `EventTarget.innerInvoke`, and in
`v8_Global_Dispose` under `setEventHandler`: every event handler IDL
attribute (`reader.onload = f`). `otool -tV` of the ReleaseSafe
`EventTarget.setEventHandler` showed the parameter's raw value stored as the
handler's Global, with no `and #0xfffffffffffffffc` anywhere. Debug never
folds, so its identical check never fired. A later build happened not to
inline `takeCallbackFunction` (realms2 added a call to it), and the crash went
away there with the UB still in place.

**Fix**: store the Global untagged (`new` returns 16-aligned memory, so the
plain address is a value the type may hold), and read an optional callback
type's value back as that Global with no tag test - a test an optimizer can
fold to false as easily. Pinned in tests/v8 (`a callback-function argument
converts to a value its function-pointer type may hold`: aligned for
`@alignOf(fn ...)`). The tagged values left in the adapter are all
`*anyopaque` / `*const anyopaque`, whose alignment is 1.

**Takeaway**: **Never put a tag in a pointer whose type has an alignment above
1 - not by a byte copy either. Tag only `*anyopaque`/`usize`; an untag the
optimizer can prove redundant is gone in every release build.** When a release
build crashes where Debug does not, disassemble the function on the stack and
look for the masking instruction before suspecting the engine.
