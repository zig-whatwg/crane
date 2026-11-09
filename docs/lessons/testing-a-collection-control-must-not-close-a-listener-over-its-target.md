# Testing: A collection control must not close a listener over its target

**Date**: 2026-11-08
**Lesson**: In a Crane test that asserts a node IS collected, no event handler or listener of that node may close over the node (or over a scope that holds it): until refcount step 8 a listener is a strong engine root, so the control fails for a reason that has nothing to do with the edge it claims to test.

**Why**: Decision D7 makes listeners and observer callbacks values traced from their target's wrapper, as Blink and WebKit trace them. Crane has not made that switch yet: the binding clones the callback into an owned strong Global, so `img.onload = () => resolve(new WeakRef(img))` roots the closure, the closure's context holds `img`, and `img`'s wrapper holds its tree. crane/rc-self-capturing-listener-collected.html pins exactly that gap and is RED on base. A test written in the natural style - resolve a promise from the element's own load handler - inherits it silently.

**What Happened**: The wrapper redesign's P0 identity suite (lane wr1) gave each `wr-` file a negative control proving its collections are real. The pending-activity file's control made an `<img>` in a detached tree, resolved a promise from its `onload` with WeakRefs to the img and its root, and expected both collected after the load. It failed on base, [false, false]. Probes on the base runner separated the causes: an img with a load handler that closes over nothing, after its load fired, was collected; a `div` with `onclick = () => void d` or `addEventListener('click', () => void d)` was not, with no image loading at all. The img's pending activity was released correctly; the control's own handler was the root.

**Fix**: Give a control's handlers a function that reaches the node through nothing but its arguments (`this`, `event.target`) or a global, and hand results out through a global (`self.wrControlDone = () => resolve(made)`), not through a closure over the node. Create the WeakRefs in the test's own job, outside the handler. When a handler must close over its node, the test is about D7 and belongs with rc-self-capturing-listener-collected.

**Takeaway**: **A listener that closes over its own target is a root in Crane until refcount step 8: a collection control must never have one, or it measures D7 instead of the edge it names.**
