# Architecture: An impl's return value is the JS return value, verbatim

**Date**: 2026-09-21
**Lesson**: There is no marshalling layer between an impl and JavaScript. Whatever the impl returns is what script sees.

**Why**: `convertReturnValue` maps `JSValue.undefined` to `v8_Undefined` and
stops. Nothing wraps, promotes or validates.

**What Happened, twice**:

1. **`Promise<T>` in the IDL, `jsUndefined` in the impl.** The whole CookieStore
   API returned the literal `undefined`, not an unresolved promise. Every
   `.then` threw. An impl whose IDL says `Promise<T>` must BUILD the promise -
   the house pattern is `Blob.zig`: `v8_PromiseResolver_New` → `GetPromise` →
   `Resolve` → `JSValue.fromPromise`. Failures must REJECT, not throw
   synchronously, or `promise_rejects_js` cannot see them.

2. **`fromAnyopaque(@ptrCast(&zig_struct))`.** That produces a `.handle` with
   `handle_scope = .global`, and the return path reinterpret_casts it to
   `Global<Value>*` and dereferences it. A heap-allocated Zig struct is aligned
   and inside the heap range, so **every guard passes and the read goes
   through** - killing the process rather than failing the subtest, and taking
   every other test in the file with it.

**Fix**: Build real V8 values. Grep `fromAnyopaque(@ptrCast(&` before trusting
any getter; it should return nothing but comments.

**Takeaway**: **A wrong pointer that passes every guard is worse than one that
fails.** The bad answer dies loudly at the subtest; this one kills the process.
