# Architecture: Abort a job by marking it, not by freeing it

**Date**: 2026-10-18
**Lesson**: When something must abort an in-flight job from outside (Clear-Site-Data aborting a service worker scope's jobs), settle its promise now and mark it aborted; let it finish through its own resume points - never free it while a waiter holds its pointer.

**Why**: The service worker registry's jobs are resumed by other calls: a running register job is pointed to by its worker's start waiter (`Waiter.update: *Job`), by an InstallOp (`op.job`), and by id from the job thread's script fetch (`updateFetched(job_id)`). A job at the front of its queue may also not have begun yet, while its Run Job task is already queued on the job thread. Freeing such a job from the outside leaves a dangling waiter, and removing an unstarted front job lets the next scheduled job be run twice (the stale Run Job task and the new one both find it at the front).

**What Happened**: Lane sw1-b8's `Registry.clearOrigin` (Chrome's `job_coordinator_->Abort`, which unregister-immediately-before-installed expects as an AbortError) had to abort a register job whose worker was still parsing an infinite loop, one whose install event never settled, one waiting for its fetch, and an update job whose Run Job task had not run. The first sketch removed and destroyed every job of the scope.

**Fix**: Two kinds of job, two treatments:
1. Jobs behind the front of the queue have never begun and nothing points at them: reject their promise with AbortError, remove and free them.
2. The front job: reject its promise now (`rejectJob` already ignores a settled promise later), set `job.aborted`, and leave it in the queue. Each resume point checks the flag and only finishes: `runJob` (not begun), `updateFetched` (its fetch came back), `updateRan` (its worker's start answered - terminating a worker whose evaluation won the race). The install and activate paths need nothing new: the worker's termination ends their events, and their existing "cleared meanwhile" checks finish the job.
Pin each resume point with a native test under std.testing.allocator (tests/service_worker/registry_test.zig "Clear-Site-Data: ..."), including the race where the worker's evaluation arrives after the clear.

**Takeaway**: **An outside abort settles and marks; the job's own resume points finish it. List every pointer to the job (waiters, ops, queued tasks) before freeing anything.**
