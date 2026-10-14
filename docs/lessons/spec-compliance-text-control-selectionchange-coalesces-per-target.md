# Spec Compliance: Text control selectionchange coalesces per target

**Date**: 2026-10-14

**Lesson**: A text control's selectionchange event has its own pending flag, separate from its select tasks and the document's selection.

**Why**: HTML queues a select event for every effective selection change. The Selection API instead coalesces selectionchange until the scheduled event starts firing. Sharing a task count or flag gives different results when several setters run together or a listener changes the selection again.

**What Happened**: Input and textarea setters correctly updated UTF-16 selection offsets and queued select, but never scheduled selectionchange. The upstream text-control tests passed only 16 of 60 subtests, and the bubbling test timed out waiting for its first event. Detached controls must notify too, so connecting the event to focus or a rendered DOM Range would miss valid cases.

**Fix**: Keep the specification's boolean in each control's existing selection state. Schedule through a shared DOM helper using the existing retained-target task pattern; publish the flag before queue handoff, clear it before dispatch and on drop, and release the target exactly once. Re-read textarea's flag through its owner accessor instead of storing a pointer into its movable state map. Pin independent controls, equal-selection suppression, reentrant listeners, detached targets surviving GC, and synchronous queue drop.

Chrome and Firefox dispatch the notification on the document for controls inside a shadow tree; Blink's TextControlElement::ScheduleSelectionchangeEventOnThisOrDocument does so explicitly. Reuse the document's existing coalescing state for that browser-majority behavior rather than making the element event composed. Evidence: WPT cc74d2669f, selection/textcontrols/selectionchange-on-shadow-dom.html, Chrome/Firefox 1/1 and Safari 0/1.

Sources: [Selection API scheduling and firing](https://w3c.github.io/selection-api/#selectionchange-event), [Blink text-control scheduling](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/html/forms/text_control_element.cc).

**Takeaway**: **Coalesce the selectionchange target; keep select scheduling and DOM Range representation separate.**
