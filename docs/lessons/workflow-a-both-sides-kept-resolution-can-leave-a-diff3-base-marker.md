# Workflow: A "both sides kept" resolution can leave a diff3 base marker behind

**Date**: 2026-11-22
**Lesson**: Resolving a conflict by keeping both sides of an append-only file is not done when the `<<<<<<<`, `=======` and `>>>>>>>` lines are gone: with `merge.conflictStyle = diff3` (or zdiff3) there is a fourth marker, `||||||| <base>`, and it is easy to leave.

**What Happened**: the integrator merged lane blk7 into main on 2026-11-21 with a conflict in `tools/wpt_gate_exemptions.txt` (append-only; both lanes added entries) and kept both sides. The `||||||| 0abf07edc` base line survived at line 2253. Nothing built from that file, so every gate stayed green, and cdp/main inherited it. The test pass's WPT lane (tpw) found it only because `wpt_progress.py` refuses the whole file ("line 2253: expected key = value") - generation 236's publish would have failed at the last step.

**Fix**: after any hand resolution, grep the resolved files for all four markers before committing - `grep -nE '^(<<<<<<<|\|\|\|\|\|\|\||=======|>>>>>>>)( |$)' <file>` - and for a data file a tool reads (exemptions, dispositions, baselines, worklists), run that tool's own parser on it in the same step (`wpt_progress.py --self-test`, the lint's check).

**Takeaway**: **Check for the diff3 base marker (`|||||||`) too, and parse a resolved data file with the tool that reads it - a green build never reads it.**
