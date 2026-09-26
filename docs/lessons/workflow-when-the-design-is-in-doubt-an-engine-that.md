# Workflow: When the design is in doubt, an engine that shipped it is one fetch away

**Date**: 2026-09-22
**Lesson**: Read how V8, WebKit, Blink or Gecko solved a problem before
inventing a mechanism for it. The specs say what; the engines say how.

**What Happened**: V8 collecting the wrapper of an unreferenced node destroyed
a node that was still in the tree (`tests/wpt/crane/gc-keeps-connected-nodes.html`
- `getElementById` returned null after two collections), and that dangling
child is what the teardown crashes in `location-protocol-setter-non-broken.html`
and `Node-cloneNode.html` were walking into. The first fix written was an
ad-hoc guard: "if the node has a parent, drop only the wrapper and keep the
instance". Ten minutes of reading gave the actual design:

- WebKit, `Source/WebCore/bindings/js/JSNodeCustom.cpp`:
  `JSNodeOwner::isReachableFromOpaqueRoots` keeps a node's wrapper alive while
  its tree root is an opaque root (`containsWebCoreOpaqueRoot(visitor, node)`),
  so a connected node's wrapper is NEVER collected, and a disconnected one
  survives only while held by a `GCReachableRef` or a custom-element reaction
  queue.
- Blink reaches the same outcome by tracing the wrapper through the node.
- V8's own `jsengines/v8/include/v8-embedder-heap.h` and `v8-traced-handle.h`
  document the roots API built for exactly this decision.

So the policy is "strong while connected, weak once removed" - identity and
expandos survive a GC, as they do in every browser - and the guard is the
safety net behind it, not the design. The two theories and three rounds of
instrumentation spent on the crash before that were spent on WHAT was
happening; none of them could have said what the right behaviour was.

**Fix**: the "Stuck on HOW" rule and its table, above.

**Takeaway**: **When you are naming a mechanism yourself, stop and check
whether Blink or WebKit already has a name for it. They usually do, and the
name comes with ten years of edge cases.**
