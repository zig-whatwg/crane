# Testing: A pin test for behaviour main already has is proven red on a never-merged diagnostic runner

**Date**: 2026-11-12
**Lesson**: When the tests come first but the behaviour they pin already passes on main, build ONE throwaway runner that re-applies the known-bad change, and show each test red there. Then delete it.

**Why**: Tests-first means seeing each test fail for the right reason before trusting it. Some tests pin readers that a FULL A/B once caught breaking. Those readers already pass on main, so no runner of main can show them red. A test never seen red may be checking nothing, for example a precondition that fails the same way on every build.

**What Happened**: Lane nav2 batch 10, the removed-frame design item. Batch 9's two reverted Window predicates had each cost a reader: the service worker frameType and an unload handler's window.parent. The design kept main's behaviour. Its three Crane tests (nav2b10-sw-frame-type-reused-window, nav2b10-removed-frame-unload-sees-parent, nav2b10-removed-frame-detached-at-once) passed on generation 217.
- One diagnostic runner was built from a detached worktree at a `wip:` commit holding batch 9's two predicates, and the integrator approved it. It cost one server1 runner build (~10 min).
- On it, each test failed with the reader's own message ("nested" expected, "top-level"; "outer pagehide: window.parent" false; the inner frame's contentWindow non-null). On generations 216 and 217 they passed, apart from the third, which 216 also failed.
- The same probe exposed a broken test. Its popup-opener case failed its precondition on every runner, because window.open()'s opener is the ENTRY global (whatwg/html#10547). The test had to open the popup from the frame's own listener.

**Fix**:
1. Make a detached worktree at main and commit the known-bad change there as `wip: RED diagnostic (never merged)`.
2. Build only the production runner on your mirror (`zig build wpt-runner snapshot`) and copy it to `<mirror>-bins/red-<sha>`.
3. Run the new tests and the upstream families on the red runner, on main's frozen runner and on the previous generation's. Quote the 3x3.
4. Delete the worktree, the red bins and the mirror's leftovers at once, and post that in held-files.

**Takeaway**: **A test that passes on every build you have has not been tested. Prove a pin test red on a deliberately broken runner, and treat a failure that is the same on every runner as a bug in the test.**
