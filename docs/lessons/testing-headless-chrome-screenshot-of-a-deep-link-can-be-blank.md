# Testing: A headless Chrome `--screenshot` of a deep-linked, script-scrolled page can come back blank

**Date**: 2026-09-30
**Lesson**: `chrome --headless=new --screenshot --virtual-time-budget=N <url>#fragment` produced all-white captures of the WPT results site whenever the fragment made its script open rows and scroll. The same page without a fragment captured fine. A small Chrome DevTools Protocol driver captured every state correctly.

**Why**: the `--screenshot` flag captures on its own schedule under virtual time, with no hook for "the page has finished what the fragment asked for". A page that scrolls from script after fetching data can be caught mid-way. Even the sticky contents rail was missing, so the capture was not a real render of any state.

**What Happened**: the first review captures of deep links (`#xhr/<file>`, `#history`) were blank 1440x1000 images. Sent to a reviewer, they would have forced a `recapture` round.

**Fix**: drive Chrome over CDP from a scratch Node script. Launch `--headless=new --remote-debugging-port=<p>`, then call `Emulation.setDeviceMetricsOverride` for the viewport and `Emulation.setEmulatedMedia` for `prefers-color-scheme` and `prefers-reduced-motion`. `Page.navigate` to the URL, wait, optionally `Runtime.evaluate` an interaction, and call `Page.captureScreenshot`. For a full page, read `Page.getLayoutMetrics().cssContentSize.height` and resize the viewport to it (capped at about 16000 px). Log `Runtime.exceptionThrown` so a script error is visible, not a blank image. The driver stays in tmp/ as scratch, never in tools/.

**Takeaway**: **Open every capture before it becomes evidence. For a page that does work after load, capture over CDP at a moment you choose, not with `--screenshot`.**
