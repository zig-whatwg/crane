# Architecture: A gate that trips once is not a scope - reset only what a mutation reaches

**Date**: 2026-10-08
**Lesson**: Form-associated custom element owners were refreshed by walking and allocating the whole tree on every children change, removal and id/form/disabled attribute change, guarded only by "any formAssociated definition exists" - so one definition turned every parser append into a walk of the document parsed so far.

**Why**: A per-agent counter keeps the common case fast only until the first definition; after that the cost is O(tree) per mutation and O(n^2) per parse. HTML names exactly what can change an owner or a disabled state: the inserted/removed/moved subtree, the ID a form attribute names entering, leaving or changing in a tree, the element's own form/disabled attributes, a fieldset's disabled attribute, and which legend is a disabled fieldset's first. Blink resets exactly those (ListedElement::InsertedInto/RemovedFrom, FormAttributeTargetObserver on an IdTargetObserverRegistry, HTMLFieldSetElement::DisabledAttributeChanged and ChildrenChanged).

**What Happened**: CE2-S1. The 2,500-section live parse took 109-138 s with one formAssociated definition (1.0-1.1 s without); 2,000 appendChild+remove on a 3,000-element document took 4.5-4.6 s (0.09 s without), and 12.7-13.5 s once one FACE had a form attribute. After the targeted resets: 0.86-1.16 s, 0.10-0.17 s and 0.08-0.11 s, with the 823-file targeted WPT list identical file by file.

**Fix**: html/custom_elements/form_owner.zig resets the moved subtree (shadow-including), the observers of IDs in it (an agent-level ID-target map, one hash lookup per ID, skipped while empty), and fieldset descendants for disabled/legend changes; children-changed steps reset nothing. Observers carry slab generation and realm and leave the map at element teardown and realm end. The owner is still derived from the tree on every reset, so built-in listed elements (derived on read) and FACEs agree; tests check them side by side.

**Takeaway**: **A "has any X" counter is a fast path, not a bound: once it trips, cost every mutation by what it can actually change, and derive that set from the spec's own triggers (and the engine that already implements them).**
