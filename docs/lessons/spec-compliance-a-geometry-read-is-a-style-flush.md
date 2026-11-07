# Spec Compliance: A geometry read is a style flush, or a transition never starts

**Date**: 2026-11-07
**Lesson**: In a style system that resolves only what is read, every API the browsers update style at must resolve too, or a later change has no before-change style and no transition starts.

**Why**: CSS Transitions start at a style change event, from the before-change style. Browsers resolve style (and layout) at every layout-dependent read: Blink's Element::GetBoundingClientRect, Element::OffsetWidth and HTMLElement::offsetWidthForBinding begin with Document::UpdateStyleAndLayoutForNode. Tests use such a read as "the style is computed now" before changing a property. Crane resolved on getComputedStyle and at rendering opportunities only, so a getBoundingClientRect at parse time left the element unresolved.

**What Happened**: Five dom/nodes/moveBefore/continue-css-transition-* and css-transition-* files timed out waiting for transitionstart. Lane move1 probed one element three ways at parse time: getComputedStyle first -> transitionstart; getBoundingClientRect first -> none; no read -> none. css/css-transitions/properties-value-* (offsetWidth after getComputedStyle, 2,004 subtests) had the same cause.

**Fix**: `dom.style.engine.updateStyleForRead(element)`: update the rendering 16.2.1's gated "recalculate styles" for the element's node document, in its realm, called first by getBoundingClientRect, getClientRects and the offset*, client* and scroll* getters. Gated by the inputs key (no-op when nothing moved) and by the document declaring transitions or animations (elsewhere a resolution is unobservable). A test creates its element inside the script, so no earlier resolution can give it a before-change style.

**Takeaway**: **List the reads the browsers flush style at and make each one resolve: a pull style system that waits for getComputedStyle misses every transition a geometry read was meant to arm.**
