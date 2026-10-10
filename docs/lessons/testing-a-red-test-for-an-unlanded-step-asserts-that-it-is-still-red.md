# Testing: A red test for a step that has not landed asserts that it is still red

**Date**: 2026-10-09
**Lesson**: A test that pins what a later migration step must achieve is red until the step lands, and `zig build test` must stay green on main in between: assert the property through `knownRed(step_landed, holds, what)`, which expects the property to be absent until its flag is flipped, fails when it turns green unannounced, and requires it once the flag is true.

**Why**: A red test committed as plain red breaks the gate for every lane until the step lands; a test left out, or skipped, is never seen go red, and "a red test you have never seen go red is not a test" (docs/lessons/testing-only-tests-codegen-test-zig-runs.md). A relative bound against a control has the opposite trap: the control may retain the same thing (docs/lessons/testing-a-retention-bound-relative-to-a-control-needs-a-control-that-retains-nothing.md).

**What Happened**: Lane rc12 (step 1 of the reference-counting migration) needed tests for retention nothing frees yet (1,000 innerHTML rounds keep 45,000 instances), and for listener cycles. tests/html/refcount_probe.zig holds the `migrated` flags and `knownRed`; each test prints the measured red value and passes while it is red. The lane that lands step 7 or 8 flips the flag in the same commit, and the property is then required.

**Fix**:
1. Write the property as an ordinary assertion over a measured number, with an absolute bound.
2. Wrap its verdict in `knownRed(migrated.<step>, holds, "what")`.
3. Print the measured value, so the red result is recorded by running the test.
4. Run it once with the flag forced true to see it fail for the reason you expect.

**Takeaway**: **A red test is merged as "red, and says so": it fails the day its step makes it green without the flag, so the flag is flipped in the commit that earns it.**
