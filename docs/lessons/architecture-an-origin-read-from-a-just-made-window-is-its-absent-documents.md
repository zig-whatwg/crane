# Architecture: An origin read from a just-made Window is the origin of the document it does not have yet

**Date**: 2026-11-06
**Lesson**: After a Window's origin became its Document's (lane loadpath1 batch 1), any step that read the origin from the navigable's active Window mid-commit read "null" whenever that Window had just been made for the document being committed.

**Why**: HTML has one source for a Window's origin, its Document's. A commit that has just made a new Window (realmForDocument, "create and initialize a Document object" step 7) has not given it a document yet. The spec never reads the origin there: it names the value it needs, here a javascript: URL's initiatorOrigin. The Window's old origin copy hid this until the copy was deleted.

**What Happened**: navigation-api/navigation-history-entry/entries-after-javascript-url-navigation.html: the frame's javascript: URL navigation recorded its replacing entry with origin "null". The navigation API then took the current entry as opaque, so entries() was 0 and currentEntry was null. A console built with temporary log lines at each recordInHistory showed the second record of blank.html?1 with origin=null.

**Fix**: The entry's origin is the record the new document is made with, initiatorOrigin (javascriptDocumentOrigin), serialized.

**Takeaway**: **When a copy of state is deleted for its one true source, grep every read of the old copy's holder that runs inside a commit: read the value the spec step names, never the object being built.**
