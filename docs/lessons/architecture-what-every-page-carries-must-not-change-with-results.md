# Architecture: What Every Page Carries Must Not Change With Results

**Date**: 2026-09-30
**Lesson**: On a static site committed to a branch that is never force-pushed, anything every page includes (the navigation rail) must carry no result-dependent value, or every regeneration rewrites every page.

**Why**: The results site is ~5,000 pages committed to `gh-pages` on every regeneration. Git stores each changed page again; a shared frame that prints a moving number (a pass count, a generation, a date) changes all 5,000 pages each time, so the branch grows by the whole site per generation and every diff is noise.

**What Happened**: The wptsite2 lane's first static build put per-suite pass counts in the contents rail that every directory and file page carries. A regeneration where one file changed standing rewrote every page. Moving results out of the rail - it carries file counts only, which change only when the worklist does - made a regeneration with no other change rewrite only `index.html` and the social card, and a rerun on unchanged input write nothing.

**Fix**:
1. Keep the shared frame (rail, header, footer) free of results, dates and generation numbers.
2. Put each result on the page it belongs to: a file's numbers on its page, a directory's on its page, the totals on the index.
3. Write files only when their bytes change, and prune what is no longer generated; test that a rerun writes 0 files.

**Takeaway**: **Keep results out of the shared frame; only the page a result belongs to may change.**

**Update (2026-11-07, lane site1)**: the frame was not the only way in. Each test file's page named the run that recorded its result, and every sweep is a new run, so generation 207's commit rewrote 13,206 pages for ~50 moved results. See [A value every run renews must not reach every page](architecture-a-value-every-run-renews-must-not-reach-every-page.md): name the generation's main run once, on the index, and test a new sweep with unchanged results, not only a new generation.
