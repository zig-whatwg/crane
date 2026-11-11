# Testing: A coverage check can require the bug's own state

**Date**: 2026-11-11
**Lesson**: tests/html/iframe_policy_container_oom_test.zig's contentWindow sweep failed unless at least one round "left the frame without a Window" (`NoRoundLeftTheFrameWithoutAWindow`). That check was meant as sweep coverage: proof that the sweep reached the out-of-memory path the null fallback was for. But the state it required was the bug. A failed realm replacement released the navigable's realm while its browsing context still answered the old Window as active.

**Why**: The check was written by lane leaks5 for the null fallback in get_contentWindow. It counted the observable effect of the path (null) instead of the path itself, and the effect was a broken invariant: a navigable with no realm, and a Window whose realm might end under it. The next navigation's abort then made a DOMException in an ended realm and panicked ("a platform object made in a realm no Browser owns"). That was FAIL on chat2 and FLAKY on server1.

**What Happened**: Lane v8up b3e's fix keeps the old realm and Window on that path: the navigation fails and the old document stays. That made the old check impossible to pass.

**Fix**: The sweep counts the path itself, with `IFrameIntegration.realm_replacements_failed` (a round whose new realm could not be made), and requires at least one such round. Every round's own assertions are now stronger: the frame answers a Window, never null; script reads it with memory to spare; and the frame navigates again after the first such round and after the sweep. The RED variant replaces the counter with 0, and it fails on main's code and on the branch before the fix.

**Takeaway**: **A coverage assertion should count the path it covers, not an effect of that path. Before keeping an "at least one round reached state X" check, ask whether X is an invariant violation.**
