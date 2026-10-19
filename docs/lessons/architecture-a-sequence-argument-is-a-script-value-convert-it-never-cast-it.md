# Architecture: A sequence argument is a script value: convert it, never cast it

**Date**: 2026-10-18
**Lesson**: A `sequence<Dictionary>` argument the binding hands an impl as `runtime.JSValue` is an engine value; reading it as a Zig slice through a pointer cast reads the engine's memory as Zig data.

**Why**: The generated binding converts most argument types, but a `sequence<CookieStoreGetOptions>` reaches the impl as a raw `runtime.JSValue`. `webidl.extractDictionarySlice(T, value.toAnyopaque())` takes the handle's pointer and casts it to `*const []const T`. Nothing checks it: the cast compiles, and whatever bytes sit at the handle's address become a slice.

**What Happened**: CookieStoreManager.subscribe() and unsubscribe() cast their argument this way since they were written. The bytes happened to read as an empty slice, so every subscribe() resolved having stored nothing, every getSubscriptions() answered `[]`, and `subscribe({name, url})` (not iterable) resolved instead of rejecting with a TypeError. Four cookiestore files sat at 0 passing (getSubscriptions single/multiple, subscribe_arguments, subscriptions_reset) with no crash and no log: the bug looked like "subscriptions are not implemented". The list was also kept on the CookieStoreManager object instead of the registration, so a window's and the worker's `registration.cookies` could never have shared one.

**Fix** (lane sw1-b9): `service_worker.realm.convertGetOptionsSequence` runs WebIDL's conversion through the engine protocol: `engine.convertToSequence` (a non-iterable is a TypeError), then each element as a dictionary - undefined or null has no members, an object's members are read in lexicographic order with `engine.getProperty` and classified with `engine.typeOf` (an absent member comes back as an engine handle to undefined, not the JSValue undefined tag: lesson architecture-a-handle-is-not-a-javascript-type), anything else is a TypeError. A conversion error propagates; the binding's rejectOnThrow turns it into the promise's rejection.

**Takeaway**: **A `runtime.JSValue` argument is a script value even when its IDL type is a sequence or a dictionary: convert it through the protocol, element by element. `toAnyopaque()` plus a pointer cast reads engine memory as Zig data and fails silently.**
