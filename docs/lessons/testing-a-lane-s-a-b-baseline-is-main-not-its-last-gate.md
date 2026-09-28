# Testing: A lane's A/B baseline is main, not its own last gate

**Date**: 2026-09-27
**Lesson**: Measure a lane's batch against the main it will merge into; an A/B against the lane's own earlier gate hides every regression that landed before that gate.

**Why**: A long-running lane gates in increments and compares each gate with the previous one. That chain shows what each increment changed, but a status change introduced before the first compared gate - or in a gate that was compared only against another lane commit - never appears in any of the A/Bs. The 0.1 measure counts a TIMEOUT as blocking and an immediate failure as not, so a change that makes a test get further and then hang is a regression on the headline even when no subtest was lost.

**What Happened**: The navigation batch (merged 505cfb9e3) reported blocking 339 -> 336 over 1,755 files, measured against gate2's tip (94bf8a53d), a lane commit. The next full sweep at 505cfb9e3 showed blocking 380 -> 465: 89 navigation-api/ files had gone from OK with 0 passed and 1 failed in under a second (the navigation API was missing, so each test failed at once) to TIMEOUT with 0 subtests, because the navigation API now existed but its navigate events or promises never settled. gate2 already had the change, so no A/B in the lane could see it.

**Fix**: A lane's batch report carries an A/B against the merge base with main (or main itself after merging main into the lane), over the lane's areas, alongside any gate-to-gate comparisons. The integrator's full sweep after a merge is the backstop, not the check.

**Takeaway**: **Compare a batch with the main it merges into; a chain of gate-to-gate A/Bs can be all green while the batch as a whole moved dozens of files to blocking.**
