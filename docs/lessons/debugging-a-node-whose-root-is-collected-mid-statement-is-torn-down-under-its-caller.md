# Debugging: A node whose tree root is collected mid-statement is torn down under its caller - a node does not keep its root

**Date**: 2026-10-01
**Lesson**: gc_bench's `{ const p = section; p.appendChild(div).attachShadow(...) }` threw InvalidStateError from attachShadow after thousands of cycles because a collection that ran between `appendChild` returning and `attachShadow` being called collected `p` (its last use was done) and `p`'s teardown freed its whole subtree - including `div`, whose wrapper was on the stack as the receiver.

**Why**: A node's wrapper is held strongly while the node has a parent (so its tree keeps it), but nothing keeps the tree's ROOT alive while a descendant's wrapper is reachable: Blink traces a node's parent (Node::Trace visits parent_or_shadow_host_node_), WebKit keeps the opaque root of every reachable wrapper. A root collected while a descendant is in use tears the descendant down. Adding a child-to-parent edge alone would leak (the child's wrapper is a strong root while parented, so the tree would never go): the real fix is the tree traced both ways, with no node wrapper a root.

**What Happened**: The handoff called it "a stale teardown at a recycled address". A scratch ring buffer of lifecycle events (slab alloc/free, Element/ShadowRoot/Node deinit, releaseStorage, appendChild and attachShadow receivers, with a thread-local "path" marking weak-callback vs tree-walk callers), dumped for the failing address, showed no recycling at all: the div was allocated and appended 50,000 events earlier, torn down by a weak callback's tree walk (its section, allocated in the same cycle, collected), and called three events later.

**Fix**: Not in this batch: needs node wrappers weak and traced both ways (parent -> children, child -> parent). Diagnosis only; the same root cause makes a shadow root whose host's tree was collected answer InvalidStateError for `host`.

**Takeaway**: **"Stale teardown at a recycled address" is a hypothesis: record every lifecycle event for the address before believing it - here the address was never recycled, the object was freed while in use.**
