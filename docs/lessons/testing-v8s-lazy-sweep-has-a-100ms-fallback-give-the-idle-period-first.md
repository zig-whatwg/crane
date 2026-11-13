# Testing: V8's lazy sweep has a 100 ms fallback - a test of idle time must give the idle period before that task can run

**Status (2026-11-13, lane wr1 batch 11)**: SUPERSEDED on V8 15.7. cppgc's sweeper no longer posts an idle task: after a non-forced collection it posts a low-priority FOREGROUND task at once and a regular one 100 ms later (15.7.112.43 src/heap/cppgc-internal/sweeper.cc:39-40, 1028-1029, 1553-1576), and nothing else in V8's heap posts idle work. The engine idle periods this lesson's test exercised (engine.runEngineIdleTasks, tests/v8/wr10_idle_tasks_test.zig) were removed in the merge onto 15.7. What stays true: a test of a lazy phase must hand the engine its next step before a fallback finishes the phase for it - on 15.7 a pump runs the sweeper's task ahead of anything queued behind it (tests/v8/wr8_anchor_free_test.zig provokes a refused free at a safe point inside the task instead).

**Date**: 2026-11-10
**Lesson**: After a collection that V8 did not force, cppgc's sweeper posts an idle task and also a regular task 100 ms later. If no idle progress was made by then, the regular task finishes the sweep itself. A test pump that runs every due task in one go lets any task longer than 100 ms make that fallback due, so the sweep ends before the idle period the test is about.

**Why**: These are V8 13.1.203's rules, in src/heap/cppgc/sweeper.cc:
- `SweeperImpl::Start` posts a 0-delay regular task with `regular_task_is_delayed_idle_task_` set.
- On its first run, `SweepForTask` posts the idle task (`ScheduleIdleIncrementalSweeping`) and a regular one `kDelayWhileIdleSweepingMakesProgress` (100 ms) later.
- When that later task runs and the idle task has not run since (`saved_idle_task_count_ == idle_task_count_`), it sweeps in 5 ms slices until it is done.
- Once the idle task has made progress, the regular task only reschedules itself.

libplatform's message loop moves a delayed task into the queue as soon as it is due, so a pump of every task (`pumpPlatformTasks`) reaches it in the same call when an earlier task took long enough.

**What Happened**:
- Lane wr1 batch 10 ran tests/v8/wr10_idle_tasks_test.zig. Its setup made 100,000 wrappers dead before an unforced full collection, dropped 5,000 more in a scavenge, then ran `engine.runEngineTasks` once. The test expected the C++ heap still sweeping after that.
- On server1 (Linux) it passed 4/4. On chat.local (macOS) it failed 3/3 and failed alone too ("alone: fail fail"), so a race was not the cause.
- A diagnostic pumped one task at a time and logged the state after each. Task 6 posted the idle task. Task 8 was the scavenge's drain: it released the 100,000 collected wrappers and took about 159 ms. Task 9 was the 100 ms fallback, now due, and it finished the sweep.
- On Linux the drain stayed under 100 ms, so the fallback was not yet due when the pump ended.

**Fix**:
1. In the test, pump one task at a time (`v8_Platform_PumpMessageLoop` plus a microtask checkpoint, as `pumpPlatformTasks` does for each task).
2. Stop as soon as the state the test needs holds: the drain has been refused and the idle task is posted.
3. Give the idle period at once, before the next turn's tasks. After that the old fallback only reschedules.
4. The no-idle case keeps the run-all turns: there, V8's own fallback is the path under test.

**Takeaway**: **A test of what idle time does must hand over the idle period before any regular task that can do the same work as a fallback. A run-everything pump lets the host's speed choose which path the test exercises, so it passes on the fast host and fails on the slow one.**
