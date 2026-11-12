# Spec Compliance: A padding br follows deleted line content, not a deleted line break

**Date**: 2026-11-11
**Lesson**: The browsers pad a line that a deletion emptied between two block boundaries with a `<br>`, but only when the deletion removed the line's content (text, a replaced element) - never when it removed only the line break itself.

**Why**: The Editing draft adds a br only to a block left with no visible child (delete the selection, step 25.3). Chrome, Firefox and Safari all keep an emptied line between blocks visible: `<div contenteditable>{A}<div contenteditable=false>x</div></div>` -> `<br><div ...>`. Gecko does it after the delete with HTMLEditUtils::LineRequiresPaddingLineBreakToBeVisible (preceded by a block boundary, followed by one). But the same engines' empty-line join (`<br><div>[]def</div>` Backspace -> `<div>def</div>`) deletes a br and must leave nothing behind.

**What Happened**: Lane editing5 b2 added the padding rule at delete the selection's step 30 for any deletion of inline nodes. The area run fixed editing/other/insert-br-tag-on-text-node-removal-with-non-editable-elements.html (3/3) but lost 8 subtests of delete-without-unwrapping-first-line-of-child-block.html (the join deletes `<br>` or a preformatted `\n` before a block, and the new rule put a br back) and 2 table rows of insertparagraph/insertlinebreak.html (a br padded into a `<tbody>`).

**Fix**: Pad only when the removed nodes were all inline and one of them held line content (text with a non-white-space character, or a replaced element); never where a br is not an allowed child (table structure: Gecko's AdjustPointToInsertPaddingLineBreak gives up at the block), never in an inline editing host, never in a display: none subtree. src/html/execcommand/delete.zig padEmptiedLine / holdsLineContent.

**Takeaway**: **A browser "make the emptied line visible" rule must know what was deleted: a deleted line break is the join's empty line, deleted content is a line to keep - run the whole editing/ area, not just the target file, before trusting it.**
