# Testing: A testdriver command must start as a task, not in the same turn

**Date**: 2026-11-20
**Lesson**: A WebDriver command reaches the page from outside it, so the runner's testdriver natives must start a command as a task queued on the page's event loop - never on a native timer that fires in the same turn, ahead of tasks the page queued before it asked.

**Why**: In a browser, `test_driver.set_permission()` (or `click()`, `actions`) goes through wptrunner's message queue and a WebDriver round trip: by the time the remote end acts, every task the page had queued earlier has run. Crane's runner armed a 0 ms native timer, and the event loop runs native timers in step 4 of the same turn that queued them - before the next turn's step 2 runs the page's older tasks.

**What Happened**: permissions/permissions-garbage-collect.https.html calls `navigator.permissions.query()` (which queues its resolution as a task) and, still inside that task's microtasks, `test_driver.set_permission(granted)`. The override landed before the query's task made the PermissionStatus, so the status was created already "granted" and heard no change event - TIMEOUT. A probe logging the order showed `set_permission` resolving before the query and before a `setTimeout(0)` queued ahead of it. The Permissions implementation was correct; the runner's scheduling was not.

**Fix**: tests/wpt_runner/test_driver.zig queues the command's first step on the realm's event loop (`Command.queueStart`), through a `StartTask` that never owns the command (endTest and the command's end clear it; it frees only itself, run or dropped). Later steps keep their timers. Red test: tests/wpt_runner/ar3_command_lifetime_test.zig "a testdriver command starts after the tasks its page queued before it".

**Takeaway**: **When a WPT result hinges on ordering between page tasks and a test_driver command, check the runner's scheduling first: a command must never run ahead of tasks the page queued before calling it.**
