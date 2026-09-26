# Architecture: Brand-check the receiver once, in the binding layer

**Date**: 2026-09-22
**Lesson**: `MethodCallback` resolved a missing or foreign `this` to the global object for every interface, so idlharness's wrong-receiver calls reached `_internal.?` on another interface's state and crashed both idlharness files.

**Fix**: `if (instance.stateAs(Interface.State) == null)` throw TypeError "Illegal invocation" for every generated operation (CRASH -> OK with 320 and 273 subtests).

**2026-09-26, getters and setters**: the accessor callbacks LOOKED brand-checked - each walks a WrapperTypeInfo chain - but `wrapper_type_info_registry.getWrapperTypeInfoByName` is a stub that returns null, and slot 1 is filled only from `dom_type_info`'s hand-written list of 24 interfaces, never by the constructor path. Every other wrapper fell through to "no type info, read slot 0", so `HTMLInputElement.prototype.value`'s getter answered for a textarea and `Node.prototype.nodeName`'s ran on an EventTarget. `implementsInterface` in `interface.zig` now asks the state ancestry in the getter, the setter and the lazy getter, as operations do. idlharness files gained 26 (streams), 27 (fetch), 11 (cookiestore) and 5 (html) subtests; `crane/accessor-brand-check.html` pins it.

**Takeaway**: **An impl cannot tell it was handed another interface's state; only the binding can.** And a check that consults a registry is only as good as the registry: read what the lookup returns before trusting the branch it guards.
