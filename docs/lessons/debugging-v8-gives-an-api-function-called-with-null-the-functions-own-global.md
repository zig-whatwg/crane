# Debugging: V8 gives an API function called with null its OWN realm's global proxy

**Date**: 2026-10-05 (recorded 2026-10-16, when binding3 resumed)
**Lesson**: A sloppy receiver - null or undefined - reaches a FunctionTemplate callback as the global proxy of the function's context (the CallFunction builtin converts it with "the global proxy from the function context"), not the caller's.

**Why**: WebIDL's [Global] operations use the method realm's global exactly when this is null or undefined. The binding assumed V8 hands over the CALLER's global for `fn.call(null)`, so it treated ANY global that was not the method's own as "a coerced null" and used the method's global.

**What Happened**: `frame.postMessage.call(window, "x", "*")` posted to the frame; `frame.structuredClone.call(window, v)` deserialized in the frame's realm (the serialization lane's ser-global-operation-this-cross-realm, html/webappapis/structured-clone/structured-clone-cross-realm-method 0/4). A Crane test showed `frame.atob.call(null)` and `.call(undefined)` already arrive as the frame's global.

**Fix**: Resolve the receiver from what it is: this === the method's global -> the method's Window; another realm's global object -> that realm's platform object, brand-checked; anything else a TypeError. binding3 wrote it first (d11262aca1, parked); main has it as xorigin2's `globalReceiverWindow` (95610b9d24), and structured-clone-cross-realm-method passes 4/4.

**Takeaway**: **Measure how the engine converts a receiver before writing a heuristic to undo it: here the conversion already gave the spec's answer.**
