# Testing: A gate on unchanged sources answers from the cache, not from new test data

**Date**: 2026-11-14
**Lesson**: When only data files that tests open at run time changed, as in a WPT update, `zig build test` replays its cached results and proves nothing about the new data.

**Why**: Zig's build cache keys a test run on its inputs: the compiled binary and the run step's arguments. A file that a test opens with `readFileAlloc` at run time is not an input, unlike `@embedFile`, which the cache does track. A tree whose sources equal the previous gate's therefore gets back the previous results.

**What Happened**: In the WPT update's cutover (lane wptup1, step 10), the post-merge gate on main 9a0207b5b4e finished in one minute: "611/611 steps succeeded; 110/110 tests passed", every step from the cache. The sources equalled generation 223's, apart from the worklist and the progress tools. But 20 test files read `tests/wpt` at run time, and those had just moved by 1,856 upstream commits:
- tests/platform's image and font decoding tests (font_adapters, font_decoding*, font_faces, fx1_image_mime_support, image_decoding*, protocol_conformance, pv1_images);
- tests/mimesniff's parsing_corpus and media_vectors;
- tests/html's fm1_font_validation;
- tests/v8's urlpattern_corpus;
- the WPT runner's own manifest, selection, test_parser and wpt_server tests.

**Fix**:
1. Find the run-time readers. Grep for `wpt/` string literals that are not `@embedFile` in tests/, tools/ and src/: `readFileAlloc`, `loadManifest(..., "tests/wpt")`, `WptServer.init(..., "tests/wpt")`.
2. Re-run their suites uncached, in the same build configuration as the gate, so the binaries still come from the cache. `-Dlaunch-seed=random` makes the test launcher re-run every test ("fresh every run, never cached"):
   `zig build test -Dspec=platform -Dtest-binaries=v8 -Dlaunch-seed=random -j2`
   and the same for `mimesniff`, `html`, `v8` and `wpt_runner`.
3. In the update, all five passed with 0 failures (2,136, 1,609, 4,233, 3,468 and 1,538 tests).

**Takeaway**: **A green gate on unchanged sources is a cache replay. When the data a test reads changes, force the run with `-Dlaunch-seed=random` for the suites that read it.**
