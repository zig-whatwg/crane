# Lane refcount9: step 7 design delta (counts decide)

Provenance: moved word for word from tmp/plans/refcount9-design.md (untracked) on 2026-11-23 by lane flk4, at the integrator's request, so tracked code points at a tracked file. It is a delta on docs/refcount-design.md (decisions: docs/refcount-decisions.md). Paths in it that start with tmp/ are untracked lane notes.

Status (2026-11-23): step 7a merged with lane refcount9 (4426c3c1b9d) and step 7b with lane rc7b (docs/roadmap.toml, the `lifetime` progress lines). The text below is kept as written; these sections no longer match the merged code: B4 (7a's coordinated teardown as the net at a realm's end - since 7b a realm's end frees no node whatever its counts, the realm dropping its own references first); B5 (the merged code took the alternative this section set aside: a per-agent DOM-algorithm depth, entered at binding entry and callback invocation, gates relief to the outermost exit, engine.deferredTeardownOf). B1-B3 and B6 match it (refcount_teardown.settle and runGarbageTree, runCollectedNode gone, weak_refs_see_garbage true).

Brief: tmp/orchestration/briefs/refcount9-final.md. Design: tmp/plans/refcount-design.md 1.4, 2.1, 7 (step 7), 9 risk 4.
Base main 247f61fdd26. Part A numbers: see "Part A" at the end (filled before this goes to the integrator).

## Precedent read (2026-10-29)

- WebKit `Node::~Node` (Source/WebCore/dom/Node.cpp): asserts `!parentNode()`, no siblings, then decrements the
  document's referencing node count ("This may destroy the document") and RELEASE_ASSERTs the count word is one
  increment. `Document::decrementReferencingNodeCount` (Document.h) deletes the document when
  `!m_referencingNodeCount && !refCount()`.
- WebKit `Document::removedLastRef` (Document.cpp): nulls its element pointers "or we will create a reference cycle",
  `destroyTreeScopeData`, `removeDetachedChildren`, `commonTeardown`; it is "resurrected" (no delete) while
  referencing nodes remain.
- WebKit `removeDetachedChildrenInContainer` (ContainerNodeAlgorithms.cpp): unlinks every child (sibling and parent
  pointers cleared, the shadow-including root reset); a child with `refCount() > 1` survives as a new root
  (`updateShadowIncludingRootForSubtree`), the rest die with the loop's RefPtr. Crane's D1 keeps the whole tree
  instead (design 1.4); the unlink-before-deref ORDER is what tree_teardown.freeDescendants already keeps.
- Blink `LocalWindowProxy::DisposeContext` (bindings/core/v8/local_window_proxy.cc): clears the native info of the
  global object only (`V8DOMWrapper::ClearNativeInfo(..., V8Window::GetWrapperTypeInfo())`,
  `DomDataStore().ClearIfEqualTo(window, global)`), detaches the global and disposes the per-context data. Node
  wrappers are left alone: a node and its wrapper outlive the context while traced (Oilpan). That is design 2.1's
  "hand surviving wrappers to the agent instead of severing them".

## B1. How counts decide

A tree's root whose total reaches zero (parentless, unhosted, `subtree_holds == 0`; a Document also
`foreign_holds == 0`) is GARBAGE. Today the audit finds exactly these moments (`auditLowered`: the unledgered deref
of a wrapper, holder, creator or remover; a removal's two roots; `hostGone`; a document's foreign holds falling).
Step 7 gives them one sink, `refcount_teardown.settle(root)` (new src/dom/refcount_teardown.zig, mine):

1. Re-test garbage; skip a root whose teardown began (`destroying`, cleanup started) or with no agent.
2. Flag `rc_flags.garbage` and push ONE item on the node's agent's DeferredTeardown (AgentHost, found as the
   audit finds it), owner = the node's realm (`*ContextData`), weight 0 (estimated in its first slice, design 1.4
   item 6: no O(subtree) walk at push). Never frees, never runs script, never relieves (D8).
