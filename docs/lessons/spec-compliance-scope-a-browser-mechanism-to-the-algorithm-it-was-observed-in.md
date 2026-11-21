# Spec Compliance: Scope a browser mechanism to the algorithm it was observed in

**Date**: 2026-11-20
**Lesson**: When all three browsers deviate from a shared spec definition in one command (here: a nested `contenteditable=true` element edited as content of the outer host by removeFormat), change that command's step, not the shared definition - the other algorithms that read the definition may still match the browsers through it.

**Why**: The Editing spec's "editing host" and "editable" feed every command. The browsers have no such definition; each command reaches its result through its own machinery (Blink's paragraph-based list and block commands keep a nested editable div as the paragraph's container, while its ApplyStyleCommand edits the nested span's style).

**What Happened**: Lane edit3 first made `common.isEditingHost` answer false for a true-state element nested in richly editable content, to follow all three browsers on editing/other/shadow_root_iteration_in_block_style.html. The targeted run gained that mechanism but lost two PPP rows of editing/run/insert-list-items-in-table-cell.html (all three keep `<div contenteditable="true">` as the list's root) and one FFF insertparagraph.html row Crane passed on the spec (`<ul contenteditable><li>{}<br></ul>` became `<p><br></p>`).

**Fix**: Restore the definition; give removeFormat's split step its own predicate (`common.isNestedRichEditingHost`, `split_parent.splitParentOf(.., nested_host)`), with a native test pinning both behaviours (removeFormat unwraps the nested span; insertOrderedList keeps the nested div as its root).

**Takeaway**: **A golden-rule-2 mechanism found in one command is evidence about that command; change the shared definition only when every command that reads it agrees, and let the targeted run's subtest diff show the blast radius before the change spreads.**
