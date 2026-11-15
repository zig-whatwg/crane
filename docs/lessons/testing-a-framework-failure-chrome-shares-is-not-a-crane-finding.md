# Testing: A framework failure Chrome shares is not a Crane finding

**Date**: 2026-11-14
**Lesson**: Run the project's own runner in a pinned Chrome on the same tree before a framework test's failure in Crane becomes an engine finding; three of jQuery's seven Crane failures fail in Chrome 157 the same way.

**Why**: A framework's suite is written against the browsers of the day it was tagged. Browsers move (HTML changed which `option`s match `:disabled`; error columns differ), and a suite's expectation tables know only the user agents it lists. A Crane failure is only a Crane finding when the browsers pass the same test on the same tree (AGENTS.md golden rule 2: the browsers decide).

**What Happened**: fw1 b2 listed seven jQuery 4.0.0 failures as Crane findings, among them "selector: pseudo - :(dis|en)abled, optgroup and option" and "core: jQuery.parseXML - error reporting" (column 10, expected 11). In b4 jQuery's own runner (`jtr -m test/middleware-mockserver.cjs -b chrome --headless`, its CI's way) ran the same tree in Chrome for Testing 157.0.8103.78: Chrome failed exactly those two with the same actual values (six matching elements for `:disabled`; column "10"), and the user-agent table test too. Only four of Crane's failures (two `fill-opacity`, focusin from an iframe, and one later shown to be layout) were Chrome passes.

**Fix**: For each framework row, keep a Chrome column from the project's own runner, pinned (Chrome for Testing version and binary sha256), on the same tree and server; compare failure by failure, actual value by actual value. A failure Chrome shares is reported as "fails in Chrome 157 too", never queued as a Crane bug; one Chrome passes is a finding with Chrome's result as its evidence.

**Takeaway**: **Before a framework failure becomes a Crane finding, run the project's own runner in a pinned Chrome on the same tree: a failure Chrome shares is the suite's, not Crane's.**
