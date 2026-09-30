# Architecture: When a step names something the engine makes later, reserve its identity instead of moving the creation

**Date**: 2026-09-30
**Lesson**: HTML fires `pageswap` at the old document naming targetEntry - the session history entry the navigation will commit - before the old document unloads, and Crane only records that entry after the unload. Reserving the entry's identity (its id, navigation API key and ID) where the event fires let the event name it and the commit make it, with nothing else reordered.

**Why**: The spec's "finalize a cross-document navigation" puts the entry in the session history before "deactivate a document" unloads the old one. Crane's commit (`runCommit` -> `unloadActiveDocument` -> `commitInRealm` -> `recordInHistory`) makes it afterwards. The obvious fix - record the entry before the unload - changes what the OLD document's script sees in between: `history.length`, and `navigation.currentEntry`, both of which Crane reads live from the joint history. The spec keeps them as the old document last saw them; only the new document is updated.

**What Happened**: 13 pageswap files were ERROR or TIMEOUT: the event was never fired. The brief had framed it as "the order of steps in the commit path has to change". `e.activation.from == navigation.currentEntry` inside the old document's pageswap listener only holds while the current entry is still the old one - with the entry recorded first, it would have been the new one.

**Fix**: `JointHistory.prepareDocument` reserves the id, key (a same-origin replace keeps the replaced entry's key) and navigation API ID; `preparedSnapshot` describes the entry for the pageswap event's `activation.entry`; `commitPreparedDocument` later makes exactly that entry. The pageswap step runs inside "unload a document and its descendants", after the children and before the document, and re-checks the navigable afterwards (a listener can remove the frame).

**Takeaway**: **When a spec step names an object the engine only makes later, reserve the object's identity where the step runs. Move the creation earlier only if everything that reads it in between is meant to see it.**
