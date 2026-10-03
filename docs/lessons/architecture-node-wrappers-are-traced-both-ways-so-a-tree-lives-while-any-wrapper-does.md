# Architecture: Node wrappers are traced both ways, so a tree lives exactly as long as script reaches any wrapper in it

**Date**: 2026-10-02
**Lesson**: A node's wrapper used to be strong while the node had a parent and weak as a root, so a detached tree's root was collected as soon as script let go of it - and its teardown freed the subtree under a node script still held. Node tracing replaces the strength rule: every wrapped node's wrapper keeps its parent's, every parent's keeps its wrapped children's (private-property edges, never roots), and a wrapped node's parent is always wrapped.

**Why**: Blink's Node::Trace visits the parent and the children; WebKit keeps a node's wrapper while the opaque root of its tree is reachable. Both make the tree one unit for the collector. With Global handles the only way to say "this wrapper is reachable from that one" is an edge the collector traces - a private property on the wrapper. An edge from child to parent alone would have kept every tree forever (the parented child's wrapper was a strong root); parent to children alone would not keep the root. Both, and no strength rule, is the shape that works.

**What Happened**: gc_bench's `p.appendChild(div).attachShadow(...)` threw InvalidStateError after thousands of cycles (realms2 diagnosed it with a lifecycle ring buffer: the section was collected between the two calls and its teardown freed the div). crane/r3-detached-tree-child-keeps-root.html - script holds only a span inside a detached section/div tree - threw InvalidStateError on main.

**Fix** (wrapper_cache.zig `drawTreeEdges` / `eraseTreeEdges`):
1. `WrapperCache.set` for a node with a parent draws both edges, wrapping the unwrapped ancestors first, top-down - each wrap draws its own one-level edges, so a deep tree never recurses - and holds their wrappers until the edges are drawn (a root made and collected in between would free the tree under the wrap).
2. The insertion steps draw them for a wrapped node that gained a parent; the removing steps erase them for the removed subtree's ROOT only (the hook visits every descendant: act only when `parent_node` is null); the moving steps (moveBefore, which runs neither) move them.
3. `shouldBeStrong` no longer counts a parented node; `engineOwns` still does for the instance (a parented node whose wrapper dies is kept - which now happens only when its whole tree's wrappers die together, and the root's teardown frees it).
4. A window's document stays strong (holdStrong): its wrapped nodes hang from it.
5. A whole tree now dies in ONE collection, so its entries can all be pending at once. Every finalizer
   path must leave a parented node to its root's teardown: the realm-end branch of `finalizeEntry`
   freed a pending parented node first, and the root's teardown then walked into it (a segfault in
   Node.deinit at the page's end, gc_bench's shadow bodies).

**Takeaway**: **Keep a graph alive by edges between wrappers, never by making members strong: strength roots the member, edges let the collector keep or take the whole graph - and make sure every wrapped member's path to the graph's root is made of wrappers.**
