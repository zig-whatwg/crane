# Architecture: A value every run renews must not reach every page

**Date**: 2026-11-07
**Lesson**: Keeping results out of the shared frame is not enough: a value inside each page's own content that every run renews - the run that recorded the file's result - rewrites every page on every sweep, even when no result moved.

**Why**: The results site regenerates from a full sweep each generation, and a sweep is a new run with a new label (`sweep-<sha>`), date and commit. Each test file's page named "Run: sweep-<sha>, <date>, Crane <sha>", so every file's page changed with every sweep. The frame rule (the rail carries no results) held; this value was per page, so the review that wrote that rule did not look for it.

**What Happened**: Generation 207's gh-pages commit (44c3f185788) changed 13,206 files when about 50 files' results had moved: the diff of an unchanged file's page was one line, the Run row. With ~14,000 files per push, GitHub Pages' deploy step ("syncing_files") hit its 10-minute limit three times in four attempts, and the user had the site restructured (lane site1): test files became sections of their directory's page, so the same leak would have rewritten all ~1,100 directory pages instead.

**Fix**:
1. Name the run only where it says something the page's own data does not: the generation's main run (the one holding the most files) is named once, on the index; a file's section names its run only when it came from another one (`pages.mainRun`, `writeFileSection`).
2. Test the property, not the frame: render twice with a new generation AND a new sweep run whose results are the same for one directory, and require that directory's page to be byte-identical while a directory whose result moved changes (tools/wpt_site/generate.zig, "byte-identical across a new generation and a new sweep").
3. Measure a real publish: count the files a one-change regeneration rewrites; it should be the changed directory, its ancestors and the summary pages.

**Takeaway**: **Anything a run renews - its label, date, commit - belongs on the one page that describes runs; a page whose results did not move must render the same bytes from a new run.**
