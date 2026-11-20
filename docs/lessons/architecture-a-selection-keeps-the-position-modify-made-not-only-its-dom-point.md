# Architecture: A selection keeps the Position modify made, not only its DOM point

**Date**: 2026-11-19
**Lesson**: Blink's selection stores Positions with their anchor type; the DOM boundary point a script reads is only their parent-anchored equivalent, and canonicalizing that point again can land somewhere else.

**Why**: After a table the caret is Position::AfterNode(table). Its DOM point (parent, index + 1) canonicalizes - CanonicalPosition prefers the next candidate in the same block - to the start of what follows the table. A modify that restarts from the DOM point therefore goes back to "after the table" at every backward step.

**What Happened**: Selection.modify("move", "backward", "character") from the paragraph after a table stayed at body@4 for ever in Crane (selection/selection-modify-across-*table*.html: 12 majority-pass subtests), while forward walked through. Chrome 157, probed headless, walks after-table, then the cell's text, then before-table, then the paragraph.

**Fix**: visible_position.modifyPosition returns the FocusForm of the Position it made (the point, or the start/end of the child next to it, with its anchor type); the Selection keeps it with a snapshot of itself and the next modify rebuilds the Position from the live DOM point while the selection is unchanged. Nothing node-valued is kept: the snapshot is only compared.

**Takeaway**: **When an algorithm translated from Blink stores a Position, keep its anchor form across calls; turning it into a DOM point and back is not the identity at tables and editing-ignored content.**
