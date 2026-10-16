# Spec Compliance: XPath predicates use axis order before union

**Date**: 2026-10-14
**Lesson**: Filter each context node's axis in its own direction before deduplicating and sorting the merged node set.

**Why**: XPath positions belong to an axis, not to a globally sorted intermediate list. Reverse axes count from the context node outwards. A location-step predicate and a FilterExpr therefore have different positional contexts.

**What Happened**: Implementing the XPath surface required distinguishing `div/i[1]` (the first `i` under each `div`) from `(div/i)[1]` (one first node). Likewise `preceding::i[1]` selects the nearest preceding `i`, whereas `(preceding::i)[1]` selects the first in document order. Sorting or combining the candidates too early produces plausible but incorrect answers.

**Fix**: Build one context node's axis in forward or reverse order, apply each predicate with the current position and size, then merge, deduplicate and sort in document order. A FilterExpr sees that sorted result. Keep the evaluation context local so nested functions and predicates cannot overwrite an outer position.

The rules are XPath 1.0 §§2.1, 2.4 and 3.3. Browser design reference: WebKit `Source/WebCore/xml/XPathStep.cpp`, `Step::evaluate` and `Step::nodesInAxis`. `crane/xp2-node-sets.html` covers the distinctions; upstream `domxpath/predicates.html` and `domxpath/node-set-tree-order.html` check nested contexts and unions.

**Takeaway**: **Ordering is part of XPath's evaluation context, not merely a presentation choice for the result.**
