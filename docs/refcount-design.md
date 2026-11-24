# DOM reference counting: design

Provenance: moved word for word from tmp/plans/refcount-design.md (untracked) on 2026-11-23 by lane flk4, at the integrator's request, so tracked code points at a tracked file. The user's decisions on its section 8 are docs/refcount-decisions.md. Paths in it that start with tmp/ are untracked lane notes.

Status (2026-11-23): steps 1 through 7b have merged (docs/roadmap.toml, the `lifetime` progress lines). The text below is kept as written; these sections no longer match the merged code: section 0 (Crane before the migration, at 6d70c36506); section 5.1 and section 5.3 item 6 (NodeBase is 88 B since the node memory redesign, cefe4044a, 2026-11-13 - not 440, 448 or 456 B); section 6.1 (src/html/parser_holds.zig is gone, but src/dom/node_holds.zig stays as the home of the counted holds - MemberHold, RefHold, CountedRef, ReachableHold, TaskHold - and generation checks were not retired: 1,088 `SlabAllocator.generationOf` calls in 276 files of src/ against the 561 in 139 that section 0 counts); section 7 steps 8 to 10 (step 8, listeners traced from their target, is `doing` on the roadmap; step 9's deletions and step 10, phase 2, have not run).

Lane `refcount`, 2026-10-09. Read-only design: no source file was changed and nothing was built.
Brief: tmp/orchestration/briefs/refcount-design.md. The user's decision (2026-10-09, docs/roadmap.toml
`lifetime` progress line, 6d70c36506): Crane's DOM lifetime model becomes reference counting, WebKit's
model, not Oilpan. One model under V8 and JavaScriptCore, and no more hand-written holds.

Citations: Crane as `path:line function` at main 6d70c36506 unless a lane is named. WebKit paths are
under https://github.com/WebKit/WebKit (main, read 2026-10-09). Gecko paths are under
https://github.com/mozilla-firefox/firefox (main). Blink paths are under https://github.com/chromium/chromium.
V8 is the local 13.1 headers in `jsengines/v8/include/`.

---

## 0. Where Crane is today, in one paragraph

A node is a slab `Instance` (24 B, plus an 8 B generation in its 32 B slot: src/runtime/slab_allocator.zig:27
`Slot`), an arena state block, a separately allocated `NodeBase` (src/webidl/impls/Node.zig:173 `init`), and
entries in address-keyed registries. Nothing counts references. A node is freed in one of three ways:

- its tree's root wrapper is collected, and the second pass frees the subtree
  (src/runtime/engines/v8/wrapper_cache.zig:682 `finalizeEntry`; lane/defertd queues this as slices);
- its realm ends (`WrapperCache.deinit`, wrapper_cache.zig:1094; the coordinated teardown in
  src/runtime/cleanup_coordinator.zig:60 `CleanupPhase`);
- a parser frees a node it made and never inserted (`dom.node_creation.destroyUninserted` →
  Node.zig:376 `deinitNodeByType`).

So whatever keeps a node alive must keep a *wrapper* alive. That is why:

- node tracing wraps every ancestor of a wrapped node (wrapper_cache.zig:430 `drawTreeEdges`);
- the parser and the node holders "rescue" a detached root by tracing one wrapper (src/html/parser_holds.zig;
  lane/nodeholds src/dom/node_holds.zig `Holder.rescue`);
- 561 `SlabAllocator.generationOf` calls in 139 files guard bare pointers;
- a never-wrapped detached tree is freed by nothing until its realm ends (tmp/plans/feature-queue.md:544
  RETENTION).

Reference counting moves ownership into the native objects themselves.

---

## 1. The model

### 1.1 Precedent: WebKit

- **The count word.** `mutable uint32_t m_refCountAndParentBit { s_refCountIncrement }`, with
  `s_refCountIncrement = 2` and `s_refCountMask = ~1` (Source/WebCore/dom/Node.h). Bit 0 is the
  parent bit. `Node::setParentNode` writes
  `m_refCountAndParentBit = (m_refCountAndParentBit & s_refCountMask) | !!parent`
  (Source/WebCore/dom/NodeInlines.h).
- **ref and deref.** Both assert `isMainThread()`. `Node::deref` calls `removedLastRef()` when the word
  reaches 0 (Node.h). A node with a parent never reaches 0, so the parent holds its child through the bit.
- **removedLastRef.** `Node::removedLastRef` special-cases Document and otherwise runs `delete this`
  (Source/WebCore/dom/Node.cpp).
- **Children are torn down by the parent.** `ContainerNode::~ContainerNode` calls `removeDetachedChildren`
  (Source/WebCore/dom/ContainerNode.cpp). That ends in `removeDetachedChildrenInContainer`
  (Source/WebCore/dom/ContainerNodeAlgorithms.cpp), which unlinks every child with
  `setParentNode(nullptr)`. A child whose `refCount() > 1` survives as a new root
  (`updateShadowIncludingRootForSubtree`).
- **child → parent is not owning.** `m_parentNode`, `m_previousSibling` and `m_next` are
  `CheckedPtr`s (Node.h). `Node::~Node` asserts `!parentNode()` (Node.cpp).
- **The document has a second count.** Every node calls `document.incrementReferencingNodeCount()` in
  `Node::Node` and decrements it in `Node::~Node`, with the comment "This may destroy the document"
  (Node.cpp). Document.h explains the count: these "are enough to keep the document from being destroyed,
  but not enough to keep it from removing its children ... without introducing reference cycles".
  `Document::removedLastRef` clears its element pointers "or we will create a reference cycle", runs
  `destroyTreeScopeData`, `removeDetachedChildren` and `commonTeardown`, and may be "resurrected"
  (Source/WebCore/dom/Document.cpp).
- **Sub-objects forward their count.** `NamedNodeMap::ref()` is `m_element->ref()`
  (Source/WebCore/dom/NamedNodeMap.cpp), and `m_element` is a `WeakRef<Element>` (NamedNodeMap.h).
- **Deferred deletion.** `ContainerNode::removeAllChildrenWithScriptAssertionMaybeAsync` hands removed
  children to `asyncNodeDeletionQueue().addIfSubtreeSizeIsUnderLimit` (ContainerNode.cpp). The queue is a
  `Vector<Ref<Node>>` capped by `s_maxSizeAsyncNodeDeletionQueue = 100000`
  (Source/WebCore/dom/AsyncNodeDeletionQueue.h).

### 1.2 Who holds a counted reference (`Ref`)

| Holder | Counted? | Kind | Precedent |
|---|---|---|---|
| A node's wrapper (a node has one, `NodeBase.bound_v8_wrapper`) | yes, one | `Ref` | JSDOMWrapper holds `Ref<T>`; pre-Oilpan Blink's `secondWeakCallback` derefed the object (docs/lessons/architecture-a-collected-wrapper-s-instance-is-torn-down-in-v8-s-second-pass.md) |
| Native holders that are platform objects: static NodeList, MutationRecord, Range/StaticRange boundary containers, NodeIterator/TreeWalker root and reference, Event target / relatedTarget, Selection | yes | `Ref` | WebKit `ChildListRecord`: `Ref<ContainerNode> m_target`, `RefPtr<Node> m_previousSibling` (Source/WebCore/dom/MutationRecord.cpp) |
| Tasks and queues that will hand the node to script: element fetch completions, toggle/load tasks, custom element reaction queues, a MutationObserver's pending targets and transient registrations | yes | `GCReachableRef` (a `Ref` that also keeps the wrapper; §2.4) | `Node::queueTaskKeepingNodeAlive` captures `GCReachableRef(node)` (NodeInlines.h); `MutationObserver::m_pendingTargets` is `HashSet<GCReachableRef<Node>>` (MutationObserver.h); `m_transientRegistrationNodes` (MutationObserverRegistration.h) |
| The parser: stack of open elements, active formatting list, head/form pointers, the adapter's node map, nodes held across a move | yes | `Ref` | HTMLElementStack records own their nodes with RefPtr (cited in src/html/parser_holds.zig:8) |
| A Window's document; a navigable's active document | yes | `Ref` | — |
| The creator of a node until it hands the node on (createElement → binding; parser → insertion) | yes, the initial reference | `Ref` (adopted) | `m_refCountAndParentBit { s_refCountIncrement }`: a node is born with one reference |
| A stack frame across a step that can run script or drain the teardown queue | yes | `Ref` | `Ref protectedThis`, `Ref protectedOldChild` in `ContainerNode::removeChild` (ContainerNode.cpp) |

