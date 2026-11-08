# Spec Compliance: An all-browsers failure can be the test driver's own algorithm

**Date**: 2026-11-07
**Lesson**: When Chrome, Firefox and Safari all fail a WPT file with Crane's exact message, check whether the failing step goes through test_driver: WebDriver's own algorithm for that action may never run the HTML steps the test waits for.

**Why**: test_driver.click(element) is WebDriver Element Click, and for an `<option>` WebDriver 12.5.1 step 8 does not click it: it fires mouseover, mousemove and mousedown at the option's container (the select), sets the option's selectedness itself, fires input and change, then mouseup and click at the select. HTML's "pick an option" - which hides a base-appearance select's picker - never runs.

**What Happened**: Lane forms1 (batch 1) found select-pick-option-dirtiness.html and select-picker-hover-after-picking.html blocking with "Select should be closed after picking an option" (assert_false: expected false got true). The wpt.fyi stable runs (Chrome 157, Firefox 159.0.1, Safari 27.2) fail both with the same message, or earlier. Crane's runner implements step 8 to the letter (tests/wpt_runner/test_driver.zig clickOption), so the picker stays open as in every browser; the upstream WebDriver text is unchanged (w3c.github.io/webdriver, 2026-11-07). Making the runner click the option instead would be an invented path that no browser takes.

**Fix**: Report such files to the integrator as "all three fail at the same step, by the driver's algorithm", with the WebDriver step and each browser's message, for the gate-exemption review - not as a Crane bug.

**Takeaway**: **Before fixing an assertion every browser fails, read the test_driver step that leads to it: if WebDriver's algorithm skips the HTML steps the test expects, Crane already matches all three browsers.**
