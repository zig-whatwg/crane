# Refcount design: the user's decisions (2026-10-09), one by one

Provenance: moved word for word from tmp/plans/refcount-decisions.md (untracked) on 2026-11-23 by lane flk4, at the integrator's request, so tracked code points at a tracked file. The design these decide is docs/refcount-design.md.

Status (2026-11-23): the D2 note's sizes are history - NodeBase is 88 B since the node memory redesign (cefe4044a, 2026-11-13; src/dom/node_base.zig), not 448 or 456 B. The decisions themselves stand as the user made them.

Source: tmp/plans/refcount-design.md section 8.
D1. A held node keeps its whole tree, ancestors included (Chrome/Firefox); check Safari's behaviour with a test first.
D2. The reference count lives in NodeBase (spare space; no size growth); moves to the slab slot only if every platform object is counted later.
D3. Scope: nodes first; other platform objects in a later phase 2.
D4. V8 wrapper liveness: keep today's node-tracing edges, driven by the host through new protocol operations (joinOpaqueRoot/leaveOpaqueRoot/keepOpaqueRoot); no cppgc.
D5. JSC: per-realm WeakMap tree edges + ES WeakRef identity; ALSO draft an Apple feedback request for a C-API visit hook (show the user before filing).
D6. A document held only through detached nodes keeps its tree; its storage uses WebKit's referencing-node count.
D7. Event listeners and observer callbacks become values traced from their target's wrapper (WebKit JSEventListener), ending the listener cycle.
D8. A tree whose count reaches zero is always freed through defertd's queue in slices, never inline mid-algorithm.
D9. Debug ledger: fatal in unit tests, logged (and counted like crashes) in WPT sweeps.
D10. A zombie-audit full sweep reporting ZERO accesses to dead-by-count nodes is required before the switch (step 7).
D11. Steps 3 (tree links), 4 (wrapper link) and 7 (switch) are Claude lanes at high effort, one at a time, each with a full sweep and the crash protocol; Codex takes no part of the migration.
D2 note (integrator, 2026-10-09): NodeBase grows 448 -> 456 B temporarily while nodeholds' holds pointer and the counts coexist; back to 448 when step 9b deletes holds (user's D2 intent: no growth in the end state).
