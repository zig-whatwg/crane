# Workflow: A capped subtest diff undercounts a lane-only diff

**Date**: 2026-11-21
**Lesson**: The lanes' `subdiff.py` (copied lane to lane: blk6, maj6, pscan1, blk7, flk3) prints at most 400 GAINED lines unless it is given `--full`, and its totals line still counts them all. A lane-only diff built from its lines - the tip's GAINED lines minus those of the merges since the base - silently loses whatever fell past line 400, and the lost gains look like another lane's.

**Why**: The cap was meant for reading output in a terminal. Once a lane merges main after the base generation, the tip's diff against that generation carries every merged lane's gains as well as its own, and passes 400 lines easily. The gains past the cap are absent from the GAINED list, while the header ("GAINED 432") still counts them. So a lane-only count derived from the list comes out short, and the difference reads as "others removed".

**What Happened**: Lane maj6's FULL A/B at 4751d3b5e14 (after merging edit3, blk6 and dnd1) printed "GAINED 432". The lane-only count fell from 106 to 91. Fifteen of maj6's own gains (ReadableStream.from, SVG importmap, filter addition, scroll-behavior) appeared in neither the lane's list nor any other lane's diff, although the tip passed every one of them. Re-run with `--full`, the lane-only count was 106 again, the same list as before the merges.

**Fix**: Always pass `--full` when a diff's lines feed another computation (a lane-only diff, a loss list). Check that the number of GAINED lines equals the header's count before subtracting anything.

**Takeaway**: **A diff tool's printed list is not its count: run subdiff with --full whenever its lines are input, and check the line count against the header.**
