# Spec Compliance: Shadow focus sorts each navigation scope

**Date**: 2026-10-27
**Lesson**: Tab order sorts within each focus navigation owner's scope before flattening the scopes.

**Why**: A document-wide list of focusable descendants loses the ownership relationships between a host, its shadow root, slots and their assigned or fallback contents. Sorting that list by tabindex cannot reconstruct the required order.

**What Happened**: The old sequential search skipped shadow descendants and imposed fixed bounds on positive-tabindex entries and the overall list. Native regressions showed Tab jumping from the host straight to the following input, failing to advance between focused descendants of a negative-tabindex host, and failing at the fixed list limit. The WPT shadow, slot fallback and click cases independently reproduced the gaps.

**Fix**: Follow HTML 6.6's associated focus navigation owner and flattening algorithms. Search a single owner's tabindex order, enter the selected owner's scope, then resume in its owner's scope on exhaustion. Assigned slot contents and fallback contents use the same scope boundary. A default box-less slot is an owner, not a focus stop; a styled slot that generates a box may be both. An excluded negative host prevents entry from outside but must not trap script-focused descendants inside it. Showing-popover sources are owners too, including when their scope is outside their own ordinary subtree.

The design reference is Chromium's `FocusNavigation`, `ScopedFocusNavigation`, `FindOwner` and cross-scope ascent in [`focus_controller.cc` at 8d5ba1795f0c50b90072399d0403389df6eebbd6](https://github.com/chromium/chromium/blob/8d5ba1795f0c50b90072399d0403389df6eebbd6/third_party/blink/renderer/core/page/focus_controller.cc). No implementation code was copied.

**Takeaway**: **Sort scopes first, then flatten. Keep the navigation scope distinct from both ordinary DOM ancestry and focusability.** A radio-group cache also needs its ordinary tree boundary; a document-only cache cannot answer shadow-tree eligibility.
