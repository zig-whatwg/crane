# Architecture: Share a counter only when both consumers need opaque identities

**Date**: 2026-10-24
**Lesson**: An existing monotonic sequence can serve another owner-local identity domain when neither consumer depends on consecutive values.

**Why**: Adding one eight-byte field can move a frequently allocated object into a larger allocation class; a size ratchet measures that cost even when functional tests pass.

**What Happened**: A separate shadow-tree serial counter grew Document's state to 2056 bytes and failed its existing 2048-byte size pin. Document already allocated nonzero load-task tokens from a monotonic counter. Pending and early load tokens were compared for equality, never for consecutive order or distance.

**Fix**: Audit every reader before sharing the sequence. Keep pending-token state and lifecycle comparisons unchanged, allocate both identities through one private owner helper, and expose the scope operation through the existing process-start-installed hook. Test real shadow-root creation between real load-token allocations, nested adoption into another document, and the unchanged Document size and loading controls. Do not weaken the size pin or add a private-state observation API.

**Takeaway**: **Reuse an identity sequence only after proving that gaps are harmless to every consumer, then pin the interleaving through public owner operations.**
