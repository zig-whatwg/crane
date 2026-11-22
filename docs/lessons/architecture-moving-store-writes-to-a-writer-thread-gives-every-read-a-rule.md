# Architecture: Moving store writes to a writer thread gives every read a rule

**Date**: 2026-11-21
**Lesson**: When a store's writes move from the thread that made the change to a writer thread (a sequence), each read of that store can now miss a write that was handed over but not yet made; list every read and give it one rule - answer from the batch in flight, wait for the writer, keep the reader out until the write lands, or rely on an ordering that already guarantees it - and make an owner that ends with a write in flight wait for its outcome rather than roll back what may already be durable.

**Why**: Inline, a write was visible the moment the writing call returned, so no read needed a rule. A job queued behind other jobs is invisible to every reader until the writer thread reaches it, and the job's owner may end before it does.

**What Happened**: Lane prof2 moved every profile-store write of a Browser (localStorage, cookies, the HTTP cache, IndexedDB commits and deletions) onto one storage sequence, as Chromium writes them on sequences of their own. Each read needed its own answer:
1. HTTP cache: a lookup that misses memory reads the store - and would find nothing for a response whose batch was still queued, then drop it from the index. Fix: the batch stays IN FLIGHT and readable (queue, then batches newest first, then the store); the job retires it under the cache's lock after writing.
2. localStorage: an area's first read may follow an earlier bottle's batch. Fix: `barrier()` first - Chrome's renderer blocks on the same read (a synchronous GetAll answered after the commits queued on the database sequence).
3. IndexedDB deletion: a database record forgotten while its deletion is queued would be re-read from the store and come back. Fix: the deletion job holds the record (`holders`) until it is written, so no reader looks at the store's copy.
4. IndexedDB transactions: no rule needed - the scheduler starts an overlapping transaction only after the earlier one finished, and "finished" now means "its commit was written".
5. An agent ending with its commit in flight: aborting would restore the in-memory schema (key generators) under a commit that may be durable. Fix: the one wait an agent makes - it waits for that job, then completes or aborts as the write says.

**Fix**:
1. A job owns copies of what it writes (Chrome's CollectCommit): the changing thread goes on.
2. For each read, write down its rule beside it, citing why the browser's equivalent waits or not.
3. A waiter pointer in a cross-thread job is read and cleared only on the waiter's thread; the job's notify task holds a reference and finds it cleared if the waiter went.
4. A job may take a lock only if no thread waits for the sequence while holding it - say which locks in the sequence's header.

**Takeaway**: **Moving writes off-thread is a list of reads: for each, in flight, barrier, hold, or ordering - and an owner that ends mid-write waits for the write, never rolls back under it.**
