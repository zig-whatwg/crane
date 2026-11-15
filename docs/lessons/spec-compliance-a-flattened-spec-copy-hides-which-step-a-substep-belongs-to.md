# Spec Compliance: A flattened spec copy hides which step a substep belongs to

**Date**: 2026-11-12
**Lesson**: Before reading a step as conditional on the one above it, check its nesting in the live spec's `<ol>` markup. The Markdown copy in `specs/` indents every level by one space, so a sibling step looks like the last substep of its neighbour.

**Why**: `specs/whatwg/html.md` keeps the step numbers but not the nesting depth. In "apply the history step", step 8.3 is "If targetEntry's document is not navigable's active document, then queue a global task ... to run these steps: 1. 2. 3.", and step 8.4 is "Set navigable's ongoing navigation to "traversal"". In the Markdown, both lists are written ` 1.`, ` 2.`, ` 3.`, ` 4.`, so 8.4 reads like a fourth step of 8.3's task, which only a cross-document target gets.

**What Happened**: Crane set the ongoing navigation to "traversal" only for a cross-document target (apply_history_step.zig skipped `c.same_document`). A same-document `history.back()` therefore left a cross-document navigation of the same frame running until step 14.10.1. The misread came to light while diagnosing html/browsers/browsing-the-web/overlapping-navigations-and-traversals/cross-document-nav-same-document-traversal.html, which flakes on server1 in both builds. Fixing it was the spec step, but it did NOT cure that flake (4/20 before, 5/20 after, x20 each side): the step only ends a navigation whose finalize is not yet queued.

**Fix**: Lane nav2 batch 11 found the nesting by curling the multipage HTML and turning `<ol>`/`<li>` into markers. Step 8.4 now applies to every changing navigable of a traversal, same-document ones included; whatwg/html#12861 and its PR #12942 keep it to traversals and reloads.

**Takeaway**: **When a step's scope decides behaviour, read its nesting from the live HTML (`<ol>` depth), not the Markdown copy.** And a plausible spec misread found next to a flake is not its cause until the same-list counts say so.
