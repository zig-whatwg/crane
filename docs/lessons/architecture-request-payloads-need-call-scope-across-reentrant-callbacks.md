# Architecture: Request Payloads Need Call Scope Across Reentrant Callbacks

**Date**: 2026-10-29
**Lesson**: Save and restore temporary request state around script callbacks, while keeping persistent element state independent.

**Why**: An event listener can cancel a request, invoke the same operation again, detach its nodes, or collect wrappers. Storing a request's arguments on an element does not make those arguments part of the element's lasting state.

**What Happened**: A canceled dialog request left its source invoker stored. A later light dismiss reused that source instead of exposing null. Simply clearing the fields after every request would introduce another error: a nested request from the cancel listener could erase the outer request's return value or source. Native regressions reproduced both paths. The aligned stable `dialog-toggle-source.html` results at WPT revision `cc74d2669f` showed the canceled-request/light-dismiss case passing in Chrome 154 and Firefox 157; Safari's failure was in its input driver. WebKit's `HTMLDialogElement::requestClose` also keeps request arguments on the call stack.

**Fix**: Treat the temporary enable flag, result and source as a call frame. Save the outer values, retain the subject and saved source with existing task holds, install this request's arguments, and restore the outer frame in a defer after the close-watcher call. Revalidate the subject before restoration because callbacks can end its realm. An outermost return restores an empty frame. Do not restore persistent `open` or `returnValue` state: script and successful closing steps are allowed to change them. Test cancellation followed by a different close path, reentrant requests, and collection during the callback.

The browser design reference is [WebKit's HTMLDialogElement implementation](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/html/HTMLDialogElement.cpp). Crane follows the observed browser behavior here; the literal HTML request-to-close steps 5–8 leave canceled payloads stored, so the implementation documents that discrepancy.

**Takeaway**: **Temporary callback arguments need a nested call frame, even when their storage is an element field.**
