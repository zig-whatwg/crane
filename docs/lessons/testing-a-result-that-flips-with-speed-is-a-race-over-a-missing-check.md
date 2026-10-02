# Testing: A result that flips with speed is a race over a missing check

**Date**: 2026-10-02
**Lesson**: When a faster build (or a faster change) flips a group of files
between pass and fail, find what the test races. WPT's frame-ancestors tests
raced their own 10 ms poll against the frame's load event, and which one won
decided the result only because Crane never threw the SecurityError the tests
look for.

**Why**: the tests read `iframe.contentWindow.location.href` and treat a
SecurityError as "blocked (or cross-origin)". Crane's Location members had no
same-origin-domain check (each setter's comment stated the deviation), so a
cross-origin frame's URL was readable. The poll path then touched
`contentDocument` - null cross-origin - and threw; the load-event path did not.
Whatever made frame setup faster made the load event win: the ReleaseSafe
runner, and then O(1) template lookups in the Debug runner.

**What Happened**: 9 of the 10 ReleaseSafe-vs-Debug status differences on a
2,100-file parity list were these files, and the same branch's Debug runner
flipped 9-12 of them against main (main 24/34 OK in both runs, the branch 12
and 15). With the checks in (src/html/origin_domain.zig, Location.zig), the
list is identical run to run. Seven files that main passed only by winning
the race now fail with "The IFrame should have been blocked (or
cross-origin). It wasn't.": they need frame-ancestors enforcement, which
nothing calls (src/csp/directives/frame_ancestors.zig).

**Fix**: implement the check the test relies on - here the Location
members' first step - and re-run the group alternating with main until both
are stable; report the passes that were only ever race wins as such.

**Takeaway**: **A pass that depends on speed is not a pass. When a group
flips with timing, read the test for the race and the engine for the check it
is missing - and expect some old passes to become honest failures.**
