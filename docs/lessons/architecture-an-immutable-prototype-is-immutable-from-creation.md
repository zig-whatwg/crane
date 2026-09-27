# Architecture: An immutable [[Prototype]] is immutable from creation: build the global from Window's instance template

**Date**: 2026-09-26
**Lesson**: A Window realm made without the snapshot had `globalThis instanceof Window` false: its global came from a plain ObjectTemplate marked SetImmutableProto, so the SetPrototypeV2(global, Window.prototype) after creation failed silently (JSObject::SetPrototype refuses any change on an immutable-proto map, and the fresh path ignored the result).

**Why**: WebIDL 3.8 wants both an immutable [[Prototype]] and Window.prototype as that prototype. Only creation can give both: a global made from the Window interface template's InstanceTemplate starts with [[Prototype]] = Window.prototype (Genesis takes it from the constructor template), which is what the snapshot generator does - its later SetPrototypeV2 "succeeds" only because the prototype is already set.

**Fix**: protocol_realms.createWindowRealm builds a fresh global from `FunctionTemplate(Window)->InstanceTemplate()` (registered once per isolate, EventTarget first, with the WindowProxy's indexed handlers), and sets no prototype afterwards.

**Takeaway**: **If an object's [[Prototype]] must be immutable, give it the right one at creation; a later SetPrototype on it is a no-op you will not notice.**
