# Architecture: Reject invalid keys before map insertion

**Date**: 2026-10-22
**Lesson**: A security key that deliberately fails equality with itself must never enter a hash map.

**Why**: Failing closed for an identity-less opaque origin prevents two unknown origins from sharing a partition. A hash map also needs every admitted key to be reflexive: insertion, lookup and removal must agree about the same key.

**What Happened**: StorageKey's opaque-identity correction also rejected the empty top-level-site sentinel used by origin-only StorageManager and quota administration. A shelf was inserted and could not be found immediately afterward, crashing ten native tests. The IndexedDB server could similarly insert invalid keys that its removal path could not find.

**Fix**: Keep the existing administrative sentinel comparable only to the same tuple-origin sentinel with the same ancestor bit. Reject invalid storage-purpose keys before either shelf or IndexedDB map insertion, including opaque keys that carry an identity. Test clone/hash/lookup/removal, separation from real partitions and other origins, and rejection without modifying the map.

**Takeaway**: **Put validity checks at map entry points; do not use non-reflexive equality as the only rejection mechanism.**