3. The refcount steps (`runGarbageTree`, replacing runCollectedNode for nodes) at slice time: same instance
   (generation), no teardown begun, `garbage` still set, and the re-check (design 1.4 step 2): parentless,
   unhosted, total zero, Document foreign holds zero. A failed re-check is a RESURRECTION: flag cleared, item
   dropped, counted (`Ledger`-less: a counter plus a warning under CRANE_REFCOUNT_CHECK; Debug-fatal in unit tests
   unless the test names it). Then `tree_teardown.freeDescendants` a budget at a time, leaves first, and the root
   last through `node_creation.destroyRoot` (Node's teardown, storage by the existing rule: no wrapper reaches a
   garbage tree, so storage returns at once). A Document goes in one go (its own teardown frees its tree), as
   runCollectedNode does today.

Weak references see garbage: `weak_refs_see_garbage = true` (refcount8's queued item). Cost cut: a connected
node's root is its node document, so `weakLinkLive` reads `owner_document`'s flag in O(1) and walks only for a
detached node.

The audit (step 6) stays compiled under -Drefcount-audit but its `noteLowered` is no longer called: counts free
for real, and a read of a freed node is now the generation nets' (a stale read), as the brief requires.

## B2. finalizeEntry -> deref

For a COUNTED instance (a node: `entry.counted != null` when made), the second pass becomes: `releaseCounted`
(the deref - whose garbage moment pushes the tree), then only the storage branches that are not lifetime
decisions: stale / slot reissued / wrapped again -> dispose; a teardown already begun -> release the storage a
completed one left (unchanged); inside a coordinated realm teardown -> unchanged (the old net, see B4); else
`markWrapperGone` when no other realm wraps it, dispose. Gone for nodes: `treeOwns`, `templateOwns`, `engineOwns`
and `queueCollectedNode`'s weight walk. Non-node types keep today's path untouched. `relieve` moves to B5's safe
points.

## B3. runCollectedNode as the refcount steps

`queueCollectedNode`/`runCollectedNode` stop being used for nodes (B1's steps replace them). They stay for
nothing else (only nodes were queued), so both are deleted with their test hooks once B1's tests cover the queue;
`wrappedAgain` and `countUpTo` go with them. `drainDeferred` (a realm's end) also drains the items owned by its
`ContextData` (B1 item 2).

## B4. Realm end (proposal: split; 7a in this batch)

What ends a Window realm today: a navigated-away frame's realm ends when the collector takes it (`global_detached`:
"lives on for as long as script reaches anything of the realm") - and a reachable wrapper reaches its realm
(prototype chain -> native context -> global), so no wrapper of it is reachable then; forced ends are the page's
end, a removed iframe (`navigable_destroyed`), a bfcache eviction and the Browser's end. Only a forced end can
leave a node wrapper of the ending realm reachable from another realm (rc-cross-realm-node-survives-realm-end is
GREEN today because its realm is NOT forced).

- **7a (this batch):** the realm's end keeps its coordinated teardown as the NET (it still frees the realm's
  document tree whatever the counts say, as today), preceded by `drainOwner` of the realm's garbage items while
  everything of the realm lives. Counts decide every free during the realm's life. A holder of a node the forced
  end frees keeps reading it through the generation nets (unchanged from today).
- **7b (next batch, proposed):** the realm's end drops the realm's Refs first - its queued tasks (refcount8's
  +18.6k task/slot holds: dropped through the event loop's `drop`, releasing their holds, before the dom_tree
  phase), the Window's Ref(Document), its parsers' structures, its holders' Refs (released by their own teardown,
  which today runs AFTER the tree phase: the order has to invert) - and lets counts decide what goes, with node
  wrappers of other realms handed to an agent-level list whose finalizer still derefs (Blink's DisposeContext).
  That reorders cleanup_coordinator's phases and Window.deinit, both shared with nav2 and the coordinator's other
  users; it is the riskiest change of the migration and gets its own full protocol run.
  Why split: 7a alone delivers the RETENTION fix (innerHTML churn), the switch for every in-realm free and the
  agent-end assertion; 7b changes only forced realm ends, whose behaviour today (sever + TypeError) is
  feature-queue "cross-realm Instance lifetime".

## B5. The "DOM algorithm active" depth (design 9, risk 4)

Where a free can land inside script today: (1) `relieve` in finalizeEntry, past `high_water`, from a second pass
that a forced collection (LowMemoryNotification) runs synchronously wherever it was asked; (2)
`requestGarbageCollection`'s drainAll, which TestUtils.gc() runs from inside script - a listener's call runs it
under the native dispatch that called the listener. Ordinary collections post their second pass as a platform
task, run between tasks.

Proposal - no free while script (and so any DOM algorithm under it) is on the stack, with no per-call counter:
- (1) goes: `relieve` was reached only through `queueCollectedNode`, which B2/B3 retire for nodes (the only type
  queued). Count-driven pushes never relieve.
- (2) a collection requested with a realm current (`engine.currentRealm() != null`: TestUtils.gc from script)
  leaves its drain to the next turn's slices; a host-requested one (gc_bench, the runner's CRANE_HEAP_GC, memory
  pressure from the host) drains at once, as the contract says. One test in the adapter's
  `requestGarbageCollection` (H-RC9-GC-IN-SCRIPT, src/runtime/engines/v8/protocol.zig, and its contract line in
  engine_protocol.zig/docs: "asked from script, the teardown waits for the next turn").
