# Workflow: Run WPT data cases natively before a runner build

**Date**: 2026-10-26
**Lesson**: A WPT suite whose cases are data (editing/data/*.js) can be run in a native test against the real engine in minutes, and joined with wpt.fyi's per-subtest results by name, to see gains, losses and the browsers' split before any runner build or A/B.

**Why**: The WPT runner is built ReleaseSafe (about 7 minutes and 14 GB per compile) and, on this Mac, only on chat.local, one job at a time inside timed windows. Iterating a 35-step algorithm against 500 innerHTML expectations through that loop costs an hour per guess. The editing suite's harness (include/tests.js) and its case files are plain JavaScript; nothing in them needs the WPT server.

**What Happened**: Lane editing4 built insertParagraph, insertLineBreak and insertHorizontalRule, then needed to know which of 825 data cases matched and which differed from the browsers. A scratch test (tests/html/editing4_probe_test.zig, never committed) embedded implementation.js, tests.js (testsJsLibraryOnly), the data files converted to JSON with node, and a copy of runConformanceTest that records innerHTML, return values and the six queries per command instead of asserting. One `zig build test -Dspec=html -Dtest-file=...` run printed every case. A Python join against the gen-185 wptreport stream and the three browsers' per-subtest JSON (storage.googleapis.com/wptd/<sha>/<run>/<test>) classified each subtest: kept, gained, LOST, or failing where at least two browsers pass. Four iterations took the three commands from 0 to +451, +184 and +114 innerHTML subtests with 0 lost, and exposed browser mechanisms the spec lacks (Enter splits inline wrappers deep and keeps their style; a link is not continued; edge spaces become no-break spaces), plus a premise error in the brief: delete's step 10 outdent does not fix join-pre-and-other-block.html - all three browsers join there instead.

**Fix**:
1. `node -e` with `new Function(src + '; return browserTests;')` turns a data file into JSON lines (strip a leading custom-element preamble).
2. Generate one JS file: the harness's helpers + the cases + a runner that returns one JSON line per case; `@embedFile` it from a scratch test in the same test directory, evaluate it in a fresh page, print between markers, fail the test so the output shows.
3. Key results by (command list JSON, input) - the subtest name's prefix - and join with the base run's report stream and wpt.fyi's per-browser JSON.
4. Delete the scratch test and generated JS before committing; the committed tests are a curated set of the browser-agreed cases.
5. Cross-test state (a variant's first case reading the previous case's defaultParagraphSeparator) differs between a whole-file probe and per-variant WPT runs: ignore those query mismatches.

**Takeaway**: **When a WPT suite is data plus a JS harness, run it in-process first: a native probe gives per-subtest gains and losses in minutes, and the runner build is only for the final A/B.**
