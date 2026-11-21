# Architecture: A document-owned holder of its own nodes must let go when the document is destroyed

**Date**: 2026-11-20
**Lesson**: State a Document owns that keeps counted holds on that Document's nodes (an undo history, a top layer, autofocus candidates) is a reference cycle under the tree-is-the-unit counts; it must be named in `refcount_teardown.holdsOwnReferences` and let go in `lifecycleReleaseOwnReferences`, or the document and everything it holds live until the Browser's final sweep.

**Why**: Since refcount step 7 a tree is freed only when its total of holds is zero. A hold the Document's own state takes on a node of its tree (or of a subtree it removed) counts in that total, so the document keeps itself alive. Step 7b breaks the cycle for a destroyed document whose only remaining references are its own: `documentDereffed` queues `releaseOwnReferences` - but only when `holdsOwnReferences` says the document holds some.

**What Happened**: Lane edit3's execCommand undo stack (html_core editing/history.zig) holds every node its steps name with `node_holds.RefHold`, traced from the Document's `traceHeldNodes`. The first native run passed every behaviour assertion and failed every test with leaks: the editor state and its steps were never freed. The Document's teardown never ran, because `holdsOwnReferences` knew only the top layer and autofocus candidates, so the destroyed document's undo holds were never released.

**Fix**:
1. A `releaseNodes` step beside the editor state's `free` and `trace` (dom/editor_states.zig), called from Document.zig's `lifecycleReleaseOwnReferences`.
2. A `holdsNodes` step, and `holdsOwnReferences` returns true when the editor state holds nodes (a non-empty undo or redo list) - the narrow test, since every document that ever ran an editing command has an editor state.
3. A native leak test with both shapes: a frame destroyed with a full history, and one with an empty editor state (tests/html/edit3_undo_test.zig).

**Takeaway**: **Before a Document's own state takes a counted hold, wire the three ends - trace from `traceHeldNodes`, release in `lifecycleReleaseOwnReferences`, and declare it in `holdsOwnReferences` - and prove it with a leak test that destroys a document holding nodes.**
