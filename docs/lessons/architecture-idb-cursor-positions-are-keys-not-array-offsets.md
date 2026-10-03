# Architecture: IndexedDB cursor positions are keys, not array offsets

**Date**: 2026-10-03
**Lesson**: A cursor owns its visible record snapshot and resumes by comparing keys against its saved position.

**Why**: Inserts and deletes change record array offsets. Removing a record also frees its key and serialized value, while the cursor must continue exposing the previously visited record until its next iteration.

**What Happened**: Native IndexedDB cursors borrowed record keys and values and resumed from an array index. Inserting a lower key caused continuation to revisit the current key. A regression clearing records before reading the cursor's string key crashed with a segmentation fault in expectEqualStrings. Index cursors also omitted the referenced record value and reverse unique iteration picked the highest primary key.

**Fix**: Clone the query range and each selected key, primary key, and serialized value before publishing cursor state. On iteration, search records by the saved key and primary key tuple. For prevunique, select the first record with the chosen index key, as IndexedDB 6.7 requires. Exercise snapshot construction with an allocation-failure walk.

**Takeaway**: **Mutable storage requires stable key positions and owned snapshots; an array offset and borrowed record bytes cannot provide them.**
