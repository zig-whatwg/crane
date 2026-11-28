# Spec compliance: A reference that retries every failure answers only its timeout

**Date**: 2026-11-27
**Lesson**: When the reference acts through a retry loop - Puppeteer's locator retries every error until its timeout - its user never sees the error that stopped an attempt, only the loop's timeout. A port that answers each failure at once with its own words ("Element is read-only.", "Element is disabled") differs on every one of them, and also gives up on an element that would have become usable a moment later. Read the reference's retry and timeout operators before porting its error messages.

**Why**: chrome-devtools-mcp clicks and fills through `handle.asLocator()` (puppeteer-core 25.17.0 src/api/locators/locators.ts). The locator's pipeline ends in `retry({delay: RETRY_DELAY})` raced with `timeout(this._timeout)`, so any throw inside it - the enabled wait, "Element is read-only.", "Element has no option with the value", "Element cannot be filled out." - is tried again every 100 ms until the page's default timeout (5 s times the CPU throttling rate). Then a TimeoutError reaches handleActionError, which answers "The element did not become interactive within the configured timeout." The messages inside the locator are never shown.

**What Happened**: Crane's MCP input tools (written in the Antigravity period) refused a disabled control or a read-only field at once, with messages taken from the locator's source. Lane mcp3's differential case of uncooperative elements (audit M7) showed Chrome's server waiting 5 s and answering the timeout text for both. Reading the locator showed two more differences in the same code: Puppeteer's classification fills an `<input type=button>` directly where Crane said it cannot be filled, and its enabled condition reads only the control's own `disabled` attribute (a fieldset-disabled button is clicked; HTML swallows the click).

**Fix**:
1. Port the loop, not only the messages: an attempt that answers "not yet" for what the locator would throw, retried every 100 ms until DEFAULT_TIMEOUT x the throttle rate (+10 ms a character for a fill, fillFormElements' timeoutPerChar), then the reference's timeout text (src/devtools/mcp/tools/input.zig `Locator`).
2. Keep immediate what the reference decides before the loop: chrome-devtools-mcp's own checks (an unknown combobox option name, a toggle value that is not "true"/"false") throw outside the locator and are answered at once.
3. Copy the page functions the loop runs (Apache-2.0, cited), so the classification is the reference's, and test both ends: an element that becomes usable inside the wait, and one that never does.

**Takeaway**: **Before porting a reference's error messages, find the retry and timeout around them: if every failure is retried until a timeout, the only answer the user gets is the timeout's - and the wait is behaviour too.**
