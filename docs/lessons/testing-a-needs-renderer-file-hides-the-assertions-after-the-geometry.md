# Testing: A needs-renderer file hides every assertion after its geometry read

**Date**: 2026-11-12
**Lesson**: When a file's first failing assertion is a renderer read (a click's caret, a line end, a box size), the assertions after it never ran: before calling the file needs-renderer, supply the renderer's answer by script in a Crane test and run the rest of the file's steps.

**Why**: testharness stops a test at its first failed assertion, so the journal names only the geometry failure. The needs-renderer kind requires EVERY failure to be one a renderer would answer, and the later steps - often plain DOM editing - are exactly the part nobody has seen fail yet.

**What Happened**: Lane editing5 batch 3 listed two click-then-Backspace files as needs-renderer candidates. Each failed at the click: Crane places no caret for a click on an element with content, because where the click lands is the renderer's position-for-point. Batch 4 wrote crane/ed5-delete-at-renderer-caret.html, which puts the caret by script where a renderer's click (and End, a line-box read) would leave it. One file then passed every step: selection/fire-selectionchange-event-on-deleting-single-character-inside-inline-element.html was listed. The other did not: in editing/other/fire-selection-change-on-deleting-empty-element.html, the second Backspace in the emptied `<h1><br></h1>` fired no selectionchange. Blink's TypingCommand empties an editing root whose only caret position is the caret (MakeEditableRootEmpty), and Chrome and Firefox pass. Crane did nothing there. Listed on the first failing assertion alone, that file would have hidden a real editing bug behind an exemption.

**Fix**: For each candidate, a Crane test that replaces only the renderer read (`getSelection().collapse(...)` where the click and End would put the caret) and keeps every later step and assertion. List the file only when that test passes. Fix what it finds first: here, MakeEditableRootEmpty for Backspace.

**Takeaway**: **An exemption for geometry needs proof that nothing but the geometry is missing: script the renderer's answer and run the rest of the file before listing it.**
