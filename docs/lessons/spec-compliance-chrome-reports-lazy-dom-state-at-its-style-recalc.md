# Spec Compliance: Chrome reports lazy DOM state at its style recalc - an eager DOM defers those CDP events to the rendering update

**Date**: 2026-11-23
**Lesson**: Some of Blink's DevTools DOM events come from work Blink does lazily - slot distribution, pseudo-element creation, inline-style revalidation - so they arrive after the script task, at the next lifecycle update or a zero-delay task; an engine that does that work eagerly (as the DOM standard says) must hold the events and send them where Blink would, or the client sees Chrome's events in another order.

**Why**: Blink recalculates slot assignment and makes PseudoElement nodes during style recalc (HTMLSlotElement::NotifySlottedNodesOfFlatTreeChange -> probe::DidPerformSlotDistribution; Element::UpdatePseudoElement -> probe::PseudoElementCreated), and batches inline-style changes in InspectorRevalidateDOMTask (a one-shot zero-delay timer). Crane assigns slots in the DOM's "assign slottables" at the mutation, and computes style on demand.

**What Happened**: Lane cdpd1 sent distributedNodesUpdated and pseudoElementAdded/Removed from the rendering update's style step (dom.inspector_probes.renderingUpdated in update_the_rendering.styleAndLayout), in Blink's recalc order (an element's ::marker, ::backdrop, ::before, its children, then ::after), and inlineStyleInvalidated from a task on the document's event loop. A node inserted is sent with no pseudo-elements (Blink's are made by the next recalc), and the agent asks for a frame after a bound insertion or attribute change so the recalc comes.

**Fix**: For each CDP event, find the Blink call site of its probe and the lifecycle phase it runs in; when Crane does the work at another time, keep a pending set and flush it at the matching point (rendering update, posted task), and prove the order with a trace against Chrome.

**Takeaway**: **Match where Chrome's probe fires, not where the DOM change happens: lazy Blink work (style recalc, revalidation tasks) means a deferred CDP event in an eager engine.**
