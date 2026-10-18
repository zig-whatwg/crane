# Spec Compliance: IndexedDB Shared Buffer Keys Are Not Stored Values

**Date**: 2026-10-18
**Lesson**: IndexedDB key conversion and storage serialization use different buffer rules.

**Why**: IndexedDB 7.4 accepts a WebIDL *buffer source type*, which includes SharedArrayBuffer and views over it, and copies its bytes into a binary key. That category is broader than an ordinary WebIDL `BufferSource` argument conversion. StructuredSerializeForStorage instead rejects shared buffers, including nested values.

**What Happened**: Row 71's brief called SAB keys invalid. The complete `indexeddb_keys.convertSeen` algorithm already handled them through `getCopyOfAllowSharedBufferSourceBytes`; an initial partial read overlooked that fallback. Upstream key WPT expects acceptance. The aligned browser run on 2026-10-18 split: Safari passed 3/3, Firefox passed 0/3, and Chrome crashed. [IndexedDB issue 506](https://github.com/w3c/IndexedDB/issues/506) records the disagreement and proposed change; it remained open. No browser majority or merged spec change justified altering Crane's implementation.

**Fix**: Preserve the existing conversion and pin copied bytes in native tests for a SAB, offset typed-array/DataView ranges, and an array containing a SAB. Mutate the source after conversion to prove the key owns a copy. Separately assert that storage serialization rejects a SAB, a shared view, and a nested SAB. The upstream `crossOriginIsolated` prerequisite is a separate failure, not evidence that either algorithm ran.

**Takeaway**: **Read the algorithm's exact buffer category and distinguish key conversion from storage serialization before choosing an engine operation.**
