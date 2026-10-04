# Workflow: Validate the worklist before acquiring runner tokens

**Date**: 2026-10-03
**Lesson**: Check a generated measurement list against the intended file count before launching its runner.

**Why**: A pipeline can produce an empty output file when its producer is missing. `pipefail` reports that pipeline's failure, but does not stop a surrounding script that continues with the next command.

**What Happened**: A remote IndexedDB smoke command used locally available `rg` to generate its worklist. Chat did not have `rg`. The script continued, acquired two runner tokens, discovered zero files and exited without testing anything. The intended list contained 25 files. The native red tests and subsequent browser gate were separate valid results; the empty smoke run was not one.

**Fix**: Generate this small list with standard shell globs, check that its file count equals the locally inspected selection, and stop before calling `crane-measure` if it differs. Check the discovered count and journal count afterward too. Record the zero-file attempt as invalid, never as a passing measurement.

**Takeaway**: **The input selection is part of the measurement gate. A successful runner exit cannot prove that the intended tests ran.** See also [the runner's directory allowlist lesson](testing-a-directory-argument-is-filtered-through-the.md).
