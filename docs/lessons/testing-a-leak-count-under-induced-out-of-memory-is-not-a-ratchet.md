# Testing: A leak count under induced out-of-memory is not a ratchet; check each block's cause

**Date**: 2026-11-11
**Lesson**: An out-of-memory sweep that fails the i-th allocation of each round does not fail the same operation in every run. Collections and the deferred teardown's slices allocate too, and they run when the engine decides, so the operation that index i lands on shifts. A leak allowance taken from one run ("at most 14 blocks") flakes. Classify each leaked block by its cause instead: the stack of the round's induced failure.

**Why**: tests/html/iframe_policy_container_oom_test.zig's contentWindow sweep checks what the Browser holds after its teardown. Lane v8up b3h named a queued leak there: engine.traceChild drops a child whose wrap fails. The check allowed at most 14 blocks of that leak's kinds and no other block. That was chat2's one measurement, with no margin, "so the debt can only go down".

**What Happened**: At b3i's tip, chat2's full test run left 15 blocks and the test was FLAKY: it failed in its first run, passed alone once and failed alone once. Six reruns from the same binary passed. Under -Dsanitize-thread on macOS it left 13 known blocks and one CustomElementRegistry in 3 runs of 3. That was the same leak: the round's failure was WrapperCache.set under Document.ensureGlobalRegistry's traceChild. It was a fifth kind the list did not name, reached only because TSAN's allocation order put round 229's failure there.

**Fix**: The sweep records each round's induced-failure stack (CountingAllocator.failures). A live block is of the queued leak only when it is of a known kind AND the rounds it was allocated in failed inside protocol_tracing.traceChild (`failedInTraceChild`). Every other block fails the test with its stack. The block-count cap was removed.

**Takeaway**: **Under induced out-of-memory, a ratchet on a count is a flake waiting to happen. Attribute each leaked block to the failure that caused it, and allow only the known cause.**
