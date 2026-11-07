# Debugging: A field count taken at teardown misses what a finalizer clears first

**Date**: 2026-11-07
**Lesson**: Counting how many objects ever use a field by reading it when they are torn down undercounts every field that something else clears before the teardown - a wrapper's finalizer, a holder's release - and can call a field on every node "never set".

**Why**: "Set at teardown" stands in for "ever set" only for fields nothing resets on the way out. A field that names a live peer (a wrapper, a hold, a registration) is cleared by that peer's own end, and in a collected tree the wrappers die first: the collector finalizes them, and the teardown of the native nodes runs later, from the event loop.

**What Happened**: Lane perf2 batch 4 counted NodeBase fields over all 17 perf pages with a per-node check at teardown (6.07 M nodes) and reported `bound_v8_wrapper` set on 0 of them - "a measured candidate for rare data". Batch 5's brief planned to move it there. Reading the writers before designing showed `wrapper_cache.zig` sets it for every wrapper the cache takes (`if (node.bound_v8_wrapper == null) node.bound_v8_wrapper = wrapper`, "Set here, for every wrapper the cache takes") and `unbindNode` clears it when that wrapper is finalized. Every node script ever touched had it set; every one of them had it cleared by the time the count ran. In rare data it would have cost a 40-byte allocation per wrapped node - every `createElement` - instead of saving 8 bytes.

**Fix**: Before acting on a "0% used" field, read its writers and its clearers. Count where the field is SET (an "ever" bit written beside the store), or at teardown only for fields nothing else resets. The field stayed inline, as Blink keeps the main world's wrapper on the object (ScriptWrappable::wrapper_); the design note says why.

**Takeaway**: **A field that names a peer is cleared by the peer's end: count it where it is set, never where its owner dies.**
