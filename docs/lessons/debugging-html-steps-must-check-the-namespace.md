# Debugging: HTML attribute steps must check the element's namespace

**Date**: 2026-10-03
**Lesson**: Element's attribute change steps dispatched HTML-only steps (keyed by local name) to SVG and MathML elements, whose state is a different struct - a wild pointer that crashed 6 of 6 runs of a Trusted Types file.

**Why**: HTML's attribute change steps are defined for HTML elements; an SVG `<script>` or a foreign `<iframe>`-named element shares the local name but not the state layout. A hook table keyed by local name alone cannot tell them apart, and `getInternal` was an unchecked cast.

**What Happened**: set-attributes-*-default-policy created foreign elements named like HTML ones and set their attributes; `HTMLIFrameElement`'s steps read a foreign element's state as its own.

**Fix**: 44b7f2466: `attributeChangeSteps` returns unless the element is in the HTML namespace before `dom.attribute_change_steps.run`; ac83bcec2: `HTMLIFrameElement.getInternal` is `instance.stateAs(State) orelse null`. Crane test tt-foreign-element-attribute-steps.html.

**Takeaway**: **A step the HTML spec defines for HTML elements is keyed by namespace AND local name, and a state cast is checked, never assumed.**
