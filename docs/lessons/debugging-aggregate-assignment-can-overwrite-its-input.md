# Debugging: An aggregate assignment can overwrite its input

**Date**: 2026-10-18
**Lesson**: Compute values that depend on an aggregate's old fields before assigning an anonymous initializer to that aggregate.

**Why**: Zig's [result-location semantics](https://ziglang.org/documentation/0.16.0/#Result-Locations) can initialize fields directly in the destination, in order. Reading the destination from a later field initializer can observe an earlier field's new value.

**What Happened**: Selection's new editing-boundary traversal assigned `position = .{ .node = parent, .offset = getChildIndex(parent, position.node) + adjustment }`. The index calculation saw `parent` instead of the old child. Forward traversal produced an invalid offset; backward traversal re-entered the same noneditable child indefinitely. The isolated character test exposed IndexSizeError and the whole upstream file stopped progressing.

**Fix**: Calculate the child index and adjusted offset in a local before assigning the new position. Keep the native regression exercising both directions and rerun the entire upstream file after the isolated case passes.

**Recurred**: 2026-10-23, lane editing1: the delete command's `point = .{ .node = p, .offset = try indexOf(point.node) }` (six sites) drilled every caret up to its parent at offset 0 - the whole-element deletions removed the node BEFORE the target, and the block merge threw IndexSizeError. The fix is a helper that takes the old node as an argument (`common.pointBefore(node, parent)` / `pointAfter`), which cannot read a half-written destination; prefer one wherever a point is rebuilt from itself.

**Takeaway**: **An anonymous aggregate initializer is not a snapshot of the old destination. Save dependent inputs before assigning it.**
