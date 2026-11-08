# Spec Compliance: A parser depth cap is decided at its edges - probe every node kind there

**Date**: 2026-11-08
**Lesson**: All three browsers cap the HTML parser's DOM depth, but not the same way at the boundary: measure elements, void elements, self-closing foreign elements, comments and text at the limit in each browser before choosing, because golden rule 2 then decides mechanism by mechanism, and the per-mechanism majorities may combine into no browser at all.

**Why**: Blink's HTMLConstructionSite::Attach checks `StackDepth() > 512 + 1` with the node already pushed for ordinary elements but not for void elements, `<svg/>` or comments, so those land one level deeper; Gecko's nodeFromStackWithBlinkCompat caps elements and voids at the same node and never caps comments; WebKit caps everything uniformly one level shallower. Text is capped by none. A test of nested divs alone (512 / 512 / 511) shows none of this.

**What Happened**: Lane crash1 batch 2 probed Chrome 157, Firefox 159 and Safari 27.2 (tmp/crash1/probe/depth2.html). The majorities were limit 512 (C, F), voids like elements (F, S), comments capped (C, S), text uncapped (all) - no shipping browser combines them. The integrator ruled Blink's mechanism whole: when the majorities do not combine, the rule falls back to the spec, which has no cap; every browser departs from it for nested elements, so Crane departs only as one real browser does. The same probe settled the XML parser: all three parse 5,000 nested elements and fail at 5,001 ("Excessive node nesting.", Blink kMaxXMLTreeDepth).

**Fix**: src/html/parser/tree_builder.zig `depthBounded` with Blink's counts (pushed elements count themselves; void, self-closing foreign and comment insertions do not; text and foster parenting are never bounded); src/xml/parser.zig `max_element_depth` 5000; tests pin Chrome's measured trees at 512 and 513 open elements.

**Takeaway**: **Before implementing a browser limit the spec does not have, probe each node kind at the exact boundary in all three browsers; if the per-mechanism majorities match no single browser, take one browser's mechanism whole rather than a combination nobody ships.**