- The "DOM algorithm active" depth is then "a realm is current", which the engine already tracks - no hot-path
  cost. The alternative, a per-agent depth entered by every platform-object callback (interface.zig's
  trampolines) with relief at its outermost exit, bounds the queue inside one long task (a 1M-iteration
  innerHTML loop); it costs two writes per binding call. Today that churn is not bounded either (never-wrapped
  trees are orphans until realm end), so I propose the cheap form now and the counter only if the memory
  high-water rows (D8) show a need.
- Memory high-water: the gc_bench rows' peak RSS (createElement, appendChild-remove, innerHTML churn, cloneNode,
  parser-write) before/after, and the sweep's peak per shard.

## B6. The two refcount8 items and the created-child audit

- Drop a realm's queued tasks before its documents are torn down: needed by 7b (counts deciding at realm end), not
  by 7a, where the forced teardown frees the document and the task's later release is the CountedRef no-op it is
  today. Proposed for 7b.
- `weak_refs_see_garbage`: flipped in 7a (B1).
- Created-child audit LATENT (DOMRectList rects, IntersectionObserver root, fullscreen/pointerLock/PiP elements):
  no producer exists, so nothing reads them; unchanged (the feature-queue rule stands: the producer's change gives
  them a hold). NET-ONLY (IntersectionObserver Observation.target, form PastEntry, ElementInternals form_owner,
  Element refs.single, button command_target, AbortSignal SignalRefs, NavigationHistoryEntry window,
  HTMLMediaElement Links): weak links by design; with counts deciding, a node freed under one reads null through
  its generation check, which is the weak reference's contract. Converting the node ones to `refcount.WeakRef`
  (garbage reads as gone) is a step-9 tidy-up, not a safety need; the audit (part A) reports any read of one.

## C. Tests (RED first)

- tests/html/refcount_retention_test.zig: flip `migrated.switch_step7` (the innerHTML never-wrapped case).
- New tests/html/rc9_switch_test.zig: a garbage tree is queued, not freed inline, and freed by the next slice; a
  resurrected root is dropped by the re-check; a removed held node keeps its tree and the tree goes at the hold's
  end; a weak link reads a garbage tree's node as gone; finalizeEntry's deref frees a wrapped detached tree with no
  other holder; relief waits for depth 0.
