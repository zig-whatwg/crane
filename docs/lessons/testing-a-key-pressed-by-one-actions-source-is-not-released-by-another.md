# Testing: A key pressed by one Actions source is not released by another

**Date**: 2026-10-16
**Lesson**: testdriver-actions.js names each new `test_driver.Actions()` input source afresh, so a `keyUp` sent from a second `Actions()` finds nothing pressed and, per WebDriver, dispatches no keyup.

**Why**: WebDriver keeps input state per source id ("If the source's pressed item does not contain key, return"), and testdriver-actions.js draws unnamed source ids from a global counter. Crane's driver (tests/wpt_runner/test_driver.zig) follows the spec, as browsers' WebDriver does.

**What Happened**: A Crane test held Space with `new test_driver.Actions().keyDown(...)` and released it with another `new test_driver.Actions().keyUp(...)`; the button stayed :active. The keyup was never dispatched - not a matching bug. Upstream tests that release that way (the-button-element/active-onblur.html) end the state some other way first (Tab), so they do not depend on the keyup.

**Fix**: Name the source and reuse it: `new test_driver.Actions().addKeyboard("k").keyDown(key, "k")`, later `new test_driver.Actions().addKeyboard("k").keyUp(key, "k")`.

**Takeaway**: **Press and release a key from the same named source; an unnamed Actions() never releases what another pressed.**
