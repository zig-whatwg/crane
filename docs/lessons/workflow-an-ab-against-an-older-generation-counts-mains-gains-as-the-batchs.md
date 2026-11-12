# Workflow: An A/B against a generation older than the main the branch merged counts main's gains as the batch's

**Date**: 2026-11-12
**Status** (2026-11-12, lane v8up b7): the same holds for a PERF pair, in the other direction. The pair's frozen baseline was round 6's console (main 253917157d7); the tip had merged main fd0567b64ed, which other lanes had made lighter. Against the frozen console the port's memory read 1.0337 of main (30 rows over the 3% bar); against a console built from the merged main, the same day and host, 1.0596 (34 rows) - main's gains had been counted as the port's. Build main-now's console (ten minutes) and report both columns whenever the frozen pin is older than the merged main.
**Lesson**: When the A/B baseline is a generation swept before the main your branch has since merged, the raw difference is main's progress plus the batch's. Attribute before reporting: diff your tip's journal against a main-now sweep of the same day, host and configuration, and report both numbers.

**Why**: A lane merges current main before its gate, and the frozen baseline is the last published generation. Between the two, other lanes merged. Every file they fixed shows as CHANGED in the lane's A/B, and its losses hide among them. The headline (+329 here) says nothing about the batch.

**What Happened**: Lane v8up b6c's FULL A/B ran against generation 217 (main 9a7434fdee9) with a tip that had merged main 19c98ff4fbd: 1,891,436 -> 1,891,765, 70 files changed, blocking 463 -> 426. Two hours earlier three other lanes had reported +220 to +252 against the same baseline for batches that changed almost nothing by themselves. Another lane's window of the same afternoon had left its tip journal on the host (main 06816236719 plus an engine-internal cache: a main-now sweep in all but name, 13,141 files, production runner, fresh serve). The comparison script run with that journal as the base took seconds and no runner: +77 subtests over the common files, blocking 429 -> 421, 25 files changed, the same two losses - the port's own effect, matching what the port measured alone a day earlier (+73).

**Fix**:
1. Run the comparison twice: against the frozen generation (the gate's number) and against today's main-now journal on the same host (`abcmp.py <main-now journal> <tip journal>`): the integrator's post-merge sweep, or another lane's tip journal when its batch changes no behaviour - say which, and what that lane changed.
2. Report both, and list the losses from the main-now comparison with their causes; a loss present in both is the batch's.
3. Files in your list but not in main-now's (worklist changes since the generation) are reported apart: they inflate the blocking count on one side only.
4. Where no same-day journal exists, ask the integrator for main-now attribution pairs (main's current runner against the tip on the changed files), as lane nd2 b5 did.

**Takeaway**: **State which main the baseline is and which main the tip merged. If they differ, the A/B's difference is not the batch's until a main-now comparison says so.**
