# Workflow: A branch's WPT run replaces main's in the progress report

**Date**: 2026-10-04
**Lesson**: The progress report keeps the newest result per file across every journal one directory under `wpt-results/`, so a lane's run there - of a branch, not of main - becomes "the latest result" for every file it covers, and a full lane A/B becomes a whole generation of someone else's tree.

**Why**: `tools/wpt_progress.py` orders journals by mtime and lets a newer record supersede an older one; it has no idea which commit's tree a journal measured relative to main. AGENTS.md told every feature commit's runs to go there, written when lanes merged to main at once; with lanes on long-lived branches, a lane's run measures a tree main never had.

**What Happened**: Main's round-5 sweep (2794798eb5, 19:00) made generation 108: 1,484,662 passing. The bclife lane's FULL A/B of its pre-merge tip 8a9cf2d4c8 - based on 70f48f5704, before the serializable and IndexedDB merges - was written to `wpt-results/ab-8a9cf2d4c8/` at 19:21. The next regeneration recorded generation 109 at 8a9cf2d4c8 with 1,459,676 passing: every file's result replaced by the lane's, the IndexedDB and WebCrypto gains gone. It was caught before gh-pages was pushed.

**Fix**:
1. Moved the journal to `wpt-results/lanes/ab-8a9cf2d4c8/` (two levels deep: the report reads one).
2. Rebuilt `tmp/wpt-progress-state.json` from the journals present (delete it; `load_results` replays them), checked the rebuilt sums equal generation 108's exactly, dropped generation 109 from `progress-history.json`, and recomputed its `last_statuses`/`last_sources` from the rebuilt records with the report's own functions - otherwise the next run diffs against generation 109 and records a phantom generation.
3. Reset the unpushed gh-pages commit and regenerated: generation 108 again, unchanged.
4. AGENTS.md: only main's runs go where the report reads; a lane's go to `wpt-results/lanes/<label>/`.

**Takeaway**: **The report's "latest result" is the newest journal, whatever tree it measured - only main's runs may feed it; a branch's run goes under `wpt-results/lanes/`.**