**Structural links (alive with their tree, no count of their own):**
- parent → child: the parent bit, as WebKit does;
- a shadow host → its shadow root;
- a template → its contents.

A child, a shadow root and a template's contents live exactly as long as their tree (§1.4). Today these
are `treeOwns` and `templateOwns` (wrapper_cache.zig:291 and :263). The rule matches Blink, whose
`Node::Trace` visits `parent_or_shadow_host_node_` (third_party/blink/renderer/core/dom/node.cc).

### 1.3 What is raw (never counted)

- child → parent and the sibling links. These are `CheckedPtr` in WebKit (Node.h). In Crane they stay the
  plain `NodeBase` pointers, and every write goes through one setter (§7, step 3).
- node → owner document. The Document keeps a separate `referencing_nodes` count for its own storage, as
  WebKit does (§1.5).
- node → wrapper (`NodeBase.bound_v8_wrapper`). This is weak: the V8 first pass clears it
  (wrapper_cache.zig:642 `unlinkCollected`).
- shadow root → host, and template contents → template.
- Registry entries in documents and elements: id/name maps, script queues, style sheet owners, the focused
  area, the target element, the form owner and a form's controls, the live-range and NodeIterator lists,
  and the observers' node lists. These are raw pointers that the removal or the free unregisters. Where no
  unregistration exists, they are `WeakRef(Node)` (pointer + slab generation, §7, step 2). A registry never
  counts: a node kept alive by its own registration would be a cycle with no external owner.
- Every node → node relation outside the tree: form owner, label ↔ control, popover invoker, assigned slot.
  WebKit keeps these as `WeakPtr`/`WeakRef`. A lint enforces the rule: no `Ref(Node)` field inside a node's
  own state, apart from the two structural links above (§7, step 2).

### 1.4 When a node is freed: the tree is the unit

A node in a tree has no count of its own: its tree decides. **A tree is alive while any node in it is held**,
and a held node is one with a non-zero count other than the parent bit. The tree's root counts as a node. A
Window's document is held by its Window, so its tree is alive for the Window's life. When the last hold
anywhere in a tree goes, the whole tree is garbage, and its root goes to the agent's deferred teardown queue.

This is the one deliberate departure from WebKit, and it is **Decision D1**. WebKit lets an unreferenced
ancestor die and leaves a referenced descendant as a new root (`removeDetachedChildrenInContainer`, the
`refCount() > 1` branch; `Node::~Node` asserts `!parentNode()`). For example:

```js
d.innerHTML = '<p><span></span></p>';
s = d.querySelector('span');
d.innerHTML = '';
```

After this, `s.parentNode` should read null in Safari, and the old `<p>` in Chrome and Firefox:
- Blink traces the parent (`Node::Trace`).
- Gecko's child owns its parent: "mParent is an owning ref most of the time" (dom/base/nsINode.h).

