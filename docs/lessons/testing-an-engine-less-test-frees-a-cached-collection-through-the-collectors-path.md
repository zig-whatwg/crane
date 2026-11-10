# Testing: An engine-less test frees a cached collection through the collector's path

**Date**: 2026-11-10
**Lesson**: A live collection the document caches (getElementsByClassName, getElementsByTagName) must be freed in an engine-less test with `runtime.gc.onObjectFreed`, the path a collected wrapper takes - never with the interface's `deinit`, which empties the object but leaves it in the cache.

**Why**: The document hands out ONE collection per (root, kind, names) from its query caches (`dom.live_collections.collectionFor`), found again by its slab slot. `interfaces.HTMLCollection.deinit` runs the destructor but leaves the slot - and its generation - where they were, so the cache still finds it and hands back an object whose filter is gone. Freeing it as the collector does (`runtime.gc.onObjectFreed`) returns the slot, its generation moves, and the next call makes a new collection.

**What Happened**: Lane nd2 b1's N3 test (tests/dom/nd2_id_class_index_test.zig) checked each element's classes with getElementsByClassName twice in a row (before and after changing its id). The first version leaked the collection (std.testing.allocator: the filter string from HTMLCollection.makeClassNames); freeing it with `HTMLCollection.deinit` made the SECOND call return length 0 - five of seven boundary tests failed with "expected 1, found 0", which looked like an N3 bug in the class index. The tests that called the helper once passed, which pointed at the cache, not the index. tests/dom/perf2_query_fast_paths_test.zig already frees its NodeLists with `defer runtime.gc.onObjectFreed(list)`.

**Fix**: `const list = try interfaces.Document.call_getElementsByClassName(doc, names); defer runtime.gc.onObjectFreed(list);`

**Takeaway**: **In an engine-less test, free a platform object the way the collector would; an interface's deinit is not the end of an object something else still finds by its slot.**
