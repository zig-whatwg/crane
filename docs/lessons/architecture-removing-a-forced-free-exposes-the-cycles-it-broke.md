# Architecture: Removing a forced free exposes the reference cycles it broke

**Date**: 2026-11-17
**Lesson**: A free made whatever the counts say hides every counted reference that an object's own state keeps on its own tree; remove the forced free and each such reference becomes a leak that only the final sweep frees.

**Why**: Refcount step 7a freed a realm's document tree at the realm's end whatever its counts (Window.deinitOwn -> node_creation.destroyRoot, node_wrappers.endRealm, runtime.orphan_roots.drain). Any counted reference from the document's own state, or from a node of the tree, onto a node of the same tree was therefore never a problem: the forced free took both ends of the cycle together. Under step 7b (lane rc7b) the realm's end lets go of the realm's own references and the counts decide, so a tree that holds itself is never garbage.

**What Happened**: Lane rc7b removed the three forced frees and ran the whole native test step: 101 failures, most of them the agent-end check (dom.refcount_teardown.agentEnded: "N node(s) alive at the agent's end"). The cycles it found:
- a Document's top layer (popovers, modal dialogs, open dialogs, fullscreen entries, pointer and hint targets) and its autofocus candidates - MemberHolds from the document's own state onto its nodes;
- an open dialog's previously focused element and request close source - MemberHolds from a node onto a node of its own tree (WebKit keeps the first as a WeakPtr);
- the empty subfragments Range's extract and clone append to a clone and drop - each kept its creator's born reference, a foreign hold that kept its whole document (the long-known "insertParagraph leaves fragments" finding);
- an engine-less test realm (a ContextData with no agent) has no deferred teardown queue at all, so nothing but its Window's own free can ever free its document.
Two more holders a realm's end used to cover were order problems, not cycles: tasks queued for the document (HTML "destroy a document" step 5, now done at once, mid-drain safe) and the fetches the page's script started ("abort a document": a page ended by Browser.navigate and a bfcache-evicted page's own document never aborted theirs).

**Fix**: Each holder ends where its owner ends, as WebKit does it: a destroyed Document that nothing outside its own work references lets go of its own state's references (refcount_teardown.documentDereffed -> document_lifecycle.releaseOwnReferences: the dialogs' saved nodes, the autofocus candidates, the top layer - WebKit's Document::removedLastRef "or we will create a reference cycle"); the subfragment's born reference is released right after its append (Range.zig appendSubfragment); "destroy a document" removes the document's tasks; every page end aborts its fetches. A diagnostic patch recorded each holderRef's stack per node (and each keep's) and printed the outstanding ones beside the agent-end report - one run named every remaining holder.

**Takeaway**: **Before removing a free that ignores the counts, list every counted reference an object's own state (or a node) keeps on its own tree - each is a cycle the forced free was breaking - and give each an owner-end release; the agent-end check plus per-node holder stacks finds the ones the list missed.**
