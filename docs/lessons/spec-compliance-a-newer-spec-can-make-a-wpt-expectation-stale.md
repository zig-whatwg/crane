# Spec Compliance: A newer spec can make a WPT expectation stale

**Date**: 2026-10-17
**Lesson**: Before changing behavior to satisfy WPT, establish which side of the spec change the test and each browser implement.

**Why**: A failing assertion does not establish that the implementation is older than the specification. Tests, stable browsers and the current specification can reflect different revisions.

**What Happened**: The invoker-command worklist included 19 failures in `button-event-dispatch.html` and one in `event-dispatch-shadow.html` because the tests expected `CommandEvent.composed` to be true. Crane produced false. Aligned stable results at WPT revision `df642c4142354ffb5a0af6fa41610677f6321092` showed Chrome passing those expectations while Firefox and Safari failed the same cases. That split alone did not explain which behavior to implement.

**Fix**: Read the complete button activation algorithm and its history. [WHATWG HTML PR 11255](https://github.com/whatwg/html/pull/11255), merged on 2025-08-15 as `787316d519f826f38ac4acc260e051a5fedc1031`, explicitly made command events non-composed and recorded support from all three engine teams. The current activation step 5.3 initializes `cancelable`, leaving `composed` at its false default. Preserve that behavior, pin it in `crane/cmd-command-scoped-event.html`, and report the stale expectations separately from actual implementation gaps. WebKit's `HTMLButtonElement::handleCommand` also initializes the event with `{ false, true, false }`.

**Takeaway**: **Trace the direction of a standards change before interpreting browser pass counts or changing code to satisfy a test.**
