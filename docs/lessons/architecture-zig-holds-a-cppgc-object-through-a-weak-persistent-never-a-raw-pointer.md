# Architecture: Zig holds a cppgc object through a WeakPersistent, never a raw pointer its finalizer clears

**Date**: 2026-11-11
**Lesson**: When Zig code must reach a cppgc object that only JS objects keep alive (a realm global's GlobalAnchor after a navigation), hold a `cppgc::WeakPersistent<T>` made in the adapter, not a raw pointer that the object's destructor nulls.

**Why**: cppgc decides an object is dead in the collection's atomic pause, but runs its finalizer later, at sweep, which can be lazy and run inside any allocation on the C++ heap. Between the two the object's memory is still there, but what it references is not: a `TracedReference` member's node was freed with the rest of the dead graph. A raw pointer cleared by the finalizer therefore reads "alive" across that whole window. A WeakPersistent is cleared in the atomic pause itself, so `Get()` answers null from the moment the object is dead.

**What Happened**: Lane v8up b3c replaced the weak handle to a navigated-away realm's hidden global (which V8 >= 14 no longer lets an embedder make, crbug.com/333672197) with Blink's model: `Object::WrapGlobal` sets a GlobalAnchor on the global proxy and its hidden JSGlobalObject, and the old global keeps its anchor after the proxy is handed on. The plan of record said "the anchor's finalizer is the signal that the old global object is gone". Reading cppgc's phases before writing it showed that a finalizer-cleared pointer would let `tracedEdgeHolderOfWindow` read a dead anchor's retained store between the pause and the sweep.

**Fix**: `GlobalAnchorRef = cppgc::WeakPersistent<GlobalAnchor>`, created by the attach function and kept on the realm's context-manager entry. Every C++ entry point reads `ref->Get()` first, before it allocates anything. The ref is disposed on the agent's thread when the entry retires, before the heap ends. The anchor's destructor does nothing (src/runtime/engines/v8/realm_global.zig, v8_wrapper.cpp GlobalAnchor).

**Takeaway**: **"Dead" in cppgc is decided at the atomic pause, not at the finalizer: an untraced reference from outside the heap is a WeakPersistent, read before anything allocates.**
