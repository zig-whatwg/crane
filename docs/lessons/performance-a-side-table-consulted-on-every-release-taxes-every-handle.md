# Performance: A side table consulted on every release taxes every handle

**Date**: 2026-11-07
**Lesson**: When a release path asks a process-wide map whether a handle is in it, every release pays for the lock, the hash and a cache-missing find, including the great majority that were never in it. Keep the "am I in it?" answer on the handle itself, and go to the map only when that answer is yes.

**Why**: The map grows with what it tracks: Crane's armed-handle map holds every live DOM wrapper. A miss is the expensive case (a find that walks a cold bucket), and on a dispose it is almost always a miss. The cost hides from a profile read by function. It appears as `std::mutex::lock`, `__hash_table::find` and the inlined copies of the release helper in every `v8_*_Dispose`, spread across every row, and never as one hot function of Crane's.

**What Happened**: perf3's profile (tmp/plans/perf3-design.md, section 1.3) bucketed the samples of eight rows by caller.
- Every `v8_*_Dispose` took `weakDataLock()` and looked the handle up in `armedWeakData` (releaseWeakArm). Whenever any handle in the process was realm-tagged, which an event listener is enough to cause, it also took `realmTagLock()` and erased from `realmTaggedHandles` (untagRealmHandle).
- The two maps cost 13-37% of EVERY row: getter 16.9%, method 23.7%, event-ctor 36.8%. The armed map's `find` alone was 16.2% SELF of event-ctor, where thousands of dead Events wait for the collector and fill the map.
- Nearly every one of those lookups found nothing.

**Fix**:
1. Mark membership on the handle's own node, through V8's public API. In perf3 phase 1a (f9c03aa259e) these are two bits of the node's wrapper class id (`PersistentBase::SetWrapperClassId`/`WrapperClassId`): `kArmedFlag` and `kRealmTaggedFlag`, beside the kind byte the class id already carried.
   - Set the bit under the map's lock when the entry is added; clear it when the entry is erased.
2. A release reads the bit first. If it is clear, the release takes no lock, does no hash and finds nothing.
3. Keep the two in step:
   - A Debug-only check aborts when the flag and the map disagree (flag set, entry absent).
   - A test shows that a freed node is reused with a clean class id. V8 clears class_id in `NodeBase::ClearFields`, and tests/v8/perf3_dispose_marks_test.zig pins it.
   - A moved handle (TakeOver) clears the mark of the node it leaves.
4. Measure it the way it was found: re-profile the same rows, bucketed by caller, and compare the release buckets. The acceptance is the Crane-only perf window, which times the tip against a frozen base. Correctness comes from the A/B, timers x3 and leaks --atExit, because a mark that drifts from its map leaks an arm or frees one twice.

**Takeaway**: **A membership question asked on every release belongs on the member, not in the set. Before optimizing what a hot path does, bucket its profile by caller: a cost spread thin over every row is still the biggest one.**
