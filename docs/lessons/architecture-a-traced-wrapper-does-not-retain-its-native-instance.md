# Architecture: A traced wrapper does not retain its native Instance

**Date**: 2026-10-03
**Lesson**: Rooting a JavaScript wrapper and keeping its native Instance alive are separate contracts.

**Why**: Realm retirement severs wrappers and frees native non-node Instances unless another realm's wrapper cache retains the same Instance. A traced property or Owned JavaScript value roots the wrapper, but does not supply that native retention.

**What Happened**: IndexedDB captured the correct result realm, but a foreign cursor method could queue a request in a live parent realm whose source cursor belonged to a retiring child realm. The queued write still read the cursor pointer. Request source and transaction associations could likewise outlive their native children. The adapter source and integrator Q25 confirmed the contract; passing iframe-removal probes did not prove forced retirement or reproduce a native crash.

**Fix**: Capture accepted cursor writes as owned backend store and transaction leases, a copied effective key, and serialized bytes. Execution no longer needs the cursor Instance. Return any-typed source attributes through traceValue/tracedValue to preserve wrapper identity. For retained native pointers, save their Context separately and check hasEngine() before dereferencing; reading pointer.ctx would already dereference freed storage. Typed nullable associations use the explicitly approved temporary null fallback while the engine-wide lifetime work remains queued. The Context check itself relies on the retirement contract, including its separately tracked OOM defect.

**Takeaway**: **Prove native retention independently of JavaScript reachability, and never read liveness through the pointer being checked.**
