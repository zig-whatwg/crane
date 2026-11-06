# Spec Compliance: A zero-delay timer's task is queued at the setTimeout call

**Date**: 2026-11-06
**Lesson**: Chromium and Gecko queue a 0 ms setTimeout's task when setTimeout is called. A timer whose task is queued when a poll later finds it due goes behind the tasks queued after the call, and so does a "queue a task" built as a 0 ms native timer.

**Why**: HTML's timer initialization steps end with "run steps after a timeout", whose completion step queues the task. With 0 ms there is nothing to wait for. Blink gives a zero timeout TaskType::kJavascriptTimerImmediate; TimerBase::Start gives it a null fire time, and TaskQueueImpl::PostTask posts it as an immediate task (PostedTask::is_delayed() is false). Gecko's TimeoutExecutor::Schedule dispatches immediately when the deadline has passed. WebKit fires a run-loop timer. Delayed timers do take their place in the queue when they become ready.

**What Happened**: Lane loadpath1's batch 2 made window timers tasks, queued from the native timer's poll (212dcdf7360). That fixed every "task queued BEFORE setTimeout" order. It broke the "task queued AFTER setTimeout" ones:
- prompt-and-unload-script-closeable.html: testharness.js's load-time setTimeout(0) lost to window.close(), whose "queue a task" was a 0 ms native timer that ran from the poll ahead of every queued task.
- DOMContentLoaded-defer.html: the timer now ran after DOMContentLoaded's task.

**Fix**: A timer whose clamped timeout is 0 reserves an id from the agent's timer manager (TimerInterface.reserveId, one id space) and queues its task at the call (`queueAtCall`). window.close()'s definitely-close is a real task on the loop.

**Takeaway**: **"Queue a task after a 0 ms wait" means queued now, in call order: read the engines' posting code (Blink's DOMTimer and TaskQueueImpl::PostTask, Gecko's TimeoutExecutor) before choosing where a timer enters the queue, and grep for "queue a task" steps built as 0 ms native timers - they run outside the queue.**
