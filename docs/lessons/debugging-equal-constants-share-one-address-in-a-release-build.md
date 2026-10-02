# Debugging: Equal constants share one address in a release build

**Date**: 2026-10-02
**Lesson**: Zig keeps distinct variables at distinct addresses, but not equal
constants. `typeId(T)` was the address of a per-type `const marker: u8 = 0`;
a ReleaseSafe build merged all 1,068 of them into one symbol, and every
`Instance.stateAs` brand check passed.

**Why**: `stateAs(T)` walks the instance's vtable ancestry comparing each
level's `typeId` with `typeId(T)`. With every id equal, the first level
matched whatever `T` was asked for, and its state was returned as a `*T`.
LLVM marks constants `unnamed_addr` and merges identical ones; Debug does not
run that pass. `nm` told the whole story: 1,068 `TypeIdHolder(...).marker`
symbols in the Debug runner, ONE in the ReleaseSafe runner.

**What Happened**: after the callback-pointer fix, the ReleaseSafe runner
still crashed FileAPI/url/url-with-xhr.any.js (SIGSEGV in
`ErrorEvent.get_filename`). The event handler processing algorithm's
"special error event handling" asks two brand questions - is the event an
ErrorEvent, is the target a Window or WorkerGlobalScope - and an
XMLHttpRequest's `error` ProgressEvent answered yes to both, so its state was
read as an ErrorEvent's. crane/td-event-handler-brand.html: Debug 4/4,
ReleaseSafe 1/4 (an ErrorEvent at a `div` reached `onerror` with five
arguments).

**Fix**: `var marker: u8 = 0` - the idiom for a unique address per type (Zig
merges no variables). Marked `// process-wide:` for lint-global-state: an
address, never written. tests/runtime/state_brand_test.zig pins distinct ids
for two same-shaped types; the Crane test is what shows the merge.

**Takeaway**: **An identity built on the address of a `const` is an identity
only in Debug. Use a `var` (or a value) when the address must be unique, and
check a release binary with `nm` when identities misbehave there.**
