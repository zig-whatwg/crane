# Architecture: An object that copies its source at creation is stale if script makes it mid-construction

**Date**: 2026-11-06
**Lesson**: A NavigationHistoryEntry copied its session history entry's document when it was made. An inline script that made one during the parse, before the commit attached the document to the entry, got an entry whose sameDocument was false for the document's whole life.

**Why**: The spec's getters read the entry: "this's session history entry's document". A copy is right only if the source no longer changes after the object is made. Crane's commit parses inside its own call and gives the entry its document after that call returns. So during a whole-body parse the source still changes after the copy.

**What Happened**: navigation-api/navigation-history-entry/sameDocument-after-fragment-navigate.html, which passes in Chrome, Firefox and Safari, failed in the WPT runner but passed in the console. The console's body streamed, so its inline script ran in a later task, after the attach. The runner's whole body parsed inside the commit, before it. url() already read the entry live; sameDocument kept the copy.

**Fix**: sameDocument reads the entry from the history (the copy only for an entry the history no longer has). And the entry gets its document when the document is made, before any parser task runs ("attempt to populate the history entry's document": IFrameIntegration.next_document_state, taken by createNavigationDocument).

**Takeaway**: **When an object mirrors spec state, read it from its source; a copy taken at creation is wrong whenever script can create the object while the source is still being built - and a whole-body parse inside the commit is exactly that window.**
