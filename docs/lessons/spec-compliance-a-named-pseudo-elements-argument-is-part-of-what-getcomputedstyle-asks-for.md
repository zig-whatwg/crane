# Spec Compliance: A named pseudo-element's argument is part of what getComputedStyle asks for

**Date**: 2026-11-18
**Lesson**: getComputedStyle(el, "::view-transition-group(root)") and "::highlight(foo)" name one pseudo-element each; a style engine keyed on the pseudo-element's name alone styles every name with every name's rules.

**Why**: Crane's getComputedStyle kept only the lowercase pseudo-element name ("view-transition-group", "highlight"), and its selector parser kept no argument for those pseudo-elements. Rule matching compared names only, so `::view-transition-group(foo) { animation-duration: 3s }` reached group(root), and `::highlight(bar)` reached highlight(foo). Nothing failed loudly: the styles were simply the union of every named rule.

**What Happened**: css-view-transitions/computed-style-no-active-transition.html read 3s for group(root) (generation 229: 0/3). The fix (lane css1, 9ef2a68bd22): the parser keeps the <pt-name-selector> name (null for `*`) and the classes, and ::highlight()'s name; getComputedStyle's target carries the argument ("view-transition-group(root)", "highlight(foo)", `*` as "()" so an escaped `\*` - the ordinary name "*" - stays apart); the matcher compares it (selector_matching.pseudoTargetMatches). Specificity follows: a named view transition pseudo-element with a name or a class is a type selector's, `*` alone zero.

**Fix**: For a functional pseudo-element whose argument NAMES the pseudo-element (not a filter like ::slotted()'s compound), carry the argument through every layer that identifies the pseudo-element: the parsed selector, the engine's target string (and its per-element pseudo cache key), and the matcher.

**Takeaway**: **A pseudo-element "name" in an engine is (name, argument) for ::highlight() and the named view transition pseudo-elements - drop the argument anywhere and every name's rules style every name, silently.**
