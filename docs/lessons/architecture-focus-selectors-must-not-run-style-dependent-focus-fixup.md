# Architecture: Focus selectors must not run style-dependent focus fixup

**Date**: 2026-10-17
**Lesson**: A focus selector must read the stored focus designation without asking computed style whether that designation is still focusable.

**Why**: Focusability can depend on computed style. A customizable select option needs `appearance: base-select`, and its visibility also comes from style. If matching `:focus` or `:focus-within` runs focus fixup, the cascade calls back into itself through that focusability check.

**What Happened**: Row 61's first Debug runner timed out on both `sel3-focus-style.html` and `sel3-focus-within-style.html`. The captured stacks repeated `matchesFocus -> currentlyFocusedArea -> focusedAreaOf -> optionFocusable -> computedStyle`. The same cycle blocked picker tests even without an author `:focus` rule, because the user-agent stylesheet contains one. The watchdog recorded TIMEOUT; the recursive stack alone was not a journal CRASH result.

**Fix**: Keep one read-only document designation helper, shared by selector matching, script focus reads, focus-action bookkeeping and popover focus reads. Follow the existing top-level document and frame descent, checking only liveness, connection, and node document. A removed element must stop matching immediately: HTML's synchronous removing steps are separate from the style-dependent fixup in update-the-rendering. The first attempt left fixup in script and action reads; seven paired rounds then measured ordinary focus/activeElement actions 124.48% slower. The correction follows HTML's actual read algorithms: `activeElement` and `hasFocus` read the designation, actions validate their explicit target, and rendering step 17 alone repairs a designation that stopped being focusable. Do not add a cascade recursion flag or change iframe matching semantics. Pin both selectors, immediate removal, designation reads before rendering, and the separate rendering fixup in tests; measure ordinary selector, focus-action and event-dispatch cost.

**Takeaway**: **State consulted by selector matching must not re-enter style resolution through a validity check. Separate the stored designation from the operation that repairs it.**
