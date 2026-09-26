# Architecture: A frame's load event has exactly one owner, and `window.document` is script's getter

**Date**: 2026-09-24
**Lesson**: Once a parsed frame document ran HTML "the end" (00f7e2d7c), "completely finish loading" fired the container's load. The synchronous fire sites that predated it - srcdoc, data:, `set_src`, and `contentWindow.location` navigations - kept firing too.

**What Happened**: data: and srcdoc frames fired load two or three times. `iframe-allowfullscreen.html` became an infinite postMessage ping-pong, because each load posted a request and the frame answered every message twice. `crane/iframe-load-once.html` pins one load each.

Two things hid it:
* The existing guard read the frame's document through `interfaces.Window.get_document`. That is the script-facing getter, and it refuses a cross-origin reader, so for a data: frame (opaque origin) "no document" meant "fire".
* `set_src` fired load for data: URLs on a disconnected iframe, where nothing had navigated.

**Fix**: `childDocument` reads the browsing context's own `active_document`. Every synchronous site goes through `fireLoadUnlessDocumentWill`. On initial insertion, a URL matching about:blank is not navigated ("process the iframe attributes" step 2.3), so the frame keeps its initial document and its window sees no load or pageshow. A "the end" task whose document a navigation has already replaced does not run, because the event loop runs only tasks whose document is fully active.

**Takeaway**: **Engine code asking about a frame must not use the getters script uses.** Those carry the cross-origin checks, and they answer "no" for exactly the frames that most need a correct answer.
