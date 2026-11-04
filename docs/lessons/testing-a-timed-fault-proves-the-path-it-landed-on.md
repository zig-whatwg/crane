# Testing: A timed fault proves the path it landed on, not the one it was aimed at

**Date**: 2026-11-04
**Lesson**: A fault injected on a timer (a stop file touched after N seconds, a stall limit, a signal
after a delay) can land before, after or beside the step it was meant to hit. The run still passes,
because the path it took really works. Read the evidence that the INTENDED path ran before you claim
it tested.

**Why**: A timer measures the clock, not the program's progress. The same delay lands somewhere else
on a faster build, a warmer cache or a smaller list. Each landing exercises a real path whose result
looks fine. A run that "passed" with the fault nowhere near its target is indistinguishable from one
that passed with the fault on target, unless the check names the target.

**What Happened**: Lane sweepq1's real-process smoke of the WPT runner's shared queue
(tests/wpt_runner/work_queue.zig) aimed three faults with timers. Two landed off target:
- **Stop file at 20 s.** The 40-file run finished in 13 s (the Debug runner was faster than
  assumed), so the stop never fired. The check passed: rc 0, 40 records, identical to the full run.
  Only the missing exit 3 and the missing "stopped" line showed the stop path had not run. With
  80 files and the stop at 5 s, it stopped at 20/80 (exit 3) and `--resume` ran the other 60.
- **Stall limit of 300 ms.** The watchdog was meant to kill a child hung on its claimed file. It
  killed every child during process start-up instead, before any claim. Every file was journalled
  once, ERROR "not run" after two rounds: a real, correct path (a runner that cannot start), but not
  the hang attribution. An 8 s limit and one file with a 60 s ceiling exercised that:
  "hung on [3] ...", TIMEOUT "supervisor killed a child that made no progress for 8000ms".
- **SIGSEGV to a child after 4 s** landed mid-file as intended, but only the log line
  "crashed on [39] ..." with the CRASH record proved it.

**Fix**: For every injected fault, write down the evidence that only the intended path produces:
an exit status, a log line, a record's status and message. Make the check assert that evidence, and
not only the run's overall success (here: rc 3 and "Run stopped" for the stop, "hung on [i]" for the
hang, "crashed on [i]" for the crash). Prefer a trigger tied to progress (the Nth record, a named
file) over one tied to the clock. Where a timer is unavoidable, make the work outlast it by a wide
margin: a long list, a file with a long ceiling.

**Takeaway**: **A fault aimed by a timer tests wherever it lands. Assert the evidence of the intended
path (its exit code, its log line, its record), not only that the run came out right.**
