# Testing: A Crane test red on both sides of every window is a bug with an owner

**Date**: 2026-11-19
**Lesson**: An A/B reads "fails identically on base and tip" as "not this lane's", so a Crane test that is red everywhere is never anyone's: give it an owner the first window it shows, and expect the test itself to be the bug more often than the engine.

**Why**: A Crane test pins what was true when it was written. A later, correct change to the engine - a property the platform now supports, an interface now gated as its IDL says - turns it red on every runner at once, so every lane's window lists it as pre-existing and moves on.

**What Happened**: Lane bugs2 (2026-11-19) took the four such files the windows had listed for days:
- crane/bx1-overflow.html expected the last standard computed name to be "z-index". cssprop1 b1 (5c29b3434ee, 2026-11-11) added `zoom` (CSS Viewport 1), which sorts after it; Chrome 157, Firefox 159 and Safari 27 all end with "y", "z-index", "zoom" (probe). Red on both sides of vm1, gcp1, rc7b, blk1 and csp1's windows - a brief later called it "since some merge after generation 228".
- crane/r3-removed-frame-retained-values-do-not-keep-it.html constructed CookieChangeEvent, which is [SecureContext] (Cookie Store API IDL), on a plain-http page: "not a constructor" once Crane gated it as the IDL says. The file is now .https.html.
- crane/ev2-touch-targets-held.html (an edit merged with rc7b) read `event.touches[0].target` after the dispatch; Crane's Touch answers the retargeted target only while an event that lists it is being dispatched, so it read the touch's own target in the other document. The host is now taken inside the dispatch.
- crane/rc-self-capturing-listener-collected.html is red by design until refcount step 8 (decision D7) - the one of the four that is the engine's, and now its own lane (rc8).

**Fix**: For each, read the failing assertion against what the browsers do (a probe, the IDL) before touching the engine; fix the test when the engine is right, and name the lane when it is not.

**Takeaway**: **"Same on base" is a reason to look, not to skip: the first window that lists a Crane test red on both sides files it with an owner, and the first question is whether the test's expectation is still true.**

**Status (2026-11-24, lane bind1)**: It recurred, and the window's own summary hid it. crane/san-options-trusted-types.html failed 3 of 3 on main (d00fea56c; since when was not traced): written 2026-10-16 for the model where the default policy's createHTML was the only callback, overtaken by the Trusted Types spec cached on 2026-11-18 (TrustedHTMLParserOptions: a default policy with no createParserOptions and options that need vetting is a TypeError, in Chrome 157 and in Crane alike). An A/B summary prints pass totals and what DIFFERS, so a file red on both sides prints nothing; it showed only because the verify step's tally lists the subtests that fail in every run. Three additions to the fix: read that tally's "failed in some run" list in every window with a verify step (10/10 is a stable failure, not noise); when a spec refresh changes an algorithm, run the Crane tests of that area on the refreshed tree before the refresh lane reports; and quote the base runner's own result for the file - "no difference" is an inference.
