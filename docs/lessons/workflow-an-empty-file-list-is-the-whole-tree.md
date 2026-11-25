# Workflow: An empty file list is the whole tree

**Date**: 2026-11-25
**Lesson**: A runner given no file runs every test it can find, so a derived list that comes out empty does not skip a step: it widens it to everything. Every step that hands a runner a computed list refuses an empty one, and a list a step needs from the whole worklist is taken from the whole worklist.

**Why**:
- `wpt_runner` with no file arguments, and `crane-measure.sh run` with an empty `--from-file`, run the WPT tree's every test. That is the right default for a person at a terminal and the wrong one for a script.
- The lanes' A/B scripts built lists inside the window (the targeted list, the changed files, the timer files) and passed them on without looking.
- The scripts were copied from lane to lane, so a list built the wrong way in one copy was built that way in the next.

**What Happened**:
- Lane hard1-usp ran a targeted url/ A/B on server1 on 2026-11-25.
- Its script took the regression protocol's timer files (html/webappapis/timers/) from the TARGETED list. A url/ list holds none.
- The empty list reached the runner, which ran the whole tree as "timers" for 70 minutes while lanes waited behind the window.

**Fix** (lane tool1-ab):
- `wpt_ab` (tests/wpt_runner/ab.zig), the one committed A/B runner, refuses an empty list at every step: `emptyListProblem`, with a line saying why.
- The A/B itself exits 2. Rerun, timers and verify skip with a line.
- The timer files come from the whole worklist (`timerFiles`); a worklist without one skips the step.
- Each side's records are counted against its list before a verdict.

**Takeaway**: **Before you hand a tool a list you computed, check it is not empty: for a test runner, an empty list does not mean "nothing", it means "everything". Take a protocol's fixed files from the source that always has them (the whole worklist), never from a subset that may not.**
