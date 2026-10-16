# Testing: A shared nesting guard races first as a stale restore, not an underflow

**Date**: 2026-10-15
**Lesson**: A save-and-restore re-entrancy guard shared by two threads fails on nearly every overlap by putting back the other thread's value; the counter underflow it is known by needs a lost update and is rare, so test the restore.

**Why**: A guard of the form `previous = current; current = mine; ...; current = previous` is only correct when its scopes nest. Two threads' scopes overlap without nesting whenever the first to enter is also the first to leave: the second to leave then restores the value the FIRST thread had set. A depth counter beside it (`depth += 1` / `depth -= 1`) stays balanced unless two read-modify-writes interleave on the same instruction, which is a window of nanoseconds.

**What Happened**: html.script_execution kept the document a script-queue drain walks (`draining_document`) and the drain depth (`drain_depth`) in process-wide variables. The known symptom was the depth underflowing and panicking in `tests/html/instances_navigables_test.zig`, now and then in native gates; that test passed 6 of 6 standalone runs on main. A test that held two Browsers' drains open together for ~25 ms (a deferred module script busy-waiting) and then asked each Browser for another drain of the same document failed 7 of 7 runs on main: the drain that ended second left the other Browser's document recorded as "draining", so that document's every later drain returned at once and its inserted script never ran.

**Fix**: The drain state moved onto its owner, the agent (`AgentHost.script_drain`, found once when a drain is entered), and the test (`tests/html/instances_script_drain_test.zig`) went 0 of 6 failures after.

**Takeaway**: **To make a cross-thread race on shared guard state reproducible, hold both critical sections open for milliseconds and assert what the restore leaves behind, not the crash a lost update causes.**
