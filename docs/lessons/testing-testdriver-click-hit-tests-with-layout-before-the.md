# Testing: testdriver's click hit-tests with layout before the vendor ever sees it

**Date**: 2026-09-30
**Lesson**: A vendor file can only automate what testdriver.js passes through to it. Upstream `test_driver.click` hit-tests the element with `getClientRects()` and `elementsFromPoint()`, and rejects with "element click intercepted error" before it calls `test_driver_internal.click`. An engine with no layout has to replace `test_driver.click` itself.

**Why**: `test_driver.click` runs WebDriver's "in view" and "obscured" checks in page script. It takes the centre of the element's first client rect and asks `document.elementsFromPoint` for it. The element has no box, so `getClientRects()` is empty, the paint tree is empty, and the promise rejects. The vendor's `test_driver_internal.click` is never called.

**What Happened**: 13 of the testdriver lane's 37 blocking files failed at once with "Unhandled rejection: element click intercepted error". Those include every replace-before-load user-click file, the navigation-api userInitiated files and pageswap-push-from-click. `send_keys` and `action_sequence` were unaffected: `send_keys` only calls `scrollIntoView` when the element is not in view, and actions have no hit test at all.

**Fix**: Crane's vendor file (tests/wpt_runner/resources/testdriver-vendor.js) sets `test_driver.click = element => test_driver_internal.click(element)`. Its native, the runner's WebDriver remote end (tests/wpt_runner/test_driver.zig), does Element Click's own checks without layout: stale if not connected, and invalid argument for a file input. A connected element counts as in view and unobscured. The file's header states the deviation.

**Takeaway**: **Read what the upstream helper does before the vendor hook it calls: a check it makes in page script is one the vendor cannot reach, and without layout that check fails every time.**
