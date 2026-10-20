# Spec Compliance: Selection Clamping Is a Mutation

**Date**: 2026-10-20
**Lesson**: Persist selection clamping when a control's relevant value changes; clamping only a getter loses intermediate mutations.

**Why**: A replace-all operation removes the old children before inserting the new children. A clean textarea's value becomes empty between those steps, even when script never reads it then.

**What Happened**: Crane stored selection offsets 3–5, replaced the textarea's children with another long string, and returned 3–5 again. Its getter clamped against the final length, so it missed the empty intermediate value. Shrinking a Text child's data and growing it again had the same problem.

**Fix**: Install the textarea's children-changed steps through the existing DOM mutation hook. For a clean textarea with stored nonzero offsets, clamp the stored selection against the normalized API value's UTF-16 length. Leave a dirty textarea's independent value alone. Return before reading text for other element types or zero offsets. Test both child replacement and CharacterData shrink/grow, with no intervening selection read.

HTML 4.10.11 defines the children-changed update; 4.10.20 defines relevant-value clamping. Blink's [HTMLTextAreaElement::ChildrenChanged](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/html/forms/html_text_area_element.cc) and WebKit's [HTMLTextAreaElement::childrenChanged](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/html/HTMLTextAreaElement.cpp) both update clean values with a clamp selection policy.

**Takeaway**: **An observable value can depend on mutations that occurred between reads. A getter cannot reconstruct that history.**
