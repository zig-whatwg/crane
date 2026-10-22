# Spec Compliance: Browser failures need the exact assertion

**Date**: 2026-10-19
**Lesson**: A browser's failing file is not evidence that it agrees with a particular assertion inside that file.

**Why**: One test can check several behaviors in sequence. An aggregate PASS/FAIL count hides which step first differs, and a test's desired behavior is not itself the browser-majority rule.

**What Happened**: `dialog-focusability.html` passed in Chrome and failed in Firefox and Safari. It was tempting to implement Chrome's exclusion of a plain dialog from sequential focus while preserving editable dialogs. The detailed results showed that both failing browsers instead stopped at step 2/11: they focused the plain dialog, where the test expected its child button. Gecko's `HTMLDialogElement::TabIndexDefault()` returns 0, and WebKit's dialog `supportsFocus()` returns true. HTML PR 8199 had already been implemented by both engines and did not prescribe whether dialogs belong in sequential focus.

**Fix**: Read each browser's exact failure message and the corresponding engine method before choosing the mechanism. Under golden rule 2's no-newer-spec branch, row 85 Q12 selected the Firefox/Safari default: dialogs are focusable and sequentially focusable; explicit tabindex rules still apply. Keep the upstream test unchanged and record its expected failure separately from the passing Crane test for the selected behavior.

**Takeaway**: **Compare browser behavior at the disputed step, then check whether a newer spec explains the split.**

References: [dialog-focusability results](https://wpt.fyi/results/html/semantics/interactive-elements/the-dialog-element/dialog-focusability.html?sha=23b0b89b1a&label=stable), [HTML PR 8199](https://github.com/whatwg/html/pull/8199), [Gecko HTMLDialogElement](https://searchfox.org/mozilla-central/source/dom/html/HTMLDialogElement.cpp), [WebKit HTMLDialogElement](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/html/HTMLDialogElement.cpp).
