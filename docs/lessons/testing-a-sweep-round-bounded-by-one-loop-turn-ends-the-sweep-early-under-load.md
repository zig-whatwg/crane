# Testing: A sweep round bounded by one loop turn ends the sweep early under load

**Date**: 2026-11-17
**Lesson**: An out-of-memory sweep that arms the i-th allocation, runs the event loop for a fixed time and takes "nothing failed" as "past the last allocation" ends early on a loaded host - run each round until its loop has nothing left to do.

**Why**: tests/html/iframe_policy_container_oom_test.zig's sweeps armed a failing allocation, ran `runEventLoopBlocking(50)` once, disarmed the allocator, and ended the sweep at the first round that induced no failure. On a loaded host the round's navigation had not reached the armed allocation when the 50 ms ended; it then finished with memory to spare, and the sweep stopped as if it had covered every allocation.

**What Happened**: the contentWindow sweep failed under load (impls9, chat.local, an every-test run; FLAKY, alone pass then fail) with no line saying why. With its error and round printed (lane bugs1), it was caught on chat2.local beside every tests-html test at batch 1, 1 of 48 alone runs: `sweepContentWindow failed: NoRoundStoppedBeforeTheDocument in failing allocation 146` - the sweep had ended before the rounds that stop between the new realm and its document. On server1 it never failed (352 alone runs, up to 2x oversubscribed). The file's policy-container sweeps end the same way but have no final check, so on a loaded host they PASSED having tested only part of the navigation - silently.

**Fix**: `runRound` runs the round's loop, the allocation still armed, until a turn runs out of pending work before its 50 ms (`Browser.runEventLoopBlocking` returns early exactly then) or a full turn does no work, at most 10 s. 144 of 144 alone runs passed beside three every-test runs on chat2 afterwards.

**Takeaway**: **"Nothing failed in this round" means "past the end" only if the round ran to completion: bound a sweep round by the loop going idle, never by a fixed time - and give every way a sweep can end a printed reason, or a loaded host turns it into an unexplained flake or a silent pass.**
