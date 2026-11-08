# Workflow: A crashtest needs the manifest's type and wptrunner's own wait

**Date**: 2026-11-08
**Lesson**: WPT classifies a crashtest in MANIFEST.json (items.crashtest) and wptrunner finishes it with its own executors/test-wait.js; a runner that only knows testharness pages runs every crashtest as a TIMEOUT, so no sweep ever sees a crash in one.

**Why**: A crashtest has no harness and reports nothing: it passes when its page loads and settles without the process crashing. Run as a testharness page, it waits for a completion that never comes; a TIMEOUT hides a CRASH only when nobody reads it.

**What Happened**: Crane's runner discovered testharness files only (feature-queue 2026-10-25), so css-syntax/crashtests/unclosed-open-brackets.html (60,000 nested blocks, a stack overflow) was found only by hand (anim1 batch 5). Lane crash1 added the mode: manifest.zig reads items.crashtest (1,785 crashtests under the worklist's suites, 505 under its exact prefixes); wpt_browser.zig `runCrashtest` loads the page as WebDriver navigation does (to readiness "complete") and runs wptrunner's test-wait.js from the checkout, formatted with class "test-wait" as WebDriverCrashtestExecutor formats it, as an async script; the result is OK in the journal and PASS in the wptreport. Four crashtests went TIMEOUT x4 -> OK x4.

**Fix**: Classify by the manifest, not by file name; run the vendor's own wait script rather than a copy of its steps (fonts.ready, two animation frames, the test-wait class, TestRendered).

**Takeaway**: **Every WPT test type needs its own completion rule from wptrunner; a type the runner does not know is silently a TIMEOUT - sweep crashtests with the crashtest rule, and read their CRASH lines.**
