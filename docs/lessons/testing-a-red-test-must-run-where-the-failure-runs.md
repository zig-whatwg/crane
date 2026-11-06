# Testing: A red test must run where the failure runs - the same kind of task, the same delivery

**Date**: 2026-11-05
**Lesson**: Two red runs of the timer-order tests passed on the unfixed tree: the scenarios ran from a markup load's commit (a queued task) and then from a timer's task, where the old poll happened to keep the order. The WPT pages failed because they come over the network, and their scripts run in that navigation's commit.

**Why**: An ordering bug depends on which step of the loop the code runs in: a task queued in step 2, a posted or network-delivered one, a timer callback in step 4. A test that reproduces the symptom in a different context tests a different path.

**What Happened**: lane loadpath1. The console reproduced the bug in one line (its input is a posted task); tests/browser's loadHTML pages did not. Moving the pages to tests/repl's loopback Site (HTTP, the WPT delivery) made 4 of 5 red for the right reason ("timeout,toggle").

**Fix**: tests/repl/loadpath1_timer_task_test.zig loads each page with Browser.navigateInPlace from the Site; its red run is recorded in the commit.

**Takeaway**: **Before trusting a red/green pair, check the red failed with the failure's own message; when it does not, reproduce the failing file's delivery (network commit, timer task, posted task) rather than its code alone.**
