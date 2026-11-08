# Testing: A substituted argument the grammar rejects is unset, not dropped

**Date**: 2026-11-08
**Lesson**: When a characterization test pins "a substitution function gives what its chosen argument written directly gives", an argument the property's grammar rejects is the exception: substituted, it is invalid at computed-value time (`unset`); written directly, the declaration is invalid at parse time and dropped, so a lower declaration wins.

**Why**: Values 5 "replace substitution functions in a property" parses the substituted text with the property's grammar at computed-value time (step 3: failure makes the declaration invalid at computed-value time, which behaves as `unset`). The same text in the source is rejected by the parser, and the cascade never sees it. The two forms agree for every valid argument and disagree for every invalid one.

**What Happened**: Lane forms1 batch 2 made the UA sheet's `-internal-auto-base(<native>, <base>)` declarations parse both arguments when the sheet is built. Its characterization test compared each html.css declaration, in eight appearance contexts, with its chosen argument written directly. The run at the base tree passed every html.css shape and failed the first added edge case, `min-width: -internal-auto-base(red, 2px)`: the direct `min-width: red` was dropped and the earlier rule's `12px` won, while the substitution gave `auto`. The engine was right; the test's equivalence was wrong.

**Fix**: In the characterization, compare a rejected argument against `P: unset` (parse the direct form first; when it yields no declaration, expect `unset`), and keep a separate test that pins `unset` in every appearance. The eager parse stores a rejected argument as null and selects `unset` for it, as the substitution's `.invalid` outcome does.

**Takeaway**: **Substitution moves validity to computed-value time: a rejected argument is `unset`, not an absent declaration - pin that, not the direct form.**