Golden rule 2 takes the majority. A Crane test should confirm the Safari reading before D1 is settled. The
semantics are also what Crane implements today (node tracing keeps a wrapped node's tree), so D1 changes
no behaviour.

**The mechanism: `subtree_holds`.** Each `NodeBase` gets a `subtree_holds: u32`: the number of held nodes
in its host-including subtree, itself included. It changes in three places:

- **A hold appears or ends.** When a node's own count goes 0 → 1, add 1 to it and to each host-including
  ancestor (parent, else the host of a shadow root or a template's contents). The walk is O(depth), and
  1 → 0 subtracts the same way.
- **A subtree S moves.** Removal subtracts `S.subtree_holds` along the old parent's chain. Insertion adds it
  along the new one. Both are skipped when `S.subtree_holds == 0`, which is the parse and innerHTML case.
- **The root's total reaches 0.** When the root's `subtree_holds` reaches 0 and the root is not queued
  already, the tree is garbage.

Nothing here is a reference, so nothing can cycle: holds come only from the non-tree holders of §1.2.

**Freeing goes through defertd's queue: "deref to zero frees later".** Lane defertd added
`runtime.gc.DeferredTeardown` (lane/defertd src/runtime/gc_integration.zig). Its doc comment already names
"an object whose reference count reached zero, once the DOM counts references". The agent's `AgentHost`
owns it. It frees in slices of `slice_budget` = 512 nodes between tasks, with `high_water` = 100,000 and
`loop_low_water` = 25,000. Garbage trees use it like this:

1. **Enqueue.** The step that made the tree garbage pushes the root, with refcount steps in place of
   `runCollectedNode` (lane/defertd wrapper_cache.zig:843). That step can be a deref, a removal or a
   wrapper's second pass. It also sets a GARBAGE flag on the root. Nothing is freed inline.
2. **Re-check at slice time.** The steps re-check that the root is still parentless, its `subtree_holds` is
   still 0, and (for a Document, §1.5) it has no outside holds. A failed re-check clears the flag and drops
   the item. That is a resurrection, which is a bug in Debug unless it is on an allowlist (§7, step 2).
3. **Free leaves-first.** The steps then free with `dom.tree_teardown.freeDescendants`
   (lane/defertd src/dom/tree_teardown.zig).
4. **Drains.** The queue drains at realm end (`drainOwner`), at agent end (`drainAll` then `close`), and
   under memory pressure, all as built.
5. **The item.** Today each item is a heap `Item`. For nodes it can be intrusive: a root's
   `previous_sibling` and `next_sibling` are null by invariant, so they can carry the queue links. Measure
   before doing that.
6. **Weight.** The weight that `queueCollectedNode` computes with `countUpTo` (an O(subtree) walk at push)
   is estimated in the first slice instead.

**"Count zero and no wrapper"** holds by construction: a wrapper owns one reference (§2.1), so a wrapped
node is held and its tree is not garbage. A garbage tree is unreachable from script and from every counted
holder.

**Weak references see garbage at once.** `WeakRef(Node).get()` returns null for a node in a GARBAGE tree
(an O(depth) walk to the root flag), as WebKit's WeakPtr does at deletion. A registry therefore cannot hand
a queued node back out.

### 1.5 The Document: two counts, and Blink's reading of the second

`Document` keeps two numbers of its own, in its state rather than in NodeBase:

- **`referencing_nodes`.** It goes up at node creation and at adoption in, and down at the free and at
  adoption out. The Document's storage is freed only when it is 0. Garbage trees of the same document can
  be queued in any order, and their teardowns read `owner_document`. That is the race this count closes,
  exactly as WebKit's `decrementReferencingNodeCount` does (Document.h).
- **`foreign_holds`.** This counts held nodes of this document that sit outside its tree, in detached
  subtrees. It is maintained in the same O(depth) walks: when the walk from a hold transition ends at a
  root that is not the node document, it counts there. A removal of S from the document's tree moves
  `S.subtree_holds` from the tree to `foreign_holds`, an insertion moves it back, and adoption moves it
  between documents. A document's tree is garbage only when `subtree_holds == 0` and `foreign_holds == 0`.
  This is Blink's behaviour: a held detached node keeps `ownerDocument.documentElement`. WebKit can tear
  the document down to a husk if nothing else references it (`Document::removedLastRef`). **Decision D6.**

### 1.6 Ownership in the types

The engine protocol already writes ownership into types (`engine.Owned`: exactly one of `release`/`take`;
docs/engine-protocol.md §2). The DOM's types follow it (§7, step 2):

- `Ref(T)` holds a counted reference. It ends with exactly one `release()` or a move. `clone()` takes
  another reference.
- `?Ref(T)` plays the role of `RefPtr`.
- `GCReachableRef(T)` is a `Ref` plus a counted wrapper keep (§2.4).
- `WeakRef(T)` is a raw pointer plus the slab generation, with `get() ?*T`. Generation checks remain in
  Crane only as the implementation of weak references.

---

## 2. Wrappers under V8 and JavaScriptCore

### 2.1 The wrapper owns one reference

- **Taking and releasing it.** The adapter takes the reference when it caches a wrapper
  (`WrapperCache.set`, wrapper_cache.zig:1382). It releases the reference in V8's second pass, where
  `finalizeEntry` runs today. Both are calls into the runtime, `runtime.lifetime.wrapperAcquired` and
  `wrapperReleased`, which dispatch through a new optional `VTable.counted` entry. A type with no entry
  keeps today's path (`gc.onObjectFreed`). The adapter therefore stops deciding anything about nodes.
- **What `finalizeEntry` loses for counted types.** These checks all go:
  - `slotReissued` and the generation check;
  - `treeOwns` and `templateOwns`;
  - `engineOwns`;
  - the scan of every live cache in `wrappedElsewhere`;
  - `isCleanupStarted`;
  - the `cleanup_coordinator.isContextTearingDown` branch.

  What is left is "dispose the handle; deref".
- **Wrapped again between the passes.** The new wrapper took its own reference, so the old wrapper's deref
  is simply one of two. Today that needs `wrappedAgain` (lane/defertd wrapper_cache.zig).
- **The wrapper's realm ends.** The node keeps its reference while the wrapper is alive, so the wrapper is
  not severed. The cache hands the entry to an agent-level list whose finalizer still derefs. Today
  `severWrapper` (wrapper_cache.zig:193) cuts it, and script in another realm gets a TypeError. Blink and
  WebKit keep the node, so this fixes feature-queue "cross-realm Instance lifetime" for nodes. Behaviour on
  a retired relevant realm stays the realm contract's (docs/engine-protocol.md, the Instance row).

### 2.2 The opaque-root rule

WebKit keeps a node's wrapper alive while the node's opaque root is reachable:

- `JSNode::visitAdditionalChildrenInGCThread` adds `wrapped()` as an opaque root
  (Source/WebCore/bindings/js/JSNodeCustom.cpp).
- `root(Node&)` is `node.opaqueRoot()` (JSNodeCustomInlines.h). That returns the cached
  `m_shadowIncludingRoot` (Node.h).
- `JSNodeOwner::isReachableFromOpaqueRoots` returns `containsWebCoreOpaqueRoot(visitor, node)`.
- A disconnected node is also kept when `GCReachableRefMap::contains(node) || node.isInCustomElementReactionQueue()`
  (JSNodeCustom.cpp).

The engine works this out while it marks: any reachable wrapper of a tree keeps every wrapper of that tree.

**V8 13.1 has no public way to work it out while marking, short of cppgc.**
- `EmbedderRootsHandler` is a "Handler for embedder roots on non-unified heap garbage collections" for
  young-generation droppability, and its `IsRoot` is deprecated (v8-embedder-heap.h).
- Object groups are gone: no `SetObjectGroupId` exists in the headers.
- The only tracing hook is `Isolate::AttachCppHeap` (v8-isolate.h:1081), which is the Oilpan the user
  declined.

So on V8 the rule stays **edges in the JS heap**, which is Crane's node tracing today:

- Every wrapped node's wrapper holds its parent's wrapper, and the parent's wrapper holds a Set of its
  wrapped children's wrappers (wrapper_cache.zig:411 `tree_parent_key`, `tree_children_key`).
- An unwrapped parent is wrapped first, so the wrapped part of a tree is upward-closed and strongly
  connected (wrapper_cache.zig:341 doc).
- Inserting or removing a subtree costs O(1) edges: only the subtree root's pair changes.

This is the opaque-root rule, built incrementally, and it is measured and pinned:
- tests/wpt/crane/gc-keeps-connected-nodes.html, crane/r3-detached-tree-child-keeps-root.html;
- tests/v8/parser_holds_invariants_test.zig (L1/L2).

**Decision D4** keeps it. A per-tree "root token" (an edge from each wrapper to the root's wrapper) avoids
wrapping ancestors but costs O(wrapped nodes in S) when S moves.

Reference counting changes who drives the edges:
- Memory safety no longer depends on them. A natively held tree lives without any wrapper (§1.4), so L1
  ("the collector frees a node only as the root of its tree") stops being a hazard rule.
- The host drives them through protocol operations. Today the adapter reaches into the DOM instead:
  `installTreeHooks` registers `dom.mutation` callbacks from inside src/runtime/engines/v8
  (wrapper_cache.zig:365), and `syncStrength` does a hash lookup for every inserted and removed node
  (wrapper_cache.zig:474). Under the new design the host calls the engine only for a wrapped subtree root,
  which is a pointer test (`bound_v8_wrapper`).

### 2.3 What the protocol must offer

These are named after the concern, per AGENTS.md "The engine boundary" rule 6. The integrator owns
engine_protocol.zig, and each operation is requested there.

| Operation | Concept | Replaces |
|---|---|---|
| contract change, 4.12: "a wrapper owns one reference to a counted instance; the adapter acquires it when it makes the wrapper and releases it, on the agent's thread and never inside a collection, when the wrapper is finalized" (engine → host through `runtime.lifetime`, not a protocol op) | JSDOMWrapper's `Ref<T>` | `gc.onObjectFreed` for counted types; engineOwns and the related predicates |
| `joinOpaqueRoot(member, parent)` | `member` (a subtree root just inserted under `parent`) now shares its opaque root with `parent`'s tree: any reachable wrapper of either keeps all of them | `onNodeInserted` + `drawTreeEdges` driven by the adapter's mutation hook |
| `leaveOpaqueRoot(member, old_parent)` | `member`'s subtree left `old_parent`'s tree and is its own opaque root | `onNodeRemoved` / `eraseTreeEdges`; `onNodeMoved` is a leave plus a join |
| `keepOpaqueRoot(owner, member, slot)` (ended by the existing `forgetTracedChild`) | `owner`'s wrapper keeps `member`'s opaque root: WebKit's non-node visitors, e.g. `ChildListRecord::visitNodesInGCThread` → `addWebCoreOpaqueRoot` (MutationRecord.cpp) | nodeholds' rescue (`Holder.rescue`, "node-holds:root(s)") and pholds' kept-roots array, which existed for memory safety. Now it is only for wrapper identity |
| `keepPlatformObjectAlive` / `releasePlatformObject`, made **counted** | ActiveDOMObject's `m_pendingActivityInstanceCount` / `PendingActivity` (Source/WebCore/dom/ActiveDOMObject.h); `GCReachableRefMap` is a `HashCountedSet` (Source/WebCore/dom/GCReachableRef.h) | the single `Holds.pending_activity` flag (wrapper_cache.zig:148), which fix-list D15 found cannot carry a second owner; the window document rule in `engineHoldsWrapper` (wrapper_cache.zig:271) becomes the Window's keep |
| unchanged: `hasWrapper`, `traceChild` / `traceValue` / `tracedValue` / `forgetTracedChild` | Blink `Member<>` / `TraceWrapperV8Reference` | — |
| `platformObjectDestroyed` | becomes a Debug assertion for counted types: a counted instance is freed only at count zero, so it has no wrapper | — |

`keepOpaqueRoot` on V8:
- It draws an edge from the owner's wrapper to the member's own wrapper when the member has one: a moved
  node takes its tree edges with it.
- Otherwise it draws the edge to the member's tree-root wrapper when that is wrapped. Upward closure means
  an unwrapped root implies no wrapper anywhere in that tree, so there is nothing to keep.
- An owner whose tree root is a document with a kept wrapper draws nothing, as nodeholds' `isKeptRoot`
  does.
- The gap against WebKit's GC-time reading: an unwrapped held node that moves into a tree that only later
  gets wrappers is not followed. It is stated in the operation's doc comment. Closing it needs the
  per-node hold chain (nodeholds' `NodeBase.holds`), which is kept only if a Crane test shows the gap
  (Decision D4).

### 2.4 Plain Ref versus GCReachableRef

A plain `Ref` keeps the native node. It does not keep the wrapper: if script drops every path to a
natively held detached tree, its wrappers are collected, and expandos and identity go with them, as in
WebKit.

A holder that will later hand the node to script, while no wrapper of its own reaches the node, takes a
`GCReachableRef`. That is a `Ref` plus a counted `keepPlatformObjectAlive` on the node's wrapper if it has
one. WebKit uses `GCReachableRef` for:
- tasks (`queueTaskKeepingNodeAlive`);
- pending mutation targets;
- custom element reaction queues (`isInCustomElementReactionQueue`).

Holders with a wrapper of their own (a delivered record, a static list) use `Ref` plus `keepOpaqueRoot`
instead.

### 2.5 JavaScriptCore (iOS)

The public C API constrains three things:

- **No visit hook.** `JSClassDefinition` has none: its members end at `convertToType`, and "current (and
  only) version is 0" (Source/JavaScriptCore/API/JSObjectRef.h).
- **Finalizers run anywhere and cannot allocate.** "An object may be finalized on any thread", and it must
  not call "any function that may cause a garbage collection or an allocation of a garbage collected object
  ... all functions that have a JSContextRef parameter" (JSObjectRef.h, `JSObjectFinalizeCallback`).
- **No weak handle.** The only GC calls are `JSValueProtect`/`JSValueUnprotect`, which are strong and
  counted: "may be protected multiple times and must be unprotected an equal number of times"
  (JSValueRef.h).

What the JSC adapter does (it wraps no platform object today; docs/engine-protocol.md §2):

1. **The wrapper's reference.**
   - A wrapper is `JSObjectMake(class, private = *Instance)` and takes one reference.
   - The class `finalize` only pushes the Instance onto the agent's **thread-safe released-wrappers list**
     (a lock-free MPSC list).
   - The agent drains the list at its next safe point, on its own thread, and derefs there. Counts never
     leave the agent thread (§4).
   - This is the 4.12 "queue the teardown" rule the protocol already states for JSC.
2. **Identity (node → wrapper, weak).**
   - The node keeps a `JSValueProtect`ed ES `WeakRef` made from the realm's pristine `WeakRef`
     constructor, and reads it through the pristine `WeakRef.prototype.deref` (`JSObjectCallAsFunction`).
   - `undefined` means collected: wrap again.
   - Each wrapper owns its own reference, so a drained finalizer for the old wrapper is just another deref.
3. **Opaque-root edges.**
   - A per-realm `WeakMap` from the pristine intrinsics maps each wrapper to an edge record, a plain object
     holding its parent's wrapper, its children's wrappers and its traced members.
   - WeakMap entries are ephemerons, so the record lives exactly while its key wrapper is reachable. That
     gives `traceChild`, `traceValue`, `joinOpaqueRoot` and `keepOpaqueRoot` the V8 semantics, invisible
     to script.
   - The protocol doc's current plan for JSC, "a private-symbol property", is not public:
     `JSValueMakeSymbol` (iOS 13) makes ordinary symbols, which `Reflect.ownKeys` shows. **Decision D5.**
4. **Strong keeps** (pending activity, the window's document) use `JSValueProtect`, which is counted, the
   same contract as §2.3.
5. **The Objective-C route, not taken.** `-[JSVirtualMachine addManagedReference:withOwner:]` (iOS 7,
   JSVirtualMachine.h) and `JSManagedValue`, a "conditionally retained" JSValue (JSManagedValue.h), are
   opaque roots in public API. They work only for owners that are Objective-C objects made reachable
   through the Objective-C bridge. The adapter's design is the C API's JSClass objects, so this would mean
   moving the adapter onto the bridge. Recommended instead: a feedback request for a C-API visit hook
   beside FB24953657/66/76 (memory: ask before filing).

QuickJS: upstream quickjs.h `JSClassDef.gc_mark` can report the edges natively. The adapter wraps nothing
today.

---

## 3. Cycles

The rule that makes a cycle collector unnecessary has two halves:

- **(R-a)** No native → JS strong reference exists except a root with a bounded reason: pending activity,
  a kept document, a timer's callback until it fires or is cleared, a promise reaction until it settles or
  its realm ends. Every other native → JS reference is an edge traced from the owner's wrapper.
- **(R-b)** No native reference other than the holders in §1.2 is counted. Tree links, back pointers,
  registries and node → node relations are all raw or weak.

Under R-a and R-b, every cycle passes through the JS heap, and the JS collector already breaks those.

| Possible cycle | Today | Broken by |
|---|---|---|
| node ↔ wrapper | wrapper → node is a pointer; node → wrapper is a weak alias | Wrapper → node is counted (§2.1); node → wrapper stays weak (`unlinkCollected` clears it). Wrappers of an unreachable tree die in one collection (their edges link them), their derefs make the tree garbage, and the queue frees it. |
| parent ↔ child, and node ↔ document | structural; ownership by tree | Child → parent is raw, and the tree is the unit (§1.4). Node → document is raw, plus `referencing_nodes` (§1.5). WebKit's `Document::removedLastRef` clears its element pointers "or we will create a reference cycle". |
| **event listener closure capturing its node** | `EventListenerRecord.callback` is an OWNED `engine.CallbackInterface` (src/webidl/impls/EventTarget.zig:37), a strong V8 Global cloned in `takeCallbackInterface` (src/runtime/engines/v8/protocol_callbacks.zig:506). Root → closure → wrapper → tree: a detached tree whose listener closes over it lives until its realm ends. | R-a. Listeners become values traced from the target's wrapper (`traceValue`, one fixed slot holding an array, never a key per listener, which is the D38 lesson). WebKit holds `JSC::Weak<JSC::JSObject> m_jsFunction` and marks it from the target's wrapper (`visitJSFunctionInGCThread`, Source/WebCore/bindings/js/JSEventListener.h). A listener can only fire while its target's wrapper is alive: connected nodes through the document's kept wrapper, pending loads through `GCReachableRef`. **Decision D7.** |
| MutationObserver callback ↔ observed nodes | callback is OWNED (MutationObserver.zig:46); the observer roots its own wrapper while registered (MutationObserver.zig:390 `keepPlatformObjectAlive`) | The callback is traced from the observer's wrapper. A node → registration → `Ref(observer)` link is native (WebKit: `const Ref<MutationObserver> m_observer`, with `WeakRef<Node> m_node`; MutationObserverRegistration.h). The observer's wrapper is kept by an edge from each observed node's wrapper. WebKit's `MutationObserver::isReachableFromOpaqueRoots` asks each registration (`registration.isReachableFromOpaqueRoots(visitor)`, MutationObserver.cpp). Drop the pending-activity root. |
| node ↔ registry (id maps, script queues, a form's controls, the observers' node lists) | generation-checked pointers | R-b. Registries are raw and unregistered at removal or free, or `WeakRef`. WebKit's `MutationObserver::m_registrations` is a `WeakHashSet`. |
| node ↔ node outside the tree (form owner, label, `ElementInternals`, an assigned slot) | raw / generation-checked | R-b, enforced by a lint: no `Ref(Node)` in a node's state except the structural links. |
| element ↔ its [SameObject] sub-objects (classList, dataset, attributes, style) | separate Instances | The element owns their storage. Their wrapper's reference is forwarded to the element (`NamedNodeMap::ref` → `m_element->ref()`), so no count of their own, and no cycle. |
| node → childNodes list → node | `Node.InternalState.child_nodes_list` (Node.zig:107) caches the list | The list holds `Ref(owner)`; the node's cache is raw and cleared when the list is freed. |
| holder platform objects (records, ranges, iterators) ↔ nodes | bare pointers or nodeholds' chain | The holder holds `Ref(Node)`; the node never points back except through raw caches. |
| the other 73 OWNED `engine.Owned` / callback fields in ~40 files (e.g. `IntersectionObserver.callback`, `ShadowRoot.adopted_style_sheets`, `node_filter`, `html/custom_elements/reaction.zig`) | strong roots | Audit them under R-a in §7, step 9: each is either a bounded root, documented as such, or becomes a traced value. |

**Gecko, by contrast**, owns in both directions:
- "mParent is an owning ref most of the time"; `mFirstChild` and `mNextSibling` are `nsCOMPtr`
  (dom/base/nsINode.h).
- Listeners and preserved wrappers are strong.

So every DOM tree is a reference cycle, and the cycle collector exists to find garbage among them
(xpcom/base/nsCycleCollector.cpp, with `FragmentOrElement::CanSkip` / `CanSkipInCC` / `CanSkipThis`
pruning "known-live" trees in dom/base/FragmentOrElement.cpp).

Crane would need one only if R-a or R-b were given up: a strong native root to a JS value that can reach
back to its owner, or a counted back link. The places to watch are the 73 OWNED fields above and any future
`Ref` between nodes. The agent-end leak report (§7, step 2) is the alarm: a cycle shows as nodes still
counted when the agent ends.

---

## 4. Threads

- **Nodes are agent-local.**
  - An agent is used only on the thread that made it (docs/engine-protocol.md §3 "Threads").
  - The DOM lives on the Browser's window agent thread (src/html/parser_holds.zig:46 doc).
  - Workers have no DOM: a worker global has no Document, and DOMParser is not exposed there.
- **Counts are non-atomic, as WebKit's are.** `Node::ref`/`deref`/`setParentNode` assert `isMainThread()`
  (Node.h, NodeInlines.h).
- **Why not atomic.** An atomic read-modify-write costs several times a plain add even uncontended, and the
  counts sit on the parse, insertion and wrap paths. The ordering guarantee would buy nothing, because no
  second thread may touch a node.
- **Debug check.** In Debug every `ref`/`deref` checks the node's agent (`owner_instance.ctx`) against the
  thread's host agent. A mismatch panics with the acquisition site.
- **Finalizers.**
  - V8's second pass runs on the isolate's thread.
  - JSC finalizers may run on any thread, so they only enqueue (§2.5).
- **Cross-thread messages carry no `Ref(Node)`.**
  - Fetch completions, worker messages and network callbacks reach the agent as tasks.
  - The task is built, and its `GCReachableRef` taken, on the agent thread. A network thread's callback
    carries an id the agent resolves.
  - A task dropped by a queue on another thread must drop its node refs on the agent thread. Queues that
    can be destroyed cross-thread move such tasks to the agent first. This is a rule for the event-loop
    lane: lesson "A queue handoff may drop the task before return".
- **The teardown queue is per agent** (defertd: `AgentHost` owns it). Each worker agent drains its own.
- **Phase 2 (Decision D3).** If counts later cover all platform objects:
  - a worker's objects count non-atomically on the worker's thread;
  - objects genuinely shared between agents (an entangled MessagePort's shared state, BroadcastChannel
    delivery, the shared worker manager) use a separate atomic type, WebKit's `ThreadSafeRefCounted`.
- **No new global state.**
  - Counts live in the node.
  - The queue and the Debug ledger live on the agent.
  - The live-node counter is per agent, with diagnostics through `engine.diagnosticCounters`'s host side.
  - lint-global-state is unchanged.

---

## 5. Cost

### 5.1 Size

`NodeBase` is 440 B on main (pinned by tests/dom/shadow_host_flag_test.zig:18) and 448 B on lane/nodeholds
(184e365062: "the padding beside node_type and the bools is 3 bytes"). Computing from the field types
(src/dom/node_base.zig; Zig 0.16 `std.ArrayList` is 24 B):

- 8-byte-aligned fields: 432 B (allocator 16, owner_instance 8, node_name 16, five tree links 40,
  `child_nodes` 88, owner_document 8, `registered_observers` 248, bound_v8_wrapper 8), plus nodeholds'
  `holds` 8.
- Small fields: `node_type` u16 and three bools, 5 B in one 8 B word.

| | 8-aligned | small | total |
|---|---|---|---|
| main | 432 | 5 → 8 | 440 |
| lane/nodeholds (+`holds`) | 440 | 5 → 8 | 448 |
| refcount (−`holds`, +`rc` u32, +`subtree_holds` u32) | 432 | 13 → 16 | **448** |

So the count costs 8 B against main and nothing against nodeholds.
- **Document** gains 8 B in its state (`referencing_nodes`, `foreign_holds`).
- **Instances** are unchanged: `Ref(Node)` carries `*NodeBase`, so the slab slot stays 32 B (D2).
- **A CacheEntry** caches its node's `*NodeBase` (+8 B per wrapped node) so the second pass derefs without
  `instance_bridge.getNodeBase`, which takes a process-wide mutex and a hash lookup
  (src/dom/instance_bridge.zig:179).

For scale (an estimate, not this lane's work): the two inline lists take ~336 B of the 448:
- `registered_observers` holds four inline 48 B records, ~248 B, almost always empty;
- `child_nodes` duplicates the sibling links, 88 B.

A rare-data side structure would save several times what the count costs. Blink's Node has `data_ = NodeRareData::Create()` (node.cc), and WebKit's Node has its own NodeRareData.

### 5.2 Time, per path (estimates; the measurements in 5.3 decide)

| Path | Today (main + nodeholds + defertd) | Refcount |
|---|---|---|
| Insert a subtree | link + child list. The insertion steps walk the subtree whenever any callback is registered, and the adapter registers one (mutation.zig:980, :1147, :1305; wrapper_cache.zig:369). `onNodeInserted` → `syncStrength` does a cache hash lookup per node. `drawTreeEdges` runs for wrapped nodes. | + one OR (the parent bit); + O(depth) adds only if the subtree holds anything (never for parse/innerHTML fragments); edges only for a wrapped subtree root, host-driven; the per-node lookup is gone |
| Remove a subtree | removing steps per node: `syncStrength` lookup, nodeholds' `holds == null` test, pholds' registry check on the root (parser_holds.zig:160). A never-wrapped subtree is retained until realm end. | clear the bit; O(depth) subtracts if S holds; if `S.subtree_holds == 0`, push the root (O(1)), which **frees innerHTML garbage**; the per-node lookups and the registry scan are gone |
| Parse, per node | create; append; per parser move, two `engine.retainValue` (a V8 Global each, and a wrap) plus `SavedNode` generation reads (src/html/parser_dom_mutation.zig:79-82, :110) | the creator's `Ref` is adopted by the stack entry; `subtree_holds` propagates O(depth) on insert and again on pop: ~2 × depth pointer chases per element (~30-60 ns at depth 15, against ~500 ms for ps-parser-page: ~0.1-0.3%); moves are integer `Ref`s, no V8 |
| Wrap | `instance_bridge` lookup (mutex + hash); `drawTreeEdges` wraps unwrapped ancestors | + count 0 → 1: O(depth) adds; edges as today |
| Collection, second pass | `finalizeEntry`: generation/vtable/state compare, cache lookups, a scan of every live cache (`wrappedElsewhere`), `engineOwns` (which includes a Document registry lookup); defertd's `countUpTo` walk | dispose + deref; push the root if the tree became garbage |
| Teardown | defertd slices + `deinitNodeByType`'s guards: `markCleanupStarted`, the generation check, the deferred `releaseStorage` gate (Node.zig:390-410) | defertd slices; each node is freed exactly once, with no guards |

### 5.3 Measurements the migration must hit

The 3% bar is the one the pholds, nodeholds and defertd briefs used: totals within 3% of the base.

1. **Full worklist sweep** at every engine-wide step: summed per-file wall time within 3%; blocking and
   passing unchanged or better; the rate outside encoding/ and the per-file mean reported.
2. **Parse:** ps-parser-page and ps-parser-speed within 3% (pholds M1/M2). Paired, alternating, at least
   7 rounds, medians.
3. **Holders:** ed-qsa-timing (a)/(b) and ed-mo-parse-page (c) within 3% (the edges/nodeholds set).
4. **gc_bench** (tools/gc_bench.zig), 7 interleaved rounds, B/cycle RSS, live instances, global-handle
   bytes, wrapper entries:
   - default `createElement`, appendChild/remove, host-in-dropped-parent, qsa churn, MO take/deliver:
     within 3% or lower;
   - **innerHTML churn must fall** from ~35 KB/cycle (nodeholds handoff) to about zero. This is the
     RETENTION fix, and nodeholds' no-lists control (45,000 instances kept) must keep none.
5. **Pauses:** dt-teardown-pause-sync/-tasks, max pause no worse than defertd's tip.
6. **`@sizeOf(NodeBase)` pinned** at 448 (shadow_host_flag_test.zig's pin moves to a refcount test).
7. **leaks --atExit** on dom/nodes/, html/syntax/, shadow-dom/ and the crane `rc-`/`ed-`/`nh-`/`dt-`
   files: no more than base. **The agent-end live-node count is 0** (a Debug assertion).
8. **Crash protocol (AGENTS.md):** timers x3 and the same-list crash protocol for the engine-wide steps
   (§7).
9. **Heap:** retained heap per file (`CRANE_HEAP_GC=1`) flat or lower.

---

## 6. What it retires, and what stays

### 6.1 Retired

- **Parser holds** (src/html/parser_holds.zig): the `ParserRegistry`, the removal-root scan and `rescue`,
  `DocumentParser.holdsNodeUnder`, `rescue`, and the kept-slot reservation in scripted_parser.zig:283/588/611.
  The parser's structures hold `Ref`s instead. The move holds (`engine.retainValue` ×2,
  parser_dom_mutation.zig:79-82, :110) and the `SavedNode` re-checks (9 uses, all in that file) go too.
  The L1/L2 invariants test becomes a test of the opaque-root rule alone.
- **nodeholds' holds** (lane/nodeholds src/dom/node_holds.zig):
  - `Hold`/`Holder`, `NodeBase.holds` and the removing-steps callback;
  - the generation-read `Hold.get` net and `nodeReleased`.

  MutationRecord and static NodeList hold `Ref`s and draw `keepOpaqueRoot`. Its isKeptRoot/root-memo logic
  moves into that operation's V8 implementation. Its lazy NodeLists and querySelectorAll's
  collect-then-set stay: they are independent of the hold mechanism.
- **edges/lifefix keep-alives:**
  - the QueuedSvgScript Owned root (edges item 5, 5fb1c2dbd8) becomes a `GCReachableRef`;
  - StaticRange's traced containers (ae9eda8bf4) become `Ref`s plus `keepOpaqueRoot`;
  - lifefix2's generation-checked registry, FormData File and [SameObject] readers become `Ref` or
    `WeakRef`.
- **Generation checks as behaviour, for nodes:**
  - the codegen [CEReactions] result check, which returns InvalidStateError when a result was freed
    (src/webidl/codegen/writer.zig:2827-2836, emitted into every interface, e.g. interfaces/Node.zig:451).
    The binding holds a `Ref` on the result across `CEReactions.end`, and the stated deviation goes;
  - `deinitNodeByType`'s dead-generation return;
  - wrapper_cache's `slotReissued` for node entries;
  - the element-task re-checks.

  Of today's 561 `generationOf` calls, the node ones go. Non-node ones stay until phase 2.
- **Storage reclamation's special cases:**
  - `deinitNodeByType`'s deferred `releaseStorage` gate (Node.zig:392-410);
  - `gc.releaseStorage` for nodes (gc_integration.zig:103);
  - for node entries, `finalizeEntry`'s `instance_already_cleaned`, `isCleanupStarted`/`isCleanedUp`,
    `treeOwns`/`templateOwns`/`engineOwns` and `wrappedElsewhere` branches, and `markAsCleanedUp`;
  - for nodes, `instance_lifecycle`'s flags and `cleanup_coordinator`'s `isContextTearingDown` branches;
  - `template_contents.ownedByLiveTemplate` as a lifetime predicate (it becomes a structural link);
  - defertd's `runCollectedNode` re-checks (they become the refcount steps of §1.4).
- **Engine boundary debt:** the adapter's `dom.mutation` hooks (wrapper_cache.zig:365-403) and its reads
  of node and Document internals (`treeOwns`, `engineHoldsWrapper`), which the host now drives (§2.3).

### 6.2 What stays

- The wrapper cache and its identity rules:
  - one wrapper per node (`bound_v8_wrapper`);
  - never replacing a live wrapper (`AlreadyWrapped`);
  - the first/second-pass split.
- Node tracing edges, as V8's realization of the opaque-root rule.
- `traceChild` and `traceValue` for non-node members.
- Pending activity, now counted.
- defertd's queue and slices.
- Realm and agent end ordering.
- Slab generations, as the identity behind `WeakRef` and for non-node objects.
- Every non-node object's lifetime, until phase 2 (D3).

---

## 7. Migration plan

**10 steps.** Step 5 has 9 holder sub-steps and step 9 is ~6 deletion commits. Each leaves main working:
until step 7 the counts run in **shadow mode** (kept and checked, deciding nothing). Steps marked
**ENGINE-WIDE** run the full protocol:

1. a frozen base and tip runner, full worklist sweep of both, newly blocking files re-run 3x;
2. timers x3 (`./zig-out/bin/wpt_runner html/webappapis/timers/ --parallel=3`), counting crashes;
3. for any sweep-only crash, the same-list comparison (base k of N vs tip 0 of N, N ≥ 6);
4. leaks --atExit on the lists in 5.3 item 7;
5. file-isolated tests/dom, tests/html, tests/v8, tests/runtime;
6. gc_bench interleaved;
7. journals in `wpt-results/lanes/refcount-<sha>/`.

Targeted steps run their directories plus the 1-in-4 sample (memory: verification process). Every step:
test first, `zig build test` (the four lints), `zig build wpt-runner`, and a commit.

**Step 1. Baseline and red tests (no behaviour change).**
- Crane tests `rc-*`, red where behaviour must change, green where it must not:
  - innerHTML garbage freed (a live-node count probe through a test hook);
  - a held descendant keeps its ancestors (D1);
  - a self-capturing listener's detached tree collected;
  - an MO callback cycle collected;
  - a cross-realm node survives its frame's realm end;
  - expandos survive while a delivered record holds a node.
- A per-agent live-node counter in diagnostics.
- All of 5.3 measured on base.
- Files: tests/wpt/crane/rc-*.html, tests/html/refcount_*_test.zig.

**Step 2. The type.**
- New `src/dom/refcount.zig` (or `ref.zig`) with:
  - the `NodeBase.rc` word in WebKit's encoding: increment 2, bit 0 = parent, born at one reference;
  - `subtree_holds`;
  - `Ref(T)`, `?Ref(T)`, `GCReachableRef(T)` and `WeakRef(T)`;
  - `Document.referencing_nodes` and `foreign_holds` (the fields only).
- Debug detection:
  - deref at zero panics (WebKit `ASSERT_WITH_SECURITY_IMPLICATION(refCount())`);
  - a ref on a GARBAGE or torn-down node panics (WebKit `applyRefDuringDestructionCheck`);
  - wrong-thread refs panic (§4).
- **Double release.** Zig copies `Ref` values, so a value-side flag cannot catch two releases. Debug
  instead keeps a per-agent ledger: each `Ref` carries a ledger id, and a second release of the same id
  panics.
- **Leaks.** Outstanding ledger entries at agent end are leaks, reported with acquisition stacks under
  `-Drefcount-trace` (WebKit `trackForDebugging` / its node leak counter).
- **Lints** (Zig, in the existing lint tools):
  - no `.parent_node =` outside NodeBase's setter;
  - no `Ref(Node)` field in node state except the allowlisted structural links.
- Pin the size: `@sizeOf(NodeBase)` = 448.
- Tests: std.testing over a tiny tree (testing allocator), the ledger's double-release and leak reports,
  the size pin.
- Targeted (no hot path yet).

**Step 3. Tree links (ENGINE-WIDE: every mutation).**
- Funnel every parent write through `NodeBase.setParent`:
  - mutation.zig:951, 1118, 1264, 1645, 2344, 2357 and 2369;
  - element_with_base.zig:219 and :235;
  - Node.deinit's walk;
  - lane/defertd tree_teardown's `unlinkLastChild`.
- Maintain the parent bit and `subtree_holds` on insert, remove, move and adopt, host-including (shadow
  roots through `dom.shadow_hosts`, template contents through `dom.template_contents`).
- Maintain the Document's two counts.
- Still shadow mode. Run the 5.3 timing set (parse, ed-qsa, gc_bench appendChild/remove).

**Step 4. The wrapper link (ENGINE-WIDE: every wrap and finalize).**
- `VTable.counted`.
- `runtime.lifetime.wrapperAcquired`/`wrapperReleased`, called from `WrapperCache.set` and the second pass,
  with the CacheEntry's cached `*NodeBase`.
- Protocol requests to the integrator, each with its V8 implementation, JSC/QuickJS/test entries
  (`NotSupported` or no-op), a tests/v8 test with values made the way the binding makes them, and its
  docs/engine-protocol.md line:
  - counted `keepPlatformObjectAlive`;
  - `joinOpaqueRoot` / `leaveOpaqueRoot`, with the host calling them from mutation.zig in place of
    `installTreeHooks`;
  - `keepOpaqueRoot`.
- Still shadow mode: frees are still the collector's. Pin the opaque-root behaviour with
  gc-keeps-connected-nodes and r3-detached-tree-child-keeps-root.

**Step 5. Holders, one class per sub-step (targeted).** Each converts bare or generation-checked pointers to
`Ref`/`GCReachableRef`/`WeakRef` and keeps its old net (generation checks) until step 9. Tests are native
with the testing allocator, plus that class's `ed-`/`nh-` Crane tests.

| Sub-step | Holders | Kind | Files |
|---|---|---|---|
| 5a | parser structures, adapter node map, move holds | `Ref` (2026-10-28, lane refcount6, integrator-approved deviation: the adapter's node map stays WEAK - TreeNode.dom_node + dom_generation is WeakRef's shape; only the structures (stack, formatting list, head/form, the script being processed), the move holds, the content-patch nodes and the active call's Document are counted, as WebKit and Blink count only their structures; counting the map would hold every node the parser made until its release. The parser also hands its born references on: a non-element's at its first insertion, an element's adopted by the structure that names it first - decision D-A) | src/html/scripted_parser.zig, parser_script_execution.zig (`DomTreeAdapter`), parser_dom_mutation.zig, tree_builder's stack (granted for this sub-step) |
| 5b | MutationRecord, static NodeList (qSA, labels), getElementsByName's static collection | `Ref` + `keepOpaqueRoot` | lane/nodeholds' MutationRecord.zig, NodeList.zig, ParentNode.zig; Document.zig (getElementsByName) |
| 5c | MutationObserver pending targets, transient registrations; callback traced | `GCReachableRef`; `WeakRef` node list | MutationObserver.zig, src/dom/mutation_observer_algorithms.zig, observer_registrations.zig |
| 5d | element tasks: image/media/script/link/style fetch completions, details toggle, frame load, queued SVG script | `GCReachableRef` | HTMLImageElement.zig, src/html/media/runtime.zig, script_execution.zig, style_sheet_loading.zig, embedded_content.zig, HTMLDetailsElement.zig, SVGScriptElement (QueuedSvgScript) |
| 5e | custom element reaction queues, construction stack, upgrade candidates | `GCReachableRef` | src/dom/custom_elements.zig, src/html/custom_elements/ |
| 5f | Range/StaticRange containers, NodeIterator/TreeWalker, Selection | `Ref` | src/dom/range_boundaries.zig:20-22, impls Range.zig:58-62, NodeIterator.zig:83-86, src/dom/traversal.zig |
| 5g | events: target, relatedTarget, path | `Ref` | impls Event.zig:33/59, FocusEvent.zig:39, src/dom/event_dispatch.zig |
| 5h | live collections, childNodes cache, [SameObject] sub-objects (forwarding) | `Ref(owner)`; raw cache; forwarded count | src/dom/live_collections.zig, node_lists.zig, Node.zig:107 |
| 5i | document registries (scripts, style sheet owners, focus, target, form controls) and Window → Document | raw + unregister, or `WeakRef`; Window `Ref(Document)` + counted keep | src/dom/document_scripts.zig, style_sheet_owners.zig, focused_area.zig, target_element.zig, form_controls.zig; Window.zig |

**Step 6. The zombie audit (measurement, no merge needed).** Build with `CRANE_REFCOUNT_AUDIT=1`: when the
counts say a tree is garbage, mark it ZOMBIE instead of acting (the old model still frees on its own
schedule). Any later access through impls to a zombie node is reported with the stack:
- `instance_bridge.getNodeBase`;
- `Node.getInternalState`;
- NodeBase reads through `node_document`;
- a re-insertion.

Each report is a holder step 5 missed: a bare pointer the counts do not see. This is the audit of element
tasks that defertd's analysis asked for, and fix-list PR-N1's audit, done by the machine. Run it on a full
worklist sweep and the crane tests. **Gate for step 7: zero reports.**

**Step 7. The switch (ENGINE-WIDE, the big one).**
- Counts decide: a garbage tree is pushed on the `DeferredTeardown` (§1.4).
- The collector-driven free path for nodes goes: `finalizeEntry` derefs, and `runCollectedNode` becomes the
  refcount steps.
- Realm end hands surviving node wrappers to the agent (§2.1) instead of severing them, and drops the
  realm's `Ref`s (Window → Document, parsers, realm-owned holders). What only the realm held then goes
  through the queue (`drainOwner`).
- Agent end asserts zero live nodes in Debug and reports leaks.
- Expected: RETENTION fixed (innerHTML churn ~0 B/cycle), and the `rc-*` tests green apart from the
  step-8 ones.
- Run the full protocol and the same-list crash protocol for every sweep-only crash. The old nets (the
  generation checks) are still in place, so a missed holder shows as a stale read, not a use-after-free.
- Inline relief inside script (`relieve` past `high_water`) must not run while a DOM algorithm is on the
  stack. Add a per-agent "DOM algorithm active" depth and defer relief to its exit (§9, risk 4).
- Prerequisites (a)-(e) from lane refcount7's handoff (tmp/plans/lane-refcount7-handoff.md "Step-7 items"),
  done by lane refcount8: (a) converted/scratch fragments end their born reference; (b)/(b2) the removal hold
  (refcount.unlinkChildHeld, ended by linkChild or endRemovalHold) and finishDispatch's order; (c) documents born
  offering, each holder taking it over; (e) no root walk on a no-hold link, and the audit behind -Drefcount-audit.
  (d) superseded by (e): same walk count, refcount8 2026-10-29.

**Step 8. Cycle breakers (ENGINE-WIDE: listener storage is on every event).**
- Event listeners and on* handler values are traced from the target's wrapper (`traceValue` into one fixed
  slot).
- MutationObserver and IntersectionObserver callbacks are traced from the observer's wrapper.
- The MutationObserver's pending-activity root goes (5c's edge from observed nodes replaces it).
- Classify the remaining OWNED fields (§3, 73 fields in ~40 files): bounded root, documented, or traced.
- Expected: the listener and observer cycle `rc-*` tests green. Lesson: "An event the engine fires and
  nobody hears must still be freed" (run one page under `CRANE_LEAK_TRACES=1`).
- **Status 2026-11-19 (lane rc8, in progress; tmp/plans/lane-rc8-handoff.md):** new protocol ops `traceValues`
  (an owner's wrapper keeps a SET of values in one slot, replaced whole) and `holdWeakly` (the holder's handle
  becomes a phantom weak Global). EventTarget's listener and handler values, the MutationObserver,
  IntersectionObserver, ReportingObserver and PerformanceObserver callbacks are weak holds with edges from their
  owner's wrapper; an observed node keeps its observers from its wrapper ("observers"), and the MO's registration
  keep became a bounded keep while records are pending (Blink HasPendingActivity). Found on the way: a dispatch
  in flight must keep its path's WRAPPERS, not only count its nodes - `runtime.gc.StackRoot` on the agent's queue,
  walked in the keep walk (lesson architecture-a-value-traced-from-its-owner-needs-every-frame-...). The OWNED
  classification is in the handoff: 16 + 10 trace candidates (event init members, NodeFilter, scoped CE
  definitions, XSLT parameters) are a follow-up.

**Step 9. Deletions (each its own commit, ENGINE-WIDE for those touching wrapper_cache.zig or Node.zig).**
- (a) pholds: parser_holds.zig and the DocumentParser rescue.
- (b) nodeholds' chain and rescue (keep the chain only if D4's gap test needs it).
  **Delete `NodeBase.holds` here and pin `@sizeOf(NodeBase)` back to 448** (decided 2026-10-09: until then rc + subtree_holds and `holds` coexist, so NodeBase is 456 B; the pin in the refcount size test says so). Follow-up, separate: drop infra.List's `?ArrayList` tag (-8 B per List, two per node).
- (c) the parser move holds and `SavedNode`.
- (d) storage reclamation and `instance_lifecycle` for nodes; wrapper_cache's node predicates.
- (e) generation checks on strong holds, which become Debug assertions inside `Ref`; the codegen
  [CEReactions] result check, by `zig build codegen` and codegen-check (never a hand edit).
- (f) `cleanup_coordinator`'s node phase.

Each deletion lowers a baseline where it can (lint-impls, lint-engine, lint-global-state:
`live_caches` and `active_coordinator` are threadlocals), recorded with `--update` (never by hand). Each
also updates docs (engine-protocol.md 4.12 and the Instance row, the lessons whose advice this supersedes
with a dated **Status** line) and adds a lesson: "the tree is the unit of a reference-counted DOM".

**Step 10. Phase 2 (Decision D3): count all platform objects.**
- The count moves into the slab slot (D2): a 40 B slot keeping the u64 generation, or a 32 B slot with a
  u32 generation.
- Records, lists, ranges and events count. `wrappedElsewhere` and realm-end freeing go.
- Feature-queue "cross-realm Instance lifetime" closes generally.

---

## 8. Decisions for the user

| # | Decision | Recommendation |
|---|---|---|
| D1 | A held node keeps its whole tree (Chrome, Firefox) rather than WebKit's "an unreferenced ancestor dies and the held child becomes a root" | **Keep the tree** (golden rule 2, majority; also today's behaviour). Confirm Safari's reading with an `rc-` test in the three browsers first. Cost: `subtree_holds`, O(depth) per hold transition. |
| D2 | Where the count lives: `NodeBase` (nodes only, fits beside `node_type`: 448 B, no slab change) or the slab slot (every platform object; slot 32 → 40 B, or a u32 generation) | **NodeBase now**; the slot in phase 2. `Ref(Node)` carries `*NodeBase` and never pays `instance_bridge`'s mutex. |
| D3 | Scope: nodes only, or all platform objects | **Nodes first** (steps 1-9). Non-node holders keep their wrapper-driven lifetime and hold `Ref(Node)`. Schedule phase 2 after step 9 is green. |
| D4 | Wrapper liveness on V8: keep node tracing (wrap ancestors, O(1) edges per move); a per-tree root token (no ancestor wrapping, O(wrapped in S) per move); or cppgc for wrappers only | **Keep node tracing**, driven by the host through `joinOpaqueRoot`/`leaveOpaqueRoot`. Accept `keepOpaqueRoot`'s stated gap unless a test shows it matters. Not cppgc: the user declined Oilpan. |
| D5 | JSC edges: a per-realm WeakMap (ephemeron, invisible), symbol-keyed properties (visible to `Reflect.ownKeys`), or the Objective-C managed-reference API | **WeakMap**, plus a feedback request for a C-API visit hook (ask before filing, per memory). |
| D6 | A document whose only remaining holds are detached nodes of it: keep its tree (Blink) or tear it to a husk (WebKit's `removedLastRef`) | **Keep its tree** (`foreign_holds`), plus WebKit's `referencing_nodes` for the storage. |
| D7 | Listeners and observer callbacks traced from their target's or observer's wrapper (a listener can no longer keep its own detached target alive) | **Yes** (WebKit `JSEventListener`, Blink tracing). It ends the "listener closure pins its tree" leak. |
| D8 | Free garbage trees always through the deferred queue, or inline for small trees (WebKit deletes inline; its async queue covers only `removeAllChildren` batches) | **Always deferred.** No frees inside DOM algorithms means far fewer `protectedThis` Refs on the stack. Measure memory high-water in step 7. |
| D9 | Debug tooling: the ledger with acquisition stacks (`-Drefcount-trace`), fatal or logged | **Fatal in `zig build test`; logged in sweeps**; stacks only under the flag. |
| D10 | Run the zombie audit (step 6) as a full sweep before the switch | **Yes.** It is the gate for step 7. |
| D11 | Who does steps 3, 4 and 7 | **Claude lanes, one at a time, high effort** (lifetime, engine and hot-path work; memory: Codex role narrowed). Step 5's sub-steps can run 2-3 in parallel: disjoint files. |

---

## 9. Top risks

1. **A holder missed before the switch.** A bare pointer becomes a use-after-free once never-wrapped trees
   are freed (defertd's analysis). Mitigations: step 6's zombie audit (zero reports is the gate), the
   generation nets kept through step 8, the same-list crash protocol.
2. **Count bugs in a language without destructors.** A double release or a missed release. Mitigations: the
   Debug ledger and underflow panics (step 2), `defer`/`errdefer` at every acquisition, testing-allocator
   unit tests, and the agent-end live-node assertion.
3. **Native cycles reintroduced:** a `Ref` between nodes, or a strong root to a closure. Mitigations: the
   lint (no `Ref(Node)` in node state), the OWNED-field audit (step 8), leak reports at agent end.
4. **Frees landing inside DOM algorithms.** Today `relieve` frees inline from a second pass, which can run
   from a GC prologue in the middle of an algorithm (lane/defertd wrapper_cache.zig `finalizeEntry` →
   `relieve`). Mitigation: a "DOM algorithm active" depth, with relief deferred to its exit (step 7).
5. **Wrapper identity semantics.** A natively held, wrapper-unreachable tree loses its expandos (WebKit
   does the same). Mitigation: `GCReachableRef` where WebKit uses it, `keepOpaqueRoot` for holders with
   wrappers, and the `rc-`/`ed-`/`nh-` identity tests.
6. **Cost on deep trees.** `subtree_holds` is O(depth) per hold transition. Mitigation: gc_bench deep-tree
   bodies, ps-parser-page within 3%. A cached shadow-including root (WebKit's `m_shadowIncludingRoot`, +8 B)
   is the fallback if needed.
