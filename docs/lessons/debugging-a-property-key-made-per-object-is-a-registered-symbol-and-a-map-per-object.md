# Debugging: A private property key made per object is a registered symbol and a map transition per object

**Date**: 2026-11-13
**Lesson**: `v8::Private::ForApi(isolate, name)` interns the name for the isolate's life, and a property under a key no other object has gives its object a map of its own. An edge named after the address of the thing it keeps therefore costs a symbol that is never freed and a transition per owner - on the OWNER's wrapper, not on the kept object's.

**Why**: Private::ForApi looks the name up in the isolate's api private symbol table and adds a new private symbol when it is missing (15.7.112.43 src/api/api.cc:9797-9805, src/execution/isolate.cc:7175-7200); nothing removes an entry. A unique key per object means a new transition from the wrapper's map for each owner, and past V8's limit of 1,536 transitions from one map (src/objects/transitions.h:149) each further wrapper becomes a dictionary-mode object with its own property dictionary. `engine.traceChild(owner, child, slot)` draws its edge as such a private property named "crane:traced:" + slot.name, and src/webidl/impls/Element.zig `attrSlot` names an element's edge to each of its Attr nodes "attr:{address of the Attr}".

**What Happened**: Lane wrap1 batch 2 measured a kept Attr wrapper at 223-228 B of V8 heap where a div's is 21. Rows that separate it (production gc_bench, slopes at 50,000 and 100,000 kept, V8 heap per kept element): a div 21.0 B; a div with an attribute 21.0; a div whose Attr was read ONCE and not kept 241.2; an Attr alone (createAttribute) 21.0; a div with one expando 39.8. So the Attr's wrapper is as light as any node's: the 220 B is on the element, whose wrapper is also no longer an unmodified object V8 may drop in a scavenge. The diagnosis took the rows and one grep for the slot's name. The same pattern is in performance_timeline.zig entrySlot, drag_data_store.zig itemSlot and element_references.zig cacheSlot. (Diagnosed only: the fix belongs to the node-wrapper work.)

**Fix**:
1. Keep the set of private keys bounded: one constant name per kind of edge. An owner that keeps many children of one kind holds them in ONE property - a JS array or Map under the constant key - or keeps them by its own trace when they are nodes (the walk, VTable.trace_held_nodes).
2. When a kept object looks expensive, measure the owner alone, the owner having touched the object once, and the object alone: the difference says which wrapper pays.
3. Grep for slot names built with a formatter (`bufPrint` near `TracedSlot`): each is a key per object.

**Takeaway**: **A key is shared or it is a leak: name an edge by what it is, never by the address of what it keeps.**
