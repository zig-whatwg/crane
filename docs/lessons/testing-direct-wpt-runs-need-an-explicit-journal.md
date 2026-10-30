# Testing: Direct WPT Runs Need an Explicit Journal

**Date**: 2026-10-28
**Lesson**: An in-process WPT runner needs an explicit `--journal` argument and an existing parent directory; `--output` alone does not enable its journal.

**Why**: `tests/wpt_runner/options.zig` `journalPath()` returns the explicit journal path, otherwise creates one only when a baseline is requested. `main.zig` then opens that file; it does not create the requested parent directory at that point. Supervisor and direct-process runs have different capture paths.

**What Happened**: The liaison's 2026-10-28 note brought row 125's Q84/Q85 and row 126's Q63 capture failures to row 128 before its planned Q136 leak runs. The prepared direct-run command supplied only `--output`. Reading both functions confirmed the missing journal request. The command was corrected before any of those leak observations ran; no successful execution is claimed by this preparation.

**Fix**: Create a fresh owned output directory before invoking the detector. Pass both `--output=<directory>` and `--journal=<directory>/journal.jsonl` to the direct runner. Dry-run every expanded path and argument before using the final command. Keep the leak target in-process: adding a supervisor to obtain a journal changes which process the detector observes. Preserve detector and pipeline exits separately from the journal's actual harness results.

**Takeaway**: **Select the execution mode and request its evidence separately: an output directory does not imply a journal.**
