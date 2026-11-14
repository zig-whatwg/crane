# Architecture: V8 keys decisions on embedder fields - a wrapper without them must answer them elsewhere

**Date**: 2026-11-09
**Lesson**: Moving a wrapper's native pointer from internal fields to `Object::Wrap` changes every check that read "has internal fields" as "is a platform object", and some of those checks are inside V8.

**Why**: `InternalFieldCount() > 0` was Crane's test for "this object wraps an instance", in the adapter and in V8 alike. V8's ValueSerializer asks it too: with no custom host objects, `ValueSerializer::IsHostObject` answers `GetEmbedderFieldCount(map) > 0` for a JS_API_OBJECT (13.1 src/objects/value-serializer.cc). A node wrapper made from a template with no internal field is still a JS_API_OBJECT. By V8's rule it is an ordinary object, so `structuredClone(node)` would copy its own properties instead of throwing DataCloneError.

**What Happened**: In the wrapper redesign's P4, node interface templates got 0 internal fields (the 16-byte wrapper, design 4.1). The audit for that change found the readers that would have taken a node for "no platform object":
- the binding's `getInstance` and every `GetAlignedPointerFromInternalField(obj, 0)` caller, which return null past the field count;
- `ThisInstanceFields`, `ReadArgument` and an interceptor's `HolderAlignedPointer`;
- conversions.zig's two `InternalFieldCount(obj) > 0` guards in front of the field-0 read;
- the serializer's host-object decision, inside V8;
- template_registry, interface.setInstance and the constructor bind, which wrote fields the object no longer has (V8 CHECK-fails on an out-of-range field).
The adapter's own tests showed one more: four tests "wrapped" nodes with `v8_Object_New`, a plain JS_OBJECT, which `Object::Wrap` cannot take (it crashed there).

**Fix**:
1. One C++ rule answers "the instance of this object": field 0 when the object has internal fields, else - for an API wrapper - `Object::Unwrap` under the node anchors' tag, then the anchor's slot and the node's instance. Every field-0 reader goes through it, and `IsApiWrapper()` guards `Unwrap`, which reads the CppHeap pointer field only API objects have.
2. The serializer's delegate answers `HasCustomHostObject` true and `IsHostObject` = has embedder fields OR has a node anchor (Blink's V8ScriptValueSerializer answers `IsApiWrapper`).
3. Writes of fields skip node instances (`instance.vtable.counted`). A wrap is refused before the count is taken when its object is no API object (`v8_NodeWrapper_Wrappable`).
4. tests/v8/node_anchor_test.zig pins the cases: a plain object, Object.create(Node.prototype), the prototype objects, a function, a non-node wrapper, a node of another realm, receivers and arguments that are no node, and structuredClone.

**Takeaway**: **When a fact moves out of the place every check read it from, grep every reader of the old place, the engine's own included. The ones inside the engine are the ones a test will not show until a page relies on them.**
