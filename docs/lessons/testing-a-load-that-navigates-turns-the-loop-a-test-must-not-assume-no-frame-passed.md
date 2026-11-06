# Testing: A load that navigates turns the event loop - a test must not assume no rendering opportunity passed

**Date**: 2026-11-06
**Lesson**: Two rendering tests put an autofocus candidate in the markup they loaded and expected it still pending afterwards. Since an embedder's load became an HTML navigation that turns the event loop until it settles, a 16 ms frame could pass during the load and flush the candidate. One test went FLAKY on a host running three builds at once.

**Why**: The old embedder load parsed synchronously, with no turn of the loop, so nothing time-driven could happen between the markup and the test's next line. A navigation runs tasks, timers and rendering opportunities, as a browser's does. Each rendering opportunity is one frame of the frame clock. How many frames pass depends on how long the load takes, and on a loaded host that varies.

**What Happened**: "reactivation restores pending native autofocus rendering without an idle timer" failed once ("expected 1, found 0": the reactivated window had no pending request) and passed twice alone (the launcher's FLAKY verdict). Its sibling test had the same dependence. Both came from lane rendering1, written against the synchronous load; lane loadpath1's load path exposed them.

**Fix**: Load a page without the candidate, then insert it with runScript, which runs no turn of the loop, so it is pending exactly when the test needs it (src/browser/rendering.zig, 13ab169699b).

**Takeaway**: **After a load that navigates, any state a frame, a timer or a task can change may already have changed: create what the test needs to be pending after the load returns, from a step that does not turn the loop.**
