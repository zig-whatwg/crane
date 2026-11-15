# Architecture: A second timer poll in one step lets a callback's 0 ms timer overtake the tasks it queued

**Date**: 2026-11-14
**Lesson**: Step 4 of the window loop fires each due timer at most once per turn. If a poll fired anything, the step ends there. Polling again in the same step fires the 0 ms native timers those callbacks armed, ahead of the tasks the same callbacks queued.

**Why**: `NativeTimerManager.pollEach` fires what was due and armed when the poll began: a timer armed by one of its callbacks waits for the next poll (`armed_before`). That rule only holds if the caller does not poll again in the same step. The timer backend's own `pollBlockingEach` returns as soon as a poll fires anything, and polls a second time only after it has slept. The tasks a timer callback queues run in step 2 of the NEXT turn, so a second `pollEach` in the same step runs a 0 ms native timer (deadline = now) before them. Window `setTimeout(0)` does not show this, because its task is queued at the call (Context.zig queueAtCall). Native timers whose callbacks run script directly do show it: test_driver's commands, `AbortSignal.timeout`.

**What Happened**: Lane rep2 (dab33ca170c) changed step 4 from the timer backend's sleep to a wait on the loop's task sink. It wrote the step as "poll; if nothing fired, wait; poll", and the last poll ran even when the first had fired. On the production runner, permissions/event-model.https.html's last test went OK -> TIMEOUT, 3 of 3 runs; main's runner was OK 3 of 3. Here is the sequence. `test_driver.set_permission("prompt")` resolves in a native timer's callback. The test's continuation queues `navigator.permissions.query`'s task (Permissions query step 8) and arms `set_permission("granted")`'s 0 ms timer. The second poll changed the permission before the query's task had made the PermissionStatus that listens for the change, so no change event ever came. A JavaScript-only reproduction with `setTimeout(0)` passed on the broken build, for the reason above.

**Fix**: Poll a second time only after a wait (18875fa4cbb):

```zig
if (mgr.pollEach(after_each)) {
    did_work = true;
} else if (wait_time > 0) {
    // ... wait on the sink ...
    if (mgr.pollEach(after_each)) did_work = true;
}
```

The red test (tests/html/rep2_window_wake_test.zig) uses two `AbortSignal.timeout(0)`s. The first one's abort listener queues a permissions query task and arms the second. The order of the results is "timer,task" before the fix and "task,timer" after.

**Takeaway**: **When you replace a poll function, keep its "return after a poll that fired" rule. Test the ordering with a native timer whose callback runs script directly, not with `setTimeout(0)`, whose task is queued at the call.**
