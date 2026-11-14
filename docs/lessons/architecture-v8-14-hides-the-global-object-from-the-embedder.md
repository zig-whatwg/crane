# Architecture: V8 14+ hides a context's global object from the embedder

**Date**: 2026-11-10
**Lesson**: In V8 >= 14 no public API returns a context's JSGlobalObject: GetPrototype() on the global proxy answers what script sees (Window.prototype), and an interceptor's Holder() is the proxy. Code that reached the global object through "V1 GetPrototype on the proxy" still compiles and silently gets another object.

**Why**: V8 deprecated, then removed, the hidden-prototype accessors (crbug.com/333672197): GetPrototypeV2 was renamed back to GetPrototype with Object.getPrototypeOf semantics (21963a7493e), SetPrototype likewise, HolderV2 became Holder (3d66b2bdda7, global proxy for a global's property), FunctionCallbackInfo::Holder and PropertyCallbackInfo::This went. What remains: Object::WrapGlobal / CheckGlobalWrappable (one v8::Object::Wrappable on both the proxy and its hidden prototype - Blink's model), and private-symbol stores through an attached proxy, which land on the global object (lookup-inl.h GetStoreTarget).

**What Happened**: Lane v8up's port compiled clean against 15.7.112.43, but Crane's Window and worker realms reach the hidden global object in eight places: the Window instance in the global object's internal field 0, the traced-edge holder of a live Window, a weak handle to the old global object when the WindowProxy moves to a new realm, severing the Window at the navigable's end, a detached realm's handles kept "from its hidden global object, never its proxy", and the Streams size functions' cache. That is realm teardown and handle ownership, so the batch escalated for a design decision instead of patching sites.

**Fix**: Decide the global-object model first (Blink's WrapGlobal with a Wrappable, or the context as the lifetime stand-in for a detached global), then port the sites; per-realm private state can go through the attached proxy.

**Takeaway**: **When an engine renames a deprecated V2 API back to the old name, grep every caller of the OLD name: each one compiles and changes meaning.**
