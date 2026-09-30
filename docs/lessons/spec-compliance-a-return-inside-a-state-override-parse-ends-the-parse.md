# Spec Compliance: A "return" inside a state-override parse ends the parse

**Date**: 2026-09-30
**Lesson**: The URL parser's scheme state has four state-override cases that "return" - leave the URL as it was, with no failure. Crane's `schemeState` returned from the step but not from the parse: the loop went on to the end of input, still in the scheme state, and reported failure there.

**Why**: The spec's "return" in a state step ends the whole basic URL parser. A step function inside a loop ends only itself; the loop needs to be told (`ctx.state_override_complete`), which the step's other exit (the successful scheme change) already did.

**What Happened**: The URL API's protocol setter ignores failure, so nothing looked wrong for years. Location's protocol setter throws a SyntaxError on failure, so `location.protocol = "x"` (or data, file, http+x) on an http frame threw where browsers do nothing - location-protocol-setter-non-broken failed four HTTP-frame cases.

**Fix**: `overrideReturn` sets `state_override_complete` for each of step 2.1's four returns; tests/url/scheme_state_override_test.zig pins each case as "no failure, scheme unchanged" (red before the fix).

**Takeaway**: **In a parser that runs spec steps inside a loop, every spec "return" must stop the loop. Test override cases for "no failure", not only for the resulting URL - a caller that ignores failure hides the bug.**
