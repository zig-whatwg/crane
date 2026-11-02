# Architecture: A clock that stands still must be woken to the exact deadline

**Date**: 2026-11-02
**Lesson**: A virtual clock moves only when the event loop moves it, so the loop must move it to the timer's exact deadline in nanoseconds. A deadline rounded to whole milliseconds reads as "due now" while the timer is not due yet, and on a clock that never moves on its own that is an endless spin.

**Why**: Crane's event loop computes its wait from `NativeTimerManager.getNextTimerDeadline()`: whole milliseconds, rounded down. On a real clock that is harmless. A wait of 0 polls, nothing is due, and a few hundred microseconds later real time has made the timer due. On a virtual clock (Chromium's MOCK_TIME: time moves only when the loop is idle) nothing moves between turns. A timer 0.5 ms away reads as a wait of 0, the poll finds nothing due, `hasPendingWork` keeps the loop turning, and the clock stays put forever.

**What Happened**: Lane detplat1's first draft of the loop's fast-forward ran only "when the turn would wait" (`wait_time > 0`). Tracing that rule against a timer armed less than a millisecond before its deadline showed the spin before any test ran. A timer armed mid-millisecond on a virtual clock is common: a frame timer's ceil-to-ms deadline, a nested timer armed by a callback.

**Fix**: `NativeTimerManager.nextDeadlineNs()` gives the heap top's deadline exactly. On a virtual clock the loop's step 3a fast-forwards to the earliest wake-up whenever nothing is runnable, posted or waiting for teardown. The earliest wake-up is that deadline, or the moment an idle period may start, in ns. This runs whatever the millisecond wait came to. A real clock never takes the branch (`BrowserClock.isReal()` first). Work budgets keep real time even on a virtual clock (the deferred-teardown slice), because a virtual clock stands still while the loop works.

**Takeaway**: **On a clock nothing advances but you, every rounding of a deadline is a hang. Wake it to the exact deadline, and never let "a wait of 0" stand for "due".**
