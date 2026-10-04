# Architecture: A navigable's children are its active document's - a list kept past the document that owned its entries is read freed

**Date**: 2026-10-04
**Lesson**: `BrowsingContext.children` kept the iframes of a document that a
navigation replaced. The old document's teardown freed those browsing contexts
on the collector's schedule while the list still named them, and the next walk
of the list read freed memory: a crash when the block was still poisoned, a
silent write into another object when it had been reused.

**Why**: HTML's navigable tree hangs off ACTIVE documents - a navigable's child
navigables are the content navigables of the navigable containers in its
active document ("document-tree child navigables") - and Blink detaches a
frame's children in `FrameLoader::DetachDocument`, after the unload event and
before the new document commits (`LocalFrame::DetachChildren`, each child's
`Frame::Detach` unlinking it from its parent). Crane's list was a cache of that
tree with no step that cleared it when the document changed, and
`BrowsingContext.deinit` deliberately did not leave its parent's list ("the
parent may already be freed"). So the list's entries lived exactly as long as
the old document's iframe elements - until a collection.

**What Happened**: the perftimeline lane's Resource Timing made more garbage,
and `html/browsers/browsing-the-web/navigating-across-documents/cross-origin-top-navigation-without-user-activation-nested.window.js`
crashed 10 of 12 single-process runs of its 20-file shard prefix (0 of 12 on
main): SIGSEGV at 0xaaaa... in `collectDescendants`, under `window.close()`'s
"definitely close". The same lane's `resource-timing/nested-context-navigations-iframe.html`
leaked 286 to 1,457 `JointHistory` structs, all from `History.runTraversal`.
A scratch trace patch (`std.log.scoped(.bctrace)` warn lines with addresses
for every create, free, child-add, child-remove, discard, close and
`collectDescendants` visit, applied by a python script inside a separate chat
mirror) named both in one run each:

- the crash: popup P commits a page whose iframe A holds iframe B; B navigates
  P's top (allowed in Crane), P's document is replaced, P's list keeps A; a
  collection frees B and then A (`integration-deinit`, `free bc=A parent=P`);
  definitely close collects P, then `cur=A` - the last line before the fault;
- the leak: every leaked address matched a `jh-create top=<context freed
  earlier>` line. The traversal's `ensureEntries` ran on a freed child whose
  block had been reused; `getTop()` found no parent in the new bytes, made it
  its own top, and `jointHistory()` stored the new JointHistory's pointer in
  whatever object now owned that memory - a leak that was also a corruption.

**Fix**: the ordering first: after "unload a document and its descendants"
(each document unloaded and, unsalvageable, destroyed - "unload" step 20),
`destroyChildNavigables` destroys the replaced document's child navigables
through the integrations that own them (`onRemovedFromDocument` ->
`BrowsingContext.discard`), in Blink's order. Then defence in depth: the parent
link and the list entry are one fact, ended together by `removeFromParent`,
`discard` and `deinit`. Proof, 20-file list, N=12 each: perftimeline tip 10/12,
the ordering fix alone 0/12, with the links too 0/12, main 0/12; the leak file
alone 1,373 DebugAllocator leaks -> 0 (the ordering fix alone too); and
`window.length` reads 0 after a navigation to a document with no frames
(crane/bc-navigated-away-frames-leave.html, 0/3 -> 3/3).

**Takeaway**: **A pointer list that mirrors a spec structure must be emptied
by the spec step that changes the structure, not left to its entries' owners
to free. And match leaked addresses against a trace before calling a leak
"never freed": these were allocations made ON a freed block.**
