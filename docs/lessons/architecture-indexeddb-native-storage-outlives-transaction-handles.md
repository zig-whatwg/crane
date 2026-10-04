# Architecture: IndexedDB native storage outlives transaction handles

**Date**: 2026-10-03
**Lesson**: Database data and native connection lifetimes must be owned independently of script wrappers and transient transaction handles.

**Why**: A transaction's object-store handle is an access path, not the persistent store. A traced wrapper graph also does not impose an order on destruction of a collected cycle.

**What Happened**: IndexedDB kept records on an object-store handle and only names/versions in its factory map. Reopening a connection lost its schema and records, and later opens did not observe an upgraded version. Separately, releasing a database while a transaction still borrowed it caused an allocator panic when the transaction accessed freed schema storage. The storage regression tests reproduced both defects under std.testing.allocator.

**Fix**: Keep a canonical native database in the existing factory container, and put records and key-generator state in database-owned RecordData. Connections retain that backing data. Native transactions retain their connection; wrapper teardown releases an owner lease and the last transaction releases the native allocation. Copy names into the native owner rather than borrowing a wrapper's allocation. Check the recorded slab generation before calling a borrowed factory during wrapper teardown. Pin reopen/version persistence and connection-release order with allocator-backed tests, and still run the required engine teardown/timer gates before merging the binding changes.

**Takeaway**: **Persist the data independently of handles, and give each native borrow a lifetime that survives either wrapper destruction order.**
