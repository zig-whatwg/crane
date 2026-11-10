# Architecture: A compressed link pays its decode on every hop of a dependent chain - keep the parent full width

**Date**: 2026-11-10
**Lesson**: Compressing a node's links to 32 bits makes sibling walks over a page-sized tree faster (smaller nodes), but a walk that follows ONE link kind hop after hop - the parent chain - pays the decode's extra instructions on its critical path every hop: keep `parent` 8 bytes, as Blink does, and compress the rest.

**Why**: A pointer chase is load -> load. A compressed chase is load -> zero-extend -> AND (the holder's region base) -> OR -> load: two or three more cycles on a chain whose hops are otherwise one cache hit each. Sibling walks hide the decode behind the cache misses that smaller nodes avoid; ancestor walks (`contains`, `closest`, connectedness, refcount's `subtree_holds` walk) do not.

**What Happened**: Lane ndalloc b1 measured a DOM-shaped tree (tmp/plans/ndalloc-bench/bench.zig, ReleaseSafe, chat.local M4 Pro and server1 Ryzen AI MAX+ 395). Full 8-byte links in a 112-B node against 32-bit links in an 80-B node: sibling walks of a 200,000-node churned tree ran at 0.33-0.65x, but the parent chain ran at 1.87-1.88x on x86-64, with or without a global base. The Blink split (parent 8 B, the other links 32-bit, the same 80 B) walked at 0.33-0.65x AND chased parents at 0.45-1.01x. Blink's node.h says the same: "Both tree_scope and parent are hot accessed members. Keep them uncompressed for performance reasons." Two more findings: in ReleaseSafe a global base was no faster than decoding from the holder's own address and 1.07-2.00x slower on writes (Zig reloads the global after every store it cannot prove does not alias it); and with 2,000,000 randomly placed nodes every compressed shape walked 1.2x slower on Apple silicon only (cause not confirmed).

**Fix**: tmp/redesign/node-memory-architecture.md 3.3 and 4.2: `Link(T) = enum(u32)` decoded from the holder's address for first/previous-or-last/next and the satellite links; `parent` stays a full pointer; a hot loop may hoist the region base once (`Cage.of(node)`).

**Takeaway**: **Measure a compressed link on the walk that chains it, not only on the walk that reads it once per node: a dependent chain pays the decode every hop, so keep the hot chain's link (the parent) full width and compress the rest.**
