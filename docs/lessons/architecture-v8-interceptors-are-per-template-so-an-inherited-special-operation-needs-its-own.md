# Architecture: V8 interceptors are per template, so an inherited special operation needs handlers on every derived template

**Date**: 2026-10-05 (recorded 2026-10-16, when binding3 resumed)
**Lesson**: A V8 map takes its named and indexed interceptors from its own constructor's FunctionTemplate only (`api-natives.cc`: `has_named_interceptor` / `has_indexed_interceptor` from the template itself), so a getter registered on HTMLCollection's template serves no HTMLOptionsCollection object.

**Why**: WebIDL 3.9 says the derived-most special operation defines the behavior - an inherited indexed getter is still the derived interface's indexed getter. FunctionTemplate::Inherit links the prototype objects, not the instance templates' handlers.

**What Happened**: The binding registered handlers only where the generated interface itself had `call_item(u32)` (and found named getters by three function names). HTMLOptionsCollection (item() from HTMLCollection) and RadioNodeList (item() from NodeList) had no indexed handler at all; anonymous getters (`getter TextTrack (unsigned long index)`, HTMLFormElement's) were not recognised; Storage's `getItem`/`setItem`/`removeItem` were never its named handlers, so `sessionStorage.x = "1"` made a plain JS property (resource-timing nested-context-navigations looped until TIMEOUT). A related V8 fact: an array index key (`localStorage[9]`) reaches only indexed interceptors, so an interface with named but no indexed properties needs indexed handlers that pass the index on as its String.

**Fix**: Codegen states each interface's special operations - its own, then the derived-most inherited one for each variety - in `Meta.special_operations`, and an heir re-exports the inherited functions; the binding registers the handlers on every template that has one, plus index-to-named handlers for named-only interfaces (lane specops 1f9e9ce980, 73ec2a9f24, aa96793924; HTMLOptionsCollection 3051fdffb8). binding3's first version of the same fix (a9027d5d74, 64b86b1a23, 2026-10-05) was parked and superseded by those.

**Takeaway**: **Ask the IDL which operation is special, and register its handlers on every derived template - V8 will not inherit them for you.**
