# Spec Compliance: Blur unfocuses the designation

**Date**: 2026-10-27
**Lesson**: An explicit blur acts on the element still designated as focused, even if that element has just lost focusability.

**Why**: Removing tabindex and changing disabled or display state can leave the focus designation in place until a rendering opportunity. Rechecking eligibility inside blur makes it impossible to explicitly clear that still-current designation.

**What Happened**: Four subtests in shadow-dom/focus/focus-method-delegatesFocus.html failed because their reset removed tabindex and then called blur. The eligibility guard rejected blur, and a later host.focus() preserved the stale shadow child. Chrome, Firefox and Safari pass all fifteen subtests at WPT revision ffc4686d11. A separate sd1 regression reproduced the problem in light DOM and open/closed delegating roots, with synchronous designation and event assertions.

**Fix**: Keep the unfocusing steps' old-chain membership check and follow the browsers over step 6's eligibility recheck. [Blink Element::blur at 8d5ba1795f0c50b90072399d0403389df6eebbd6](https://github.com/chromium/chromium/blob/8d5ba1795f0c50b90072399d0403389df6eebbd6/third_party/blink/renderer/core/dom/element.cc) tests the adjusted focused element and clears it without IsFocusable. No code was copied.

The asynchronous path is different: HTML update-the-rendering step 17 runs the focusing steps for the viewport when a connected focus target becomes non-focusable, usually firing blur and change. It also resets the navigation focus flag. Reuse the existing focus-update algorithm so a blur listener's new focus survives. Removed targets retain the separate synchronous removal behavior, which does not dispatch blur.

**Takeaway**: **Designation, eligibility and focus fixup are separate operations.** Read designation in activeElement and selectors; test eligibility when choosing a target; explicitly unfocus a current designation even after eligibility changes.
