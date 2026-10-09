# Architecture: Parser association is not document activity

**Date**: 2026-10-08
**Lesson**: Validate a parser's ownership using its live document association, separately from the document's browsing-context activity.

**Why**: HTML destruction retires a document's browsing context, while script may retain the Document object and open a new input stream. The old parser must stop; a newly associated parser can still process markup.

**What Happened**: The parser's active-call root guard rejected every document with its lifecycle `destroyed` flag set. A final full sweep found four new `InvalidStateError` failures in event-listeners.window.js, partly offset by a shadow-listener improvement. Three paired runs and the original 50-file process group reproduced the loss. Both close and write on a reopened removed-frame document failed.

**Fix**: Keep slab generation, parser association, epoch, detachment and realm-liveness checks. Remove the unrelated activity flag from parser and input-stream association checks. Keep that flag set, preserve task-activity checks, and disable scripting when the reopened document has no browsing context. Test that the old parser remains revoked, a new parser writes and closes, and inert script elements do not prevent subsequent markup from parsing.

Design references: HTML 8.4.1 steps 16-17, 8.4.2 steps 3-6 and 8.1.3.4; WebKit `Document::open`, `close`, and `explicitClose` in [Document.cpp](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/dom/Document.cpp); Blink `Document::close` in [document.cc](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/dom/document.cc). Both engines finish an associated script-created parser without requiring a live frame.

**Takeaway**: **An activity flag is not a lifetime proof: validate the exact native association that the operation will use.**
