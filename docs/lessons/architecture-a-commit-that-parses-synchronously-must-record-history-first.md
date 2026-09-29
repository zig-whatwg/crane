# Architecture: A commit that parses synchronously must record the history entry first

**Date**: 2026-09-29
**Lesson**: A frame's new document ran its inline scripts before its session history entry existed, so those scripts saw the history the navigation had left.

**Why**: HTML's "finalize a cross-document navigation" puts the new entry in the traversable's history before any of the new document's script runs. The spec's parser runs later, as tasks. Crane's commit (`IFrameIntegration.commitResponse`) creates the document and parses it synchronously, running every inline script inside the call. The entry was recorded after that call returned. For the whole parse:
- `history.length` was one short;
- `navigation.currentEntry` was the previous document's;
- `location.reload()` reloaded the previous entry.

**What Happened**: location_reload.html's frame calls `location.reload()` while it parses and expects five pings. It pinged once. The reload went through History's "reload" and ran a traversal to the navigable's current entry. That entry was still the one the navigation replaced, the frame's initial about:blank, so the frame navigated to about:blank and never pinged again. A probe separated the two cases: a reload in `onload`, after the entry existed, worked; a reload during the parse did not.

**Fix**: 8b6c667ec.
- `commitInRealm` records the entry first. Its URL is the response's, and its origin is the new document's Window's (that Window is made, with the response's origin, before the commit).
- The document goes in once `commitResponse` has made it, through `JointHistory.setDocumentOfState`. That reaches every entry of the document state, including pushState and fragment entries its scripts made during the parse.
- The javascript: URL commit uses the same order.

**Takeaway**: **When the engine runs synchronously something the spec runs as later tasks, every state the spec sets "before any script runs" has to move ahead of the synchronous call. Probe the same script call from the parse and from onload: if only the parse is wrong, the state is being set too late.**
