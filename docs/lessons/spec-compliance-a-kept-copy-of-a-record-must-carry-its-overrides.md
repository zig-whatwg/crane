# Spec Compliance: A kept copy of a timing record must carry the entry's overrides

**Date**: 2026-10-31
**Lesson**: When an entry is set up from a record and the record is kept to set the entry up again later, any override applied while making the entry must be applied to the kept copy too - or the later setup quietly undoes it, and only when the later setup happens.

**Why**: Navigation Timing's fetchStart getter returns the service worker timing's fetch event dispatch time when there is one (Navigation Timing 2, the PerformanceNavigationTiming fetchStart getter steps). Crane applied it in PerformanceNavigationTiming's creation, to a local copy of the ResourceTiming record. createNavigationTimingEntry also kept the ORIGINAL record when the response body was still arriving, and `navigationBodyEnded` set the entry up again from it to fill in the body sizes - putting fetchStart back to the fetch's post-redirect start.

**What Happened**: service-workers/service-worker/navigation-timing-extended.https.html failed 8 of 50 isolated runs on frozen main 0aa6c6c8cf: "fetchStart should be marked once the worker is activated", with fetchStart ~480 ms BEFORE the worker's activation ended - exactly the fetch's start. A diagnostic runner showed the fetch event dispatched after activation and the entry made with the right dispatch time in failing runs as in passing ones; the difference was whether the service worker's response body (a relay the worker writes) had all arrived when the document was made. Generations 171-196 had disposed of it nine times as a clock-tie flake.

**Fix**: createNavigationTimingEntry applies the override to the record before both the entry and the kept copy are made (src/dom/performance_timeline.zig); PerformanceNavigationTiming copies what it is given. tests/html/f4_navigation_timing_test.zig pins it: an entry made with its body arriving keeps the dispatch time as fetchStart after navigationBodyEnded.

**Takeaway**: **A record that is applied twice must be the same record both times: put an override where the record is made, not where it is first consumed.**
