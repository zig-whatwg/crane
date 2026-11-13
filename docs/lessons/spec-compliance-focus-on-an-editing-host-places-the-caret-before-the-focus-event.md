# Spec Compliance: focus() on an editing host places the caret, before the focus event

**Date**: 2026-11-12
**Lesson**: Every browser gives a root editable element the caret at its start when script focuses it and the selection is elsewhere, and does it before the focus event fires; without it `host.focus(); document.execCommand(...)` finds no range and silently does nothing.

**Why**: HTML's focusing steps say nothing about the selection, but Blink and WebKit's Element::UpdateSelectionOnFocus (focus() passes kRestore) and Gecko's HTMLEditor::OnFocus -> InitializeSelection collapse the selection into the focused editing host. Crane had only the reverse path (a selection set in a host focuses it: selection_focus.focusPosition).

**What Happened**: Lane editing5 b2 found editing/other/inserttext-after-bold-in-font-face-monospace.html failing with "div + div is null": every execCommand after `editingHost.focus()` ran with no active range. Adding the caret AFTER the focusing steps fixed it and 14 other editing subtests (plaintext-only/insertText.html, insertHTML.html, typing-text-in-direct-child-of-editing-host.html), but lost both rows of selection/contenteditable/initial-selection-during-focus-event-propagation.html: its focus listeners must already see the caret (UI Events: focus moves before the event; Chrome and Firefox pass).

**Fix**: In focusMethod, before step 2, selection_focus.caretOnFocus(element) collapses to (element, 0) when the element is a rendered, non-inert root editable element and the selection's anchor is not in it; Selection.collapse's own editable focus step then focuses it, and step 2 finds it focused. Script focus only - a click's caret is a hit position.

**Takeaway**: **An editing test that calls focus() and then edits depends on the focus placing a caret, and listeners depend on WHEN: set the selection before the focusing steps fire their events, and re-run html/interaction/focus/, selection/ and shadow-dom/focus* against the generation, because focus() is reached everywhere.**
