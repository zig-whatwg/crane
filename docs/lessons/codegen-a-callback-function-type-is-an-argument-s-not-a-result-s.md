# Codegen: A callback function type is an argument's form, not a result's

**Date**: 2026-10-17
**Lesson**: Codegen types an IDL callback function as a Zig function pointer (`callbacks.Function`), a form whose value the V8 binding fills with the argument's Global. As a getter's result it has no conversion: `readonly attribute Function size` gave script `undefined`, made fresh by `v8_Undefined` and never released - one handle per read.

**Why**: The function-pointer type is a carrier the binding understands in one direction only: conv.fromV8Value hands an argument's handle over in it, and the impl takes it with `engine.takeCallbackFunction`. Nothing converts it back. The getter path's generic branch sent any pointer that is not an Instance to "undefined", and `getterValueIsOwned` (an allowlist) kept the handle it made. CountQueuingStrategy and ByteLengthQueuingStrategy returned a pointer to a Zig function, so the spec's "realm's size function" could never reach script.

**What Happened**: Lane leaks2's leaks --atExit over streams/ named 165 roots under the size getters; the WPT files queuing-strategies.any.js (36/60) and queuing-strategies-size-function-per-global.window.js (0/2) failed on it.

**Fix**: `writer.isCallbackFunctionValueAttribute`: a non-nullable attribute of a `callback` type is generated as `runtime.JSValue`, which the binding releases like every JSValue a getter returns. The impl returns a hold of the realm's function, which `engine.globalBuiltinFunction` makes once per realm (CreateBuiltinFunction, kept under a private key on the global object - Blink's GetCachedSizeFunction). Nullable callback attributes and event handlers keep their forms.

**Takeaway**: **A type the binding fills in one direction is not a type the binding can return. When codegen gives an IDL type a carrier form, check the getter path has a conversion and an ownership rule for it - a JSValue already has both.**
