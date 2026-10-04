# Architecture: Bootstrap stubs can shadow native global accessors

**Date**: 2026-10-03
**Lesson**: After wiring a native global attribute, verify that startup does not replace it with an older JavaScript stub.

**Why**: An own data property installed by bootstrap code wins over the native accessor. Checking that a global exists, or that an object passes instanceof against a constructor the same stub replaced, does not establish native behavior.

**What Happened**: WorkerGlobalScope gained native IndexedDB and Crypto accessors, but WorkerHost's setup script still overwrote both globals. Its IDBFactory.open returned a rejected Promise, so WPT failed at addEventListener or waited forever for request events. Its crypto.getRandomValues used Math.random, replacing the native random source. Factory identity/cmp controls had passed against the stub. A new real-request test failed its IDBOpenDBRequest assertion, and dedicated-worker descriptor tests found data properties instead of accessors.

**Fix**: Remove the obsolete IndexedDB and crypto bootstrap blocks with the shared file owner's grant. Keep performance's fallback because it still lacks a native worker getter. Test native attribute descriptors, interface prototypes and methods, and a real asynchronous IndexedDB upgrade/success sequence. WebIDL 3.7.6 uses the interface declaring the attribute: WorkerGlobalScope is not Global, so crypto/indexedDB belong on WorkerGlobalScope.prototype and the worker global must have no own shadowing property. DedicatedWorkerGlobalScope being Global does not move inherited members onto the global. An initial fixture incorrectly expected own accessors; correcting that expectation is a fixture repair, not an engine fix. Include WebCrypto worker results in the full before/after measurement.

**Takeaway**: **Test the object and behavior reached after bootstrap, not merely the native getter that startup can hide.**
