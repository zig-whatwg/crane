# Testing: A lateness bound in milliseconds measures the host's scheduler

**Date**: 2026-11-15
**Lesson**: A test that asserts "the timer fired within N ms of its deadline" tests how soon the host runs a thread it has just woken. Assert what the code decides - never early, earliest deadline first, the deadline and not some other bound - and prove where the lateness comes from before blaming or excusing the code.

**Why**: The window event loop waits for a timer in slices of at most 1 ms (TaskSink.waitForWork) and fires what is due when a wait returns. Everything the loop controls is the length it asks for. How long the wait really lasts is the kernel's: a thread at nice 10 that becomes runnable on a CPU held by nice-0 work waits its turn.

**What Happened**: tests/html/rep2_window_wake_test.zig asserted `worst < 5` ms over ten 20 ms timers. It failed three gates in one day, each time about 5.9 ms late, on server1 under a 32-runner WPT sweep (the tests run at nice 10 through the pool's build shim). It could not be reproduced by the obvious means: on macOS neither background QoS nor 16 busy loops moved it past 2.3 ms, and 3,600 timers sampled beside a real sweep peaked at 3.4 ms. It reproduced only with the gate's own shape made heavier: the test at nice 10 pinned to four CPUs beside eight nice-0 busy loops on the same four (3 failures in 6 runs; 0 in 82 with four busy loops or three). A second series at that load, one CPU and two busy loops a copy: the old assertion failed 9 runs of 12 (worst 5.0 to 12.0 ms), the new test 0 of 52.
The proof was a temporary instrumentation of the loop's wait step: for each timer fire, what the turn did before it. Every timer 2 ms late or more (19 of 200, up to 12 ms) fired straight after a wait the loop had asked to last 1 ms and the kernel returned 5.6 to 29 ms later, in a turn that had done nothing else. None came from a gap between turns.
Two things that looked like findings and were not:
1. A control thread making "the same wait" beside the loop was 0.1 ms late where the loop was 0.9 ms late on macOS. The cause was phase, not the loop: a 1 ms wait there takes 1.25 to 2 ms, and whether the last slice ends before or after the deadline depends on the sum of the slices before it. Two threads making the same waits are not a control for each other at sub-slice scale.
2. A process CPU figure (44 ms per 600 ms) read as "the loop spins 7% of a core". The loop's own thread measured 6 to 8 ms; the rest was the test harness. Measure the thread you are accusing.

**Fix**:
1. Reproduce with the failing condition's shape, not with "load": here the priority difference (nice 10 against nice 0) mattered more than the load average.
2. Instrument the wait itself: asked and taken, and what else the turn did. Pair each late event with its row. If every late event follows a stretched wait, the bound measured the host.
3. Replace the bound with assertions the code decides: no timer fires before its deadline; timers armed latest-first fire earliest-first; and the timer fires at its deadline, not at the caller's bound, with the two set ten seconds apart so that the line between them is nowhere near any scheduler's delay.
4. Say in the test what was measured and why no millisecond bound holds.

**Takeaway**: **A wait's length belongs to the kernel; a test can only own the length the code asks for. Bound a timing test by the alternative behaviour it must exclude, placed seconds away, not by a delay that is fine on a quiet host.**
