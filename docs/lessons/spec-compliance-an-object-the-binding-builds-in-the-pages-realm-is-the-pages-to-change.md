# Spec Compliance: An object the binding builds in the page's realm is the page's to change - no prototype, own data fields, and never a name looked up on the global

**Date**: 2026-11-13
**Lesson**: A spec's internal algorithm reads records and internal slots. When the binding implements it with script-level pieces - a Proxy handler object, a property-descriptor object, a call to `Reflect.x` found on the global - each piece is an ordinary object in the page's realm, and the page can replace what it inherits or what its name resolves to. Then an operation no browser lets script see calls the page's code, or aborts.

**Why**: Three instances in one function family (v8_wrapper.cpp, the Proxy around a legacy platform object with named properties, and the descriptors its interceptors answer):
- the proxy's traps called `context->Global()->Get("Reflect")` at each call and cast the result unchecked: `delete globalThis.Reflect; "x" in document.body.children` was "Fatal error in v8::ToLocalChecked", and a replaced `Reflect.has` was called with the proxy's raw target;
- the handler was `Object::New(isolate)`, so it inherited from %Object.prototype%, and a proxy finds its traps with GetMethod(handler, name): the handler had no own "get", so `Object.prototype.get = f` became every such object's [[Get]] trap;
- the descriptor an interceptor hands V8 was an ordinary object filled with [[Set]], and V8 reads it back with ToPropertyDescriptor (HasProperty and Get of each field): a `get` on Object.prototype made every descriptor "Invalid property descriptor", and a setter there named "value" was called instead of the field being made. The set trap asked `desc->Has("get")`, the same mistake reading.
WebIDL 3.9's algorithms for these internal methods read the object's supported property indices and names and its own properties - nothing of a global or of Object.prototype.

**What Happened**: Lane wrap1 batch 2 was asked to make the handler one per realm (it cost 3,860 B per wrapper) and to show first that script cannot observe it. Writing that proof found the three holes: a test that set `Object.prototype.get` got "hijacked" from `el.children.length`; reading the traps to see what they did with their arguments found the `Reflect` lookups. tests/v8/wrap1_legacy_proxy_traps_test.zig asks one object every internal method before and after each tampering and compares the answers; tests/wpt/crane/wrap1-legacy-platform-object-no-script-calls.html does the same in a page, across an iframe.

**Fix**:
1. A helper object handed to the engine has NO prototype (`Object::New(isolate, Null(isolate), nullptr, nullptr, 0)`) and gets its fields by CreateDataProperty, never [[Set]]. If it lives longer than one call, freeze it.
2. Read a field of an engine-made record object with HasOwnProperty, not [[HasProperty]].
3. Never resolve an intrinsic by name on the global at call time. Ask the engine's API for the operation on the object (Object::GetOwnPropertyNames, Object::GetOwnPropertyDescriptor, Object::DefineProperty, Object::CreateDataProperty), or capture the intrinsic when the realm is made, before any script runs.
4. A Proxy trap that only forwards is a liability: delete it. ES 10.5 forwards a missing trap to the target natively.
5. Build a result array with its elements (`Array::New(isolate, elements, n)`): a [[Set]] per index runs a setter the page put on Array.prototype.
6. Test it by tampering: delete and replace the global's `Reflect`, put functions and accessors named like trap names and descriptor fields on Object.prototype, then ask every internal method and compare with the untampered answers. A browser passes that test by construction.

**Takeaway**: **Whatever the binding builds out of the page's realm - an object with the default prototype, a property of the global - the page can change. Give helper objects no prototype and own data fields, ask the engine's API instead of a global's name, and prove it with a page that has tampered with both.**
