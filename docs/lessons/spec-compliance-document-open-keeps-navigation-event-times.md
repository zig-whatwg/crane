# Spec Compliance: Document replacement keeps navigation event times

**Date**: 2026-10-18

**Lesson**: Dispatching another DOMContentLoaded or load event after document.open does not replace the original navigation timestamps.

**Why**: Event dispatch and the navigation entry's first recorded milestone have different lifetimes. A replaced document can fire load events while script still observes the same navigation entry.

**What Happened**: Crane guarded domInteractive and domComplete but rewrote the DOMContentLoaded and load timestamps, including navigation duration. The rt3-navigation-document-open.html regression failed after its first replacement. Both upstream document-open timing tests pass in all three aligned stable browsers.

**Fix**: Retain each first recorded event timestamp and the corresponding navigation duration. HTML's cached “the end” steps 6.1/6.3 and 9.4/9.8 say to set them; follow the established unanimous browser behavior here. Blink's [Document::FinishedParsing](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/dom/document.cc) and [LocalDOMWindow::DispatchLoadEvent](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/frame/local_dom_window.cc) guard the timing writes while still dispatching later events. Test repeated completed replacements, both timing interfaces, entry identity and duration.

**Takeaway**: **Keep repeated event delivery separate from recording a navigation's first milestones.**
