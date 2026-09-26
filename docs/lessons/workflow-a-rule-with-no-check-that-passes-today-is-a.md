# Workflow: A rule with no check that passes today is a suggestion

**Date**: 2026-09-23
**Lesson**: "Calling impls across the boundary in new code" was already non-negotiable, and six new cross-impl references landed in five commits in one day, because nothing checked them.

**Why**: `zig build lint-impls` listed the files that imported the impls module from outside allowed directories. It never looked at one impl calling another, and it failed on files that predated it - so it failed every run, gated nothing, and nobody ran it.

**What Happened**: a review asked whether the rule was being followed. The audit found `Document -> RangeImpl.joinDocument`, `ParentNode -> HTMLCollectionImpl.makeLive`, `NodeIterator -> NodeImpl.getNodeType`, `Document -> NodeImpl.setOwnerDocument`, and `src/dom/mutation.zig -> impls.Node.getOwnerDocument` - and 36 sites across the impls, the parsers and the context manager setting a node's document through `NodeImpl.setOwnerDocument`. `src/webidl/interfaces/` itself was clean: regenerated from the IDL, every file matched byte for byte.

**Fix**: each call now goes through the owner's impl if the caller is in the owner's hierarchy, through an interface if it is not and an IDL member exists, and otherwise through a `src/dom/` hook the owning impl installs (`node_document.zig`, `traversal.zig`, `live_collections.zig`, `range_boundaries.zig`) - see [architecture-inside-a-hierarchy-go-through-the-impl-a-hook](architecture-inside-a-hierarchy-go-through-the-impl-a-hook.md) for how the first route was got wrong at first. `tools/lint_impls_boundary.zig` is a per-file, per-`Impl.member` ratchet that `zig build test` runs; a new cross-type reference and the `getNodeType` swap in NodeIterator both fail it with the file, line and code.

**Takeaway**: **A rule needs a check that passes today and fails on regression. Ratchet it on today's number, key it finely enough to see a swap, and put it in the step everyone already runs.**
