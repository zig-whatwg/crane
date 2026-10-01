# Testing: A ceiling checked between event-loop turns cannot stop a script, and a per-file watchdog cannot see per-run progress

**Date**: 2026-10-01
**Lesson**: A run's ceiling was checked only between event-loop turns, and the supervisor's stall watchdog counted only finished files. So a synchronous script ran past its ceiling until the 150 s stall kill. A file of four legal 60 s variants was also killed at 150 s, because no file record had appeared. Both kills lost every result in the file.

**Why**: `waitForCompletion` compares the clock after `runEventLoopBlocking` returns. A script the parser runs, or a timer callback that loops, never returns there. The supervisor's watchdog watched the journal, and the journal gains a record only when a file's LAST run ends. A run, though, is a test URL (globals x variants), and each run has its own ceiling, as wptrunner gives one per URL. The full corpus's "120 s timeouts" were 2-variant files, not a ceiling that doubled. 15 of its 19 stall kills were files with 4-55 variants.

**What Happened**: the three NodeList-static-length-getter-tampered-indexOf-* files were killed at 150 s with 0 subtests. On a ReleaseSafe runner, with nothing enforcing the ceiling, they "passed" at 85 s against a 60 s ceiling.

**Fix**:
1. The supervisor gives each child a heartbeat file (`--heartbeat=`, one byte per run start), and the watchdog counts it with the journal (`stall_watchdog.watchedSize`).
2. `script_deadline.ScriptDeadline` runs on its own thread. Past ceiling + 1 s, if the run has not disarmed it, it calls `engine.abortRunningScript` (HTML 8.1.4.5 "abort a running script"; V8 TerminateExecution, which any thread may call). It repeats every second until disarmed. The run resumes the agent, lets the harness report, and records TIMEOUT.
3. The ceiling counts from the run's start, so a slow load no longer buys a second full wait.

The runaway scratch page then gave TIMEOUT at 11.0 s with 2 PASS + 1 TIMEOUT, where it used to be killed at 150 s with nothing reported.

**Takeaway**: **A deadline checked by the thread it bounds cannot fire while that thread is in script: put the clock on another thread and give it a way into the engine. A watchdog must count progress in the unit the budget is given in, which is runs, not files.** V8 reports a terminated evaluation to the host as an exception (one report per abort, measured), so whatever is downstream of the abort must not read the harness's ERROR as the outcome.
