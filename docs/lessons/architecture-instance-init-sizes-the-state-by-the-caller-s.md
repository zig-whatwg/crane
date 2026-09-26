# Architecture: `Instance.init` sizes the state by the caller's type; `onObjectFreed` frees it by the vtable's

**Date**: 2026-09-22
**Lesson**: `Instance.init(allocator, StateType, vtable, ctx)` allocates
`@sizeOf(StateType)`; `gc_integration.onObjectFreed` frees
`vtable.state_size`. Pass a subtype's vtable with a parent's State and the
arena's size-class free list is poisoned, not leaked.

**Why**: `Node.cloneSingleNode` fell through, for every node type it did not
handle, to `Instance.init(allocator, State, node.vtable, ...)` - Node's State
under the node's own vtable. A cloned Document therefore had a `Node.State`
sized block (small class) that was later returned to the arena as Document's
1080 bytes (the 1024 class). The next `Document.InternalState` was carved from
that block and overlapped whatever lived after the small one; its neighbours'
ordinary writes zeroed the new document's allocator, and `Node.init` faulted
at 0x0 under `createElement`. The clone also had no registry state, so
`createElement` on it could only throw.

**What Happened**: three rounds of instrumentation, each ruling out a
theory that fit the symptom:

1. The generation stamp ([architecture-a-stale-weak-callback-s-registry-remove-evicts](architecture-a-stale-weak-callback-s-registry-remove-evicts.md)) - correct, and closed a different
   crash, but this document's callback saw its own generation.
2. Tagging `Document.init/deinit` and the Document registry - between the
   new document's init and the fault there was no deinit, no `remove`, no
   double free. The registry was not the actor.
3. Logging every arena pop and push with the block address named it in one
   run: `[onObjectFreed] DOC ... state=@X state_size=1080`, `push class=7 @X`,
   `pop class=7 @X`, `createIn ... block=@X`, then `[createElement]`
   `alloc_vtable=0x...` followed by `alloc_vtable=0x0` with **no allocator
   event between**. A block that changes with no allocator event is being
   written through somebody else's pointer, and "somebody else" is whoever
   owns the memory the undersized block overlaps.

A `dumpCurrentStackTrace(.{})` at `Instance.init` for `vtable.name ==
"Document"` then grouped 15 creations into 6 stacks; the 3 that never
reached `Document.init` were all `Node.cloneSingleNode`. Note the Zig 0.16
signature takes a `StackUnwindOptions` struct, not a start address.

**Fix**: DOM §4.4 "clone a single node" step 3 - the copy implements the same
interfaces as node - as typed branches: Document via `interfaces.Document.init`,
DocumentType via the owner's `DOMImplementation.createDocumentType`, Attr via
`createAttributeNS` + `set_value`, DocumentFragment via
`createDocumentFragment`. The fallthrough now returns `error.NotSupported`
rather than sizing a State it cannot know. Stated deviation: a cloned
Document keeps `Document.init`'s defaults for encoding, content type, URL,
origin, type and mode - those are Document internals with no interface
delegate to set them, and an impl-to-impl call is not allowed in new code.
`custom-elements/Document-createElement.html`: CRASH -> OK.

**Takeaway**: **A block that changes with no allocator event is being written
through a pointer that was never yours. Trace the BLOCK - every pop and push
of its address - before theorising about the object; and never hand
`Instance.init` a State type that is not the vtable's own.**
