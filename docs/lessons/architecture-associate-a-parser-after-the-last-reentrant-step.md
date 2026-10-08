# Architecture: Associate a parser after the last reentrant step

**Date**: 2026-10-08
**Lesson**: Replacing a parser must release the parser present at the association step, including one installed by an earlier callback in the same operation.

**Why**: Discarding a document's parser before removing its DOM does not establish that the parser field stays empty. Child unload and history currententrychange handlers can call document.open before the outer call reaches parser association.

**What Happened**: Document.open discarded the old parser before steps 11–12, then unconditionally assigned a new parser at step 16. A nested open from either callback installed a parser whose document-owned reference was overwritten. Two allocator-backed tests, each using only a nested open, leaked three allocations apiece; their script assertions otherwise passed.

**Fix**: Immediately before step 16, suppress continuations, discard parser-owned script work and the currently associated parser, and clear the old parsing-end/load-delay waits. Then install the new parser and its epoch. Keep both callback paths covered with std.testing.allocator on fresh threads.

**Sweep attribution (DW-M5)**: The three extra native leak reports in the row 11 sweep were this same defect. Replaying chunk aan/shard 1's exact 50-file list in one process gave zero leaked markers on f83fd1e955 and three on 52e195b3a2. Paired splits and a file census isolated `html/browsers/browsing-the-web/unloading-documents/004.html`; its child unload calls `parent.document.open()`. `CRANE_LEAK_TRACES=1` named `DocumentParser.createWithInput`, `TreeNode.initDocument`, and the TreeNode-to-Instance map. After 36be451196, both the traced single file and the original 50-file group report zero leaks. The group preserves all results: 49 OK / 1 ERROR, 61 passing / 20 failing assertions on both f83 and the repaired build. The existing child-unload allocator test is the minimal regression; a second production change is unnecessary.

**Takeaway**: **Recheck ownership after the last step that can run script, immediately before replacing the owned field.**