- Agent end: every node freed (the Browser's bridge map empty after its agent's end) - a Debug assertion, and a
  logged error (counted like a crash) in sweeps.
- gc_bench innerHTML churn (`(h ??= div).innerHTML = '<p><b>x</b><i>y</i></p>'`, 100,000 cycles, --gc): main
  retains every removed tree (orphans until realm end); target ~0 B/cycle. Plus the refcount8 rows
  (createElement, appendChild-remove, cloneNode, parser-write) for cost and memory high-water (D8).
- Full protocol: FULL A/B, timers x3, leaks --atExit in-process, same-list crash protocol for any sweep-only crash.

## Hunks to request (not my files)

- H-RC9-REALM-DRAIN: src/runtime/engines/v8/context_manager.zig removeContextByKey, one call beside
  `cache.drainDeferred()`: `cache.drainRealmGarbage(&entry.runtime_ctx)` (the drain itself is wrapper_cache's).
- H-RC9-AGENT-END: src/browser/Browser.zig deinit, where it asserts the queue empty: `drainAll()` first (items the
  counts queued during a realm's coordinated teardown, owner = the ended realm; a retired realm's tree is left to
  the final sweep as today), then `dom.refcount_teardown.agentEnded(scope)` - nodes still alive (the Browser's
  bridge map) before dom.teardown_sweeps: an error log in unit tests (D9 fatal), a warning under
  CRANE_REFCOUNT_CHECK.
- H-RC9-BOOKS: src/html/agent_host.zig, one field (`refcount_books: dom.refcount_teardown.Books`), beside the
  audit's; src/dom/root.zig one export line.
- H-RC9-GC-IN-SCRIPT (B5): src/runtime/engines/v8/protocol.zig requestGarbageCollection, + the contract line.
- Tests I change: tests/html/refcount_probe.zig (flag flip), tests/html/rc8_xml_move_hold_test.zig (reads the
  switch's resurrections instead of the audit's), tests/html/refcount_audit_test.zig deleted (its four cases are
  rc9_switch_test.zig's, with real frees), and whatever tests/v8 deferred-teardown test reads a collected node's
  item on the cache (`deferredCount`), which moves to the realm's owner.

## Part A (measured 2026-10-30 00:18-01:38 UTC, chat.local, pair rc9-audit)

Audit runner (main 247f61fdd26 built with -Drefcount-audit=true, wpt_runner fc3536b2, snapshot 11c614b1) with
CRANE_REFCOUNT_AUDIT=1 over the 2,311 Crane tests (tests/wpt/crane/) + the full 13,077-file worklist = 15,388
files, 4 runners asked (3-4 held), manifest c1843a3eb5f9acc4 / 165,473 before and after:
- 15,388 records: OK 15,214, TIMEOUT 120, ERROR 54, CRASH 0; no panic, SIGSEGV, SIGBUS or double-free line.
- 930 agent ends: 1,632,118 zombie trees (4,267,692 nodes) - every tree step 7 would have freed early.
- ZOMBIE READS: 0 (0 ZOMBIE lines in the whole stderr). RESURRECTIONS: 1, one site:
  crane/rc5-scoped-define-collected-document.html, `refcount.holderRef` from `upgrade.enqueueCandidates`
  (define() steps 17-18 walking a scoped registry's weak document set; symbolized with atos). It is the known
  pair refcount8 left: its fix (3e3ff07eda5, H-RC8-CER-WEAK) makes the weak set read a GARBAGE document as gone,
  which production builds skip until `weak_refs_see_garbage` flips (step 7, B1); the audit flags
  `audit_pending`, not `garbage`, so it still shows here. No product change in part A; part C re-runs that file
  with the step-7 runner and must show 0 resurrections (the switch's books, logged under CRANE_REFCOUNT_CHECK).
- Gate (D10, zero reports): met for reads; the one resurrection is closed by step 7's own flip.
- Journal and report lines: wpt-results/lanes/refcount9/audit-full/.
