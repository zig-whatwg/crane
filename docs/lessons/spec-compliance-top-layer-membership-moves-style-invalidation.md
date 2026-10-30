# Spec Compliance: Top-layer membership changes cached ancestor styles

**Date**: 2026-10-27
**Lesson**: An unchanged focused, hovered or active element does not imply unchanged selector matching on its ancestors.

**Why**: Selectors 4's user-action and focus-within chains stop at an inclusive top-layer boundary. Showing a popover can introduce that boundary without changing the designated element or a DOM attribute. A cache key containing only those element identities cannot see the change.

**What Happened**: After repairing the popover ancestor cutoff, a native Browser test kept the same input focused across showPopover(). The ancestor correctly stopped matching :focus-within, but getComputedStyle still returned its cached green color instead of red. Modal dialogs had a separate predicate gap: the old top-layer showing() helper finds popovers only. Modal cache tests are preservation checks as well, because dialog opening and closing also mutate the open attribute.

**Fix**: Keep an entry revision on the Document-owned top-layer State and pull it during style reads, beside the existing environment revision. Store the last observed revision in StyleEngine.Rare so documents without top-layer activity keep the existing embedded size. Centralize revision changes where entries are inserted, promoted or removed, including cleanup; callers do not push style invalidation. The existing generation invalidates cached styles only when the observed revision changes.

**Verification**: The unchanged 15-case native fixture passes after the pulled-revision change. It checks cached ancestor colours across popover and modal transitions, independent hide/close cases, unchanged-cache preservation, revision wrap and cleanup, and allocation failure in the lazy observer. Its earlier run had seven passes and eight failures. One active hide-only case had failed while setting up its opened cache, so that earlier run did not establish a hide-phase failure for that case.

**Takeaway**: **Test the cached style as well as matches(), and measure removal independently so an opening failure cannot hide it.** Pin unchanged-revision cache preservation too. Avoid a new generation write in every popover/dialog/picker caller.
