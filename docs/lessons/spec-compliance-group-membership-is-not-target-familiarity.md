# Spec Compliance: Group membership is not target familiarity

**Date**: 2026-10-17
**Lesson**: Verify every condition of a spec-named predicate before reusing it, and test a related target that must still be rejected.

**Why**: A helper's name does not establish that it implements the current algorithm. Broadening traversal can expose a shortcut that older callers never reached.

**What Happened**: Row 58 expanded named lookup from an opener tree to the Browser's related pages and their descendants. The existing `BrowsingContext.isFamiliarWith` returned true for every same-group pair. The focused same-origin and cross-group cases passed, but the matched sweep regressed `targeting-cross-origin-nested-browsing-contexts.html`: an opener found a cross-origin page's initial about:blank child instead of creating a new top-level target. Running the single upstream test on the frozen runners reproduced BASE PASS versus candidate TIMEOUT. A separate five-case Crane test identified the incorrectly accepted child while preserving positive origin, top-level, auxiliary-opener and ancestor cases.

**Fix**: Implement HTML's full familiarity algorithm for the lookup: active-document same origin, the source's top-level context, the target's auxiliary opener, and the target's same-origin ancestors. Use an existing resolved Document origin record before an inherited Window creation string; that string can be stale after navigation. Preserve opaque identity with the origin-record comparator, never origin-domain relaxation. Validate stored parent/opener edges against the existing live-context list before dereferencing them, and bound walks by that list's size rather than an arbitrary depth. Blink's `FrameTree::FindFrameForNavigationInternal` and `LocalFrame::CanNavigate` likewise check origin and relationship when choosing a named target. Leave origin creation and ownership to their owners.

**Takeaway**: **A related page's descendants are not all familiar: pair each wider search with the spec's full eligibility check and a negative case inside the same group.**
