# Architecture: An idle period too short to run anything must not start

**Date**: 2026-10-31
**Lesson**: Start an idle period only when it can last a minimum (Blink: 1 ms, IdleHelper kMinimumIdlePeriodDuration), and otherwise wait for the work that bounds it, not for the next turn.

**Why**: computeDeadline bounds a period by the next timer, which the loop reads in whole milliseconds rounded down. A timer due in under a millisecond reads as "due now", so the period was over when it began. Its "invoke idle callbacks" task found now past the deadline, ran nothing and asked again. The loop then started another period on the next turn, and nothing waited between them.

**What Happened**: lane flaky3 saw the window's idle task re-queue about 100 times in a millisecond, with a fetch in flight. Any page with a requestIdleCallback waiting and a timer due soon burned CPU that way until the timer fired: CPU taken from the other runners in a sweep.

**Fix**: EventLoop.startIdlePeriod computes the deadline first and returns without starting when it is less than min_idle_period_ns (1 ms) away. idleWaitMs then asks for no wake-up of its own: the turn's wait already ends at that timer. tests/html/fk2_idle_period_spin_test.zig checks that every idle period that starts runs a callback.

**Takeaway**: **A retry loop whose exit condition is time needs a minimum step that is not zero; "try again next turn" spins when nothing in the turn waits.**
