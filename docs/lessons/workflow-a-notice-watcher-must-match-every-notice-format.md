# Workflow: A notice watcher must match every notice format, and only notices

**Date**: 2026-10-26
**Lesson**: A STOP watcher keyed on the words "CLOSING NOTICE" fires on any line that mentions a notice, and one keyed on a single line shape misses notices written in another shape. Match the real notice shapes, and check the pattern against the file's history before arming it.

**Why**: Lanes arm a local watcher that sets their STOP file when a new closing notice appears in tmp/plans/held-files.md (docs/lessons/workflow-a-lane-inside-a-long-command-cannot-see-a-closing-notice.md). The liaison writes notices in two shapes: `- (<time> UTC, liaison, rule 16): CLOSING NOTICE - ...` and a line that BEGINS `CLOSING NOTICE (<time> UTC, ...)`. Other lines mention the words as well: "re-read this file for a CLOSING NOTICE before every chat job", or a liaison note that a row "checks for a CLOSING NOTICE at every chunk boundary".

**What Happened**: On 2026-10-26, lane vars1b2's first watcher counted lines containing "CLOSING NOTICE". At 02:12 a liaison note mentioning the words fired it, which stopped a gate chain for nothing. Its second watcher matched only `): CLOSING NOTICE -`. The real notice at 06:20 began with `CLOSING NOTICE (`, so the watcher missed it, and the integrator had to tell the lane. Nothing of the lane was running at the time, so no timed series was spoiled.

**Fix**:
1. Match both shapes, and nothing else: `grep -cE '^CLOSING NOTICE|\): CLOSING NOTICE -'`.
2. Before arming the watcher, run its pattern over the whole file and read what it matches. Every match must be a real notice, and every real notice must match.
3. When the watcher fires, it also writes the lane's STOP file on chat, so that a remote driver checking that file stops at its next chunk.

**Takeaway**: **Key a watcher on the notice's exact shapes, every one of them, and test the pattern against the file's history before trusting it.**
