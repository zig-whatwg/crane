# Spec Compliance: A tick added to match ordering tests goes stale when the spec moves

**Date**: 2026-10-04
**Lesson**: The navigation API delivered "wait for all"'s outcome one microtask after the reaction that decided it, "as browsers wait", and ran the navigate event's handlers from "commit a navigate event" - both matching an older text. The current HTML runs the handlers from "update the navigation API entries for a same-document navigation" (step 14) and WebIDL's wait for all performs its steps in the reaction itself; twelve ordering-and-transition files failed on exactly that tick.

**Why**: A deviation that exists to satisfy tests is a claim about the spec and the tests at one moment. The navigation API's algorithms were reworked (precommit handlers, the intercept commit handler steps), the WPT ordering tests were updated with them, and the extra tick - right for the old ordering - put navigatesuccess after "committed fulfilled" and after the test's own "promise microtask".

**What Happened**: navigation batch 6's probe grouped 12 blocking files under "expected navigatesuccess but got committed fulfilled / promise microtask". Reading the cached (2026-10-02) spec showed the step-14 structure and a wait for all with no tick; the file comment still said "the December 2025 text returns there and never settles".

**Fix**: f78f492903 - interceptCommitHandlerSteps runs from sameDocumentNavigation after currententrychange and dispose (for the ongoing navigate event that committed an interception, or an uninterrupted same-document one), Wait.decide delivers in the reaction, the obsolete deviations are gone from the file comment. 12 files unblocked, 0 regressions in the 938-file probe.

**Takeaway**: **When ordering tests fail against a stated deviation, re-read the current spec text before tuning the deviation: the deviation may be what is now wrong.**
