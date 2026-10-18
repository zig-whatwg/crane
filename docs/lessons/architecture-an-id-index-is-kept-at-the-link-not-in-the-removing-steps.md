# Architecture: An ID index is kept at the link, not in the removing steps

**Date**: 2026-10-18
**Lesson**: A tree scope's ID and named-property maps must change at the point the node is linked or unlinked, before any other step of the same mutation can read them - not in a registered insertion or removing steps callback.

**Why**: The spec's getElementById is a walk of the tree, so every step of a mutation sees the tree as it is after the link or unlink. An index that changes later than that answers a step that runs earlier with the old tree. In Crane's `mutation.remove`, `formSubtreeMoved` (HTML's form owner reset, and the form-attribute ID observers through `form_associated.firstElementWithId` -> `getElementById`) runs BEFORE `runRemovingSteps`; and the insertion steps run node by node, so an earlier node's step would miss a later sibling's ID.

**What Happened**: Lane domindex1 replaced getElementById's walk with Blink's TreeOrderedMap design (a count per key and a lazily re-found first element). The first idea was to keep the maps from `registerInsertionStepsCallback`/`registerRemovingStepsCallback`, which needs no change to mutation.zig. Reading the removal order showed that an `<input form=f>` outside a removed `<form id=f>` would be re-associated with the removed form: the reset reads the ID map before the removing steps take the form out. Blink and WebKit update their maps in `InsertedInto`/`RemovedFrom`, before `IdTargetObserver` notification, for the same reason.

**Fix**: `src/dom/tree_ordered_map.zig`'s `inserted`, `removed` and `moved`, called by mutation.zig right after `linkChild`/`unlinkChild` (and `insertIntoChildrenList` for move), walk the moved node's light subtree once and find the scope once, from the parent's root. Element calls `beginChange`/`endChange` around its id cache update. `crane/domindex1-getelementbyid.html` pins the form-owner case. The maps hold links (instance and slab generation), and an allocation failure while they change empties them and makes every reader walk until a rebuild succeeds: exact or walk, never a stale answer.

**Takeaway**: **An index of the tree is part of the tree's state: update it where the tree changes, not in the steps that run after, because some of those steps read it.**
