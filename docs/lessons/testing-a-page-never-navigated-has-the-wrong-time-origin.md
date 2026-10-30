# Testing: A test page that was never navigated has the wrong time origin

**Date**: 2026-10-28
**Lesson**: A moment handed to script must be converted with the time origin its Performance has - a navigation moves it to the navigation's start - and only a navigated page shows the difference.

**Why**: HR-Time's relative high resolution time is relative to the global's time origin. Crane's Window records its creation as a stand-in, and Navigation Timing's "create the navigation timing entry" (performance_timeline.createNavigationTimingEntry) moves the Performance's origin to the navigation's start. `performance.now()` measures from the latter.

**What Happened**: Lane rendering1 converted the rAF frame instant with the Window's recorded origin (dom.global_settings `time_origin`). Its native tests (tests/html helpers.Page: about:blank, then loadHTML - no navigation timing entry) passed; in the WPT runner, whose pages are real navigations, the timestamp came out 1.3 ms AFTER performance.now() in the same callback (crane/r1-raf-refresh-grid.html), and an iframe's by 2 ms.

**Fix**: Convert through the Performance's own conversion, `dom.performance_timeline.relativeCoarseTime(realm, unsafe_ms)` (the installed relative_coarse_time hook, the one fetch timestamps use). Pin it with a native test that navigates for real (`browser.navigate("data:text/html,...")`, asserting a navigation entry exists) and checks every timestamp <= performance.now().

**Takeaway**: **Convert a moment for script through the global's Performance (performance_timeline.relativeCoarseTime), and test any time conversion on a navigated page - helpers.Page never sets the navigation start.**
