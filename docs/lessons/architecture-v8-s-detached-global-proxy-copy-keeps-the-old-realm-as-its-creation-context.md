# Architecture: V8's detached copy of a global proxy can keep the old realm as its creation context

**Date**: 2026-11-11
**Lesson**: In a detached context, V8 15.7 hands native accessors and interceptors a COPY of the global proxy as Holder(): `global_proxy_for_api`, which `Isolate::DetachGlobal` makes. The copy has empty embedder fields. Its creation context, though, is not always empty, and in a page it was the OLD context.

**Why**: DetachGlobal copies the proxy first. It then calls `JSObject::ForceSetPrototype(proxy, null)`, which gives the PROXY a new map, and it makes only that new map contextless (meta map, null constructor). The copy keeps the old map. `JSReceiver::GetCreationContext` reads the meta map's native context, so for the copy it answers the old realm.

**What Happened**: Lane v8up's receiver rule (realm_global.receiverRealm) recognised the copy as "every field empty and no creation context". The tests/v8 case for a lazy interface object passed, but in a real page (the Crane test v8up-old-realm-contextual-window.html) the old realm's first `typeof DOMParser` after its frame navigated answered undefined. Chrome 157 answers undefined too, by the same V8 mechanism. Firefox 159 and Safari 27 give the old realm's interface object. A temporary print in the lazy getter showed the page's Holder(): field 0 empty, not the context's Global(), and with a creation context. The bug-finding runner was built with the print and run on the Crane test; it cost one build.

**Fix**: `isDetachedGlobalCopy(current, object)`: the global's internal field count, field 0 empty, and either no creation context or `current` itself (compared by the contexts' Crane ids). tests/v8/v8up_old_realm_members_test.zig makes the agent, the page and both frames from the snapshot, as a page's are.

**Takeaway**: **When a unit test and a page disagree about an engine object, print the object's facts in the page's own build before theorising: one diagnostic run named the difference that two readings of V8 had missed.**
