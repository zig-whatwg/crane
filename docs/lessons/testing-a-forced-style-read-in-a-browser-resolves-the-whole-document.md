# Testing: A forced style read in a browser resolves the whole document - one element's read gives every element a before-change style

**Date**: 2026-11-07
**Lesson**: In Blink and Gecko, `getComputedStyle(a)` flushes the whole document's pending style, so every element - not just `a` - has a current style afterwards; a test that reads one element and then changes another expects the other to start a transition from its before-change style.

**Why**: CSS Transitions need a before-change style. Crane resolves style lazily per lineage: a read of `a` resolves `a` and its ancestors only, and elements never read (and not yet reached by a step-16 update) have no before-change style, so their first change starts no transition.

**What Happened**: css/css-animations/animation-important-with-transition.html reads target1 in its first test, then (with no frame in between) changes target3's and target4's classes and expects CSSTransitions on them. In isolation (a read or a frame first) Crane passes all of it; in the file the two subtests fail: target3 and target4 were never resolved. This is batch 2's stated deviation 1 seen from a document that DOES declare transitions.

**Fix**: Not fixed in batch 3 (queued): the browsers' behaviour is a document-wide update at a read whose inputs moved, in a document that declares transitions; its cost is the step-16 walk's (~2 us per element) per such read, which needs a measurement and a ruling first.

**Takeaway**: **When a transition test fails only in its file, check whether the element was ever resolved before its change: a browser's read resolves every element, Crane's only the lineage it reads.**
