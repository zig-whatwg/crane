# Testing: A test green before the change pins it only once you have seen it red without the mechanism

**Date**: 2026-10-02
**Lesson**: The B0 test "a page on a fresh thread fetches before any AbortSignal exists, navigates before any navigation object, and runs a frame's setTimeout" passed on main, although the brief expected it red: threadlocal hooks were null on a new thread, but each thread's first owner installed them again, and every consumer that could run before an owner made a throwaway owner to install the hook.

**Why**: Lazily installed hooks make a fresh thread behave like a fresh process, and the workarounds (an iframe element made and dropped by an anchor's activation, `window.open`, Navigation's entry, destination, transition and controller installers, PageSwapEvent, AbortSignal for `createDependent`) existed precisely to make consumer-before-owner pages pass. The behaviour was right; the mechanism was the problem.

**What Happened**: The test was committed green as a pin. The workarounds were deleted and hooks moved to `crane.Process` start-up in one change, and the test stayed green. Commenting out Process's `installHooks()` call alone turned it, and two other test-browser tests, red (7/10), which is what proves the eager install, not the workarounds, now carries the behaviour.

**Fix**: When the change replaces a mechanism that already produces the right result, write the test against the behaviour, then show it red by removing the NEW mechanism (or by deleting the old workaround before adding the replacement), and record that run.

**Takeaway**: **A test that was never red proves nothing about the code it is meant to protect; when the behaviour already works, take the new mechanism away once and watch it fail.**
