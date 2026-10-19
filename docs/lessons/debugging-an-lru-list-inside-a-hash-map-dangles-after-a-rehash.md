# Debugging: An LRU list inside a hash map dangles after a rehash

**Date**: 2026-10-19
**Lesson**: Linking a hash map's values to each other through pointers (an intrusive LRU list) leaves every link dangling the first time the map grows: a rehash moves the values, not the pointers that point at them.

**Why**: `std.HashMap` (and `StringHashMap`, `AutoHashMap`) stores its values inline in one array. `put` can grow and rehash that array, so every `*Value` taken before it - `getPtr`, `value_ptr` - points into freed memory afterwards. A doubly linked list threaded through those values keeps such pointers for the whole life of the cache.

**What Happened**: The RFC 7234-era HTTP cache library in src/fetch/cache/memory_backend.zig kept its LRU nodes inside its `StringHashMapUnmanaged(EntryNode)` and linked them with `prev`/`next`. Nothing called it, so nothing crashed; lane httpcache1 found it reading the library before wiring a cache into Fetch, and deleted it. src/selector/cache.zig's `SelectorQueryCache` (unused too, 2026-10-19) has the same shape: `std.StringHashMap(CacheEntry)` with `lru_head`/`lru_tail`/`prev`/`next` pointing into the map. The first `put` that grows the map would leave the list pointing at the old array.

**Fix**: Give each node its own allocation and keep pointers to it in the map (`HashMapUnmanaged(Key, *Node, ...)`), as src/fetch/cache/http_cache.zig does; the map may move its `*Node` slots freely. Or index the list by key and look nodes up again. Free nodes after unlinking, never while the map still holds them.

**Takeaway**: **Never keep a pointer to a hash map's value across a `put`: a list threaded through the values dangles at the first rehash. Heap-allocate the nodes and store pointers in the map.**
