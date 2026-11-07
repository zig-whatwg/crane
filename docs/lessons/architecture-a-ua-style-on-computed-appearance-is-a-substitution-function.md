# Architecture: A UA style conditional on computed appearance is a substitution function, not a selector

**Date**: 2026-11-07
**Lesson**: When the spec conditions UA styles on an element's own COMPUTED value (HTML 15.5.16: "styles expected to apply when the select is rendered with base appearance"), no selector can express it; Blink and WebKit both write such blocks as a UA-only arbitrary substitution function chosen after that one property is computed.

**Why**: A selector matches before the cascade, so `select:-x-base { display: inline-flex }` would have to know the select's `appearance` before computing it - the cycle the spec's prose hides. Splitting the property out of the cascade instead (computing `appearance` first for every element) makes every element pay for what a few selects need.

**What Happened**: Lane forms1 (batch 1) needed HTML 15.5.16's base-appearance blocks for 3 blocking customizable-select files. Blink's html.css writes `display: -internal-auto-base(inline-block, inline-flex)`, resolved in StyleCascade::ResolveAutoBaseInto after `LookupAndApply(appearance)` with a cycle check, plus StyleAdjuster's inherited InBaseAppearance bit (set on a select that has base appearance, cleared on a nested select); WebKit's html.css and Style::SubstitutionResolver do the same. Crane's vars1 substitution engine ("a function is one row") took it as a row restricted to UA sheets (`user_agent_table`; Blink's CSSVariableParser accepts kInternalAutoBase only in kUASheetMode), `appearance` resolved on demand behind a guard, and a UA-only `:-internal-list-box` for list box versus drop-down. The options' half needed one more piece: a drop-down select's children inherit from its ::picker(select) (the spec's select popover slot), so "the select's contents are rendered with base appearance" needs the picker to be base too. The three files unblocked on the first Debug run (8 of 9 subtests of the computed-style file; the 9th needs calc-size()), and the picker parent unblocked a fourth, select-picker-exit-animation.html, whose option takes its colour from ::picker(select).

A trap on the way: the cascade unit tests first checked the function through `display`, and got `block` - a root element and a child of an inline-flex select are blockified (Display 4 2.7). A substitution test reads a property no adjustment touches (`min-width`).

**Fix**:
1. A UA-only row in src/css/substitution.zig (`-internal-auto-base`), parsed only when `ParseOptions.user_agent` (properties.zig, pending_values.zig).
2. src/css/cascade.zig: `ensureAppearance()` (computed once, early when asked; `.resolving` makes a self-referencing `appearance` invalid), `hasBaseAppearance()` from `Context.appearance_support` (select, picker, none) and the parent's `in_base_appearance`, set in `adjust()`.
3. src/dom/style/engine.zig: fill `appearance_support`; make the picker the flat-tree parent of a drop-down select's children (not a first-child button).
4. html.css: write the native value as `revert-rule` where the spec's block has no native counterpart, so the cascade is as if the base rule did not exist.

**Takeaway**: **A UA style that depends on the element's own computed value belongs in a UA-only substitution function resolved after that value, as Blink and WebKit do - not in a selector, and not in an early pass every element pays for. Test a substitution through a property no adjustment touches.**
