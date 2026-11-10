# Architecture: A cached view turned into a live read needs the old value passed to the steps that read it

**Date**: 2026-11-10
**Lesson**: When a derived field that was re-derived inside the change steps (an element's ID view) becomes a live read of its source (the attribute list), every step that read the field BEFORE the re-derivation was reading the old value - and now reads the new one; find them and hand them the old value explicitly.

**Why**: DOM's "handle attribute changes" runs after the list changed. A cached ID re-derived at the end of the id attribute's change steps gave everything that ran before it a free "old ID" - in particular the tree scope's maps, which take the element out under its old ID (Blink Element::UpdateId, WebKit Element::updateId) before putting it back under the new one. A live read (`ElementData.idValue`, through the index in the list's header) has no such window.

**What Happened**: Lane nd2 b1, N3 (the ID and classes as two u8 indices in the attribute list's header, ElementData 64 -> 16 B). Element's id change steps called `tree_ordered_map.beginChange(..., .current)`, which read `data.id` as the old ID because `rederiveId()` came after it. With the view gone, `.current` would have read the new ID, unregistered a key the maps never had, and left the element registered under its old ID: getElementById would answer the stale ID. The name attribute's change already passed its old value (`.was`), which showed the shape.

**Fix**:
1. List every reader of the old field that runs between the source's mutation and the re-derivation (here: `beginChange(.current)` in Element's attribute change steps).
2. Give each the old value from the change itself (the attribute's old value): `OldName.id_was = old_value orelse ""`, beside `.was` for the name attribute.
3. Pin it: the N3 tests check getElementById for the old and new IDs after a change, a removal and a setAttributeNode replace.

**Takeaway**: **A cache that is re-derived late is also a record of the old value; when it becomes a live read, the steps that relied on that record need the old value passed in.**
