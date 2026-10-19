# Spec Compliance: Shadow activeElement reads the document designation

**Date**: 2026-10-19
**Lesson**: Document and ShadowRoot implement the same activeElement algorithm over the document's focused-area designation.

**Why**: A shadow root does not maintain an independent focus designation. HTML retargets the document's focused area's DOM anchor into the requested tree and returns null if the candidate's root differs.

**What Happened**: ShadowRoot.activeElement returned a private field that no focusing path updated. A focused nested input therefore produced null, even though Document.activeElement correctly exposed the outer host. The fresh-thread native regression reproduced `open: inner`; the upstream ShadowRoot-interface tests failed in both modes.

**Fix**: Call the existing `html.focus.activeElement` helper after validating ShadowRoot state. It implements HTML steps 1–7, including retargeting, root comparison and the document fallback. Its designation read already observes removal without running rendering-time focus fixup. Test open and closed nested roots, removal, outside focus and slotted light-DOM focus.

WebKit uses the same design: `ShadowRoot::activeElement` calls `TreeScope::focusedElementInScope`, which reads the document's focused element and adjusts it into the scope. See [ShadowRoot.h](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/dom/ShadowRoot.h) and [TreeScope.cpp](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/dom/TreeScope.cpp).

**Takeaway**: **Reuse the document's focus designation and retarget it; another cached active-element pointer would duplicate state and require its own lifetime rules.**
