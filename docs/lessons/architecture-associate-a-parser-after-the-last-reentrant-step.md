# Architecture: Associate a parser after the last reentrant step

**Date**: 2026-10-08
**Lesson**: Replacing a parser must release the parser present at the association step, including one installed by an earlier callback in the same operation.

**Why**: Discarding a document's parser before removing its DOM does not establish that the parser field stays empty. Child unload and history currententrychange handlers can call document.open before the outer call reaches parser association.

**What Happened**: Document.open discarded the old parser before steps 11–12, then unconditionally assigned a new parser at step 16. A nested open from either callback installed a parser whose document-owned reference was overwritten. Two allocator-backed tests, each using only a nested open, leaked three allocations apiece; their script assertions otherwise passed.

**Fix**: Immediately before step 16, suppress continuations, discard parser-owned script work and the currently associated parser, and clear the old parsing-end/load-delay waits. Then install the new parser and its epoch. Keep both callback paths covered with std.testing.allocator on fresh threads.

**Takeaway**: **Recheck ownership after the last step that can run script, immediately before replacing the owned field.**
