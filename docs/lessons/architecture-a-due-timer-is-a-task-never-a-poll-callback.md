# Architecture: A due timer is a task in the queue, never a callback run from the loop's poll

**Date**: 2026-11-05
**Status** (2026-11-06, lane loadpath1 batch 3): a ZERO-delay timer's task is queued at the setTimeout call, not when the poll finds it due - Chromium and Gecko queue it then (spec-compliance-a-zero-delay-timer-is-queued-at-the-call.md); "Chromium's sequence manager gives a delayed task its place ... when it becomes ready" below holds for delayed timers only.
**Lesson**: Crane ran a window timer's handler from the native timer's callback, which the event loop polls after the turn's tasks, so a zero-delay timer armed in a task ran before every task that task had queued earlier - a details toggle, a selectionchange, a frame's deferred destroy, a navigation's history update.

**Why**: HTML's timer initialization steps end with "run steps after a timeout", whose completion step QUEUES A GLOBAL TASK on the timer task source; the event loop then runs the oldest runnable task. Chromium's sequence manager gives a delayed task its place in the queue when it becomes ready, after the running task. A poll that runs callbacks outside the task queues is a second scheduler, and its order is whatever the loop's steps happen to be.

**What Happened**: lane loadpath1's FULL A/B: 10 deterministic losses (toggle and selectionchange files, settimeout-detached-iframe, two navigation-API files). Hidden for months because WPT pages ran their scripts outside any task (the embedder's synchronous load) until every page load became a navigation; the browser console showed it at once ('timeout,toggle').

**Fix**: 212dcdf7360. The native timer is only the wait: its callback queues the timer's task (document = the Window), and the task runs steps 8.2-8.9. The timer record's ownership is written per state (armed: the native callback; queued: the task, which frees it run or dropped; held: the map) - a cleared queued timer has its handles released at once and its record freed by its task.

**Takeaway**: **Anything the spec says "queue a task" for must enter the task queue at that moment; running it from a side poll keeps an order nobody chose - and the first page that runs inside a task will find it.**
