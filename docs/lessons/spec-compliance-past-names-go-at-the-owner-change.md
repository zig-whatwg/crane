# Spec Compliance: A form's past names go at the change of owner, and insertBefore is one

**Date**: 2026-10-16
**Lesson**: "If an element listed in a form element's past names map changes form owner, then its entries must be removed" is applied at the change - and `insertBefore` of a node already in the tree changes its owner twice.

**Why**: Crane computes a form owner on every read; nothing is told when it changes. Checking an entry lazily ("is the element still the form's?") misses an owner that changed and changed back between two reads: the control removed and reinserted, the form's id renamed and restored. The spec, WebKit (`removeFromPastNamesMap` from `unregisterFormListedElement`) and Blink (`Disassociate`) drop the entries at the change.

**What Happened**: The lane's first test expected a control moved within its form by `form.insertBefore(control, form.firstChild)` to keep its past names, and the implementation dropped them. The implementation was right: inserting a node that has a parent removes it first (DOM "adopt" -> "remove"), the removing steps reset its form owner to null, and that is a change of owner. `moveBefore` keeps the node in its tree, its owner never changes, and the entries stay.

**Fix**: The agent keeps the forms that have past names (dom.form_past_names.Registry on its AgentHost - per agent, because adoptNode moves a form with its controls between documents of one agent). The "reset the form owner" seams (form_owner.zig: every insertion, removal and move; `form` and `id` attribute changes; a parser association recorded) hand the change to each such form, which recomputes the owner of only the entries the change can reach and drops those it no longer owns. The registry is empty - one length check per mutation - until script reads a single named element off a form. Entries hold their element by a weak link: an entry's element is in the form's tree while the entry stands, and node state never counts another node (refcount design D1; WebKit's map holds WeakPtrs).

**Takeaway**: **A rule keyed on a change of a computed value needs the change, not a later comparison - and a remove-then-insert is two changes even when the value ends where it began.**
