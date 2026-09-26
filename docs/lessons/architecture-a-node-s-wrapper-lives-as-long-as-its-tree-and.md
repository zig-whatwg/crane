# Architecture: A node's wrapper lives as long as its tree, and so does the node

**Date**: 2026-09-22
**Lesson**: V8 collecting the wrapper of a node nobody references in JS
destroyed the node, even when the node was still in the document.

**Why**: `wrapper_cache.weakCallback` treated "JS dropped the wrapper" as "the
instance is garbage" and called `gc.onObjectFreed`. For a node, the tree still
holds it - its parent's child list points at the instance - and V8 cannot see
that pointer. The parent was left holding a freed child.

**What Happened**: three unrelated-looking crashes were this. The teardown
walks in `location-protocol-setter-non-broken.html` and `Node-cloneNode.html`
read freed children. `connected-callbacks.html` died with a SIGTRAP in
`LookupIterator::GetRootForNonJSReceiver` because an iframe document's wrapper
was collected while its window still aliased it. The probe
`tests/wpt/crane/gc-keeps-connected-nodes.html` makes it plain:
`getElementById` returned null after two collections.

**Fix**: the browsers' design, not a guard. WebKit keeps a node's wrapper alive
while its tree is (`JSNodeOwner::isReachableFromOpaqueRoots` in
`Source/WebCore/bindings/js/JSNodeCustom.cpp`); Blink traces it through the
node. With `Global` handles that is two predicates in `wrapper_cache.zig`:

- **Instance lifetime** (`engineOwns`): a node with a parent, or a document
  with a default view, is never freed by its wrapper's weak callback - only
  the wrapper is released. Its tree frees it.
- **Wrapper strength**: strong while the node has a parent, weak once it is a
  root. The insertion and removing steps flip it (`installTreeHooks`), reading
  each node's own parent - the removing steps visit a whole removed subtree,
  but only its root loses a parent. A document's wrapper is held from
  `Document.setDefaultView` on (`holdStrong`).

**What remains**: `markAsCleanedUp` still ClearWeaks the wrapper of every node
torn down, so those are held until the page ends, and a wrapper reachable only
through a strong `Global` (an event listener's closure, say) is held with it.
Both predate this. The real fix is tracing (`TracedReference` and
`EmbedderRootsHandler` in `jsengines/v8/include/v8-embedder-heap.h`, or cppgc).

**Measured**: probe 0/1 -> 2/2 (identity and expandos survive a collection);
connected-callbacks exit 134 -> exit 0 on 3 of 3 runs; the protocol-setter file
SEGV 3/3 -> 0/3; Node-cloneNode teardown SEGV -> clean 3/3; timers x3 0
crashes; `gc_bench` 50k cycles 4112 -> 4127 B/element (noise).

**Takeaway**: **"JS no longer references the wrapper" and "nothing references
the object" are different claims.** Only the engine knows about the second one,
so the weak callback has to ask it before freeing anything.
