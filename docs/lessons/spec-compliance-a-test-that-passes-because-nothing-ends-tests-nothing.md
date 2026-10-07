# Spec Compliance: A test that passes because nothing ever ends tests nothing

**Date**: 2026-10-05
**Lesson**: Four `workers/SharedWorker-extendedLifetime*.html` files passed while Crane never closed a shared worker; implementing HTML's owner set - a worker whose owner set empties is closed - made all four fail, because the option they test, `extendedLifetime`, had never been implemented at all.

**Why**: A test of "X survives Y" passes trivially in an engine where nothing ever ends. Its green says only that the engine leaks the object for at least as long as the test waits. The moment a correct lifetime lands, every feature whose job is to EXTEND that lifetime shows up as a regression - and the tempting fix, keeping the object alive longer again, would bring the leak back.

**What Happened**: Workers batch 2 moved shared workers to threads of their own and implemented HTML 10.2.3's owner set: a Document joins when it makes or connects to a shared worker, leaves when it is destroyed, and a worker whose owner set is empty is closed (Chromium's SharedWorkerHost does the same when its last client goes). The targeted A/B over the 533 shared-worker files was blocking 42 -> 22 - and four files newly blocking: the extendedLifetime tests, which open a popup that makes `new SharedWorker(url, {extendedLifetime: true})`, close the popup, wait a second, and expect the same worker. The constructor had never read `extendedLifetime`; the files had passed because the worker was never closed.

**Fix**: Implement the feature the test names: SharedWorkerOptions.extendedLifetime is converted (after the inherited WorkerOptions members, WebIDL dictionary order), compared in the manager's step 11.4, and an orphan with it set is closed only once the extended lifetime shared worker timeout has passed with its owner set still empty (an epoch tells a stale timer from a current one). The four files pass again, for the right reason; the owner set's close stays.

**Takeaway**: **When a new lifetime rule turns tests red, ask whether they ever passed for the right reason: a "survives" test that went green on a leak is an unimplemented feature, not a regression - implement the extension, never restore the leak.**
