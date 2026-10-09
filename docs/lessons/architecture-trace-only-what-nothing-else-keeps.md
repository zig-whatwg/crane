# Architecture: Trace only what nothing else keeps - an edge per object to its owner's own value is a Global per unwrapped object

**Date**: 2026-10-08
**Lesson**: Every element drew a traced edge to its document's global custom element registry, which the document already kept; for an element script had not wrapped, `engine.traceChild` parks that edge as a Global in the realm's wrapper cache until a wrapper is made - one handle per created element, never released for elements discarded unwrapped.

**Why**: `traceChild(owner, child)` on an owner with no wrapper cannot set a private property, so the adapter keeps the child strongly in `edges_before_wrap` (a Global) until the owner is wrapped. innerHTML, DOMParser and the live parser create most elements unwrapped. An edge that is redundant on paper (the document keeps the registry anyway) is therefore not free: it is a handle, a hash entry and a wrapper-cache allocation per object, on the hottest creation path.

**What Happened**: CE2-S2 (tmp/analysis/fix-list.md). A unit test parsing 2,000 elements through innerHTML grew V8's own `global_handle_bytes` by exactly 64,000 bytes (one 32-byte node per element). gc_bench with `innerHTML` replacing five `<p>` per cycle grew global handle bytes by 160 B/cycle for 20,000 cycles - 100,000 Globals held until the realm ended, because the discarded elements' waiting edges were never released - and RSS was 43,240 B/cycle. With the edge drawn only for registries the document does not keep (scoped ones): 0 B/cycle of handles, 35,990 B/cycle RSS; createElement 6,750 -> 5,430 B/element; the 2,500-section live parse 1,055-1,115 -> 895-926 ms.

**Fix**: `RegistryAssociation.setForNode` keeps a registry equal to the node document's global one as `document_global`: its pointer with generation and realm (`KeptInstance`, read through `get()`), and no edge. DOM guarantees the global case equals the node document's registry (flatten 3.2.3, importNode 3, clone 2.3, adopt 3.3.2.4). Only a registry nothing else keeps is traced from the node.

**Takeaway**: **Before drawing an edge per object, ask what already keeps the child: an edge to a value the owner's owner keeps costs a Global per unwrapped object and can leak with every discarded one - measure `global_handle_bytes` per created object, not just the wrapper count.**
