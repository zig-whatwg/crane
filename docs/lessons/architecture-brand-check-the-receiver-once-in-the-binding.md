# Architecture: Brand-check the receiver once, in the binding layer

**Date**: 2026-09-22
**Lesson**: `MethodCallback` resolved a missing or foreign `this` to the global object for every interface, so idlharness's wrong-receiver calls reached `_internal.?` on another interface's state and crashed both idlharness files.

**Fix**: `if (instance.stateAs(Interface.State) == null)` throw TypeError "Illegal invocation" for every generated operation (CRASH -> OK with 320 and 273 subtests). Getters and setters still lack the guard.

**Takeaway**: **An impl cannot tell it was handed another interface's state; only the binding can.**
