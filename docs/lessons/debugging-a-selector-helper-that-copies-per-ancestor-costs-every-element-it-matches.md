# Debugging: A selector helper that copies per ancestor costs every element it matches

**Date**: 2026-11-08
**Lesson**: A predicate that selector matching calls per element - and that walks the ancestors - must read element data in place: one allocating getter per ancestor turns a handful of new UA rules into a multiple of the page's style cost.

**Why**: Selector matching runs for every element on every style resolution. `:enabled` and `:disabled` reach `form_associated.isDisabled`, which walks every ancestor for a fieldset, and its `isElementNamed` read each ancestor's local name through `Element.get_localName` - an owned DOMString copy, freed at once. In the WPT runner's debug allocator every such copy is an allocation and a free, sometimes an mmap/munmap pair.

**What Happened**: Lane forms1 batch 1 added HTML 15.5.16's base-appearance UA rules, among them `select option:enabled:hover`, `select option:disabled` and the drop-down select's `:enabled`/`:disabled` rules. Its cost pair (crane/forms1-computed-style-cost.html: 200 selects, 800 options and optgroups) went 316 -> 2,774 ms. The design blamed the substitution of `-internal-auto-base()` values, and batch 2 fixed that first (both arguments parsed with the UA sheet): 2,774 -> about 1,900 ms. A `sample` of the runner on the cost page then put 620 of 782 computedStyle samples in `pseudo_classes.disabledState -> isDisabled -> isElementNamed -> DOMString.clone` and the allocator. Reading the local name in place took the select page to about 780 ms, and the page with no select at all from about 1,290 to 880 ms - `:focus`'s navigable-container test used the same helper.

**Fix**: Compare `dom.element_data.of(node).local_name` in place (as `hasControlName` already read attributes). Then profile the cost page again before calling the rest structural: what remained was the drop-down select's ::picker(select) style, which HTML 15.5.16 (and Blink's UA shadow popover) makes every option's parent.

**Takeaway**: **In anything selector matching calls, an IDL getter that returns an owned copy is an allocation per element per ancestor - read the element's data in place, and profile the page before trusting the design's suspect.**
