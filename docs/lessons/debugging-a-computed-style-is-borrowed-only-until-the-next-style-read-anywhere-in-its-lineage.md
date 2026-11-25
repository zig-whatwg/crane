# Debugging: A computed style is borrowed only until the next style read anywhere in its lineage

**Date**: 2026-11-24
**Status** (2026-11-24, lane cs1): superseded for callers - `dom.style.computedStyle` now answers a `HeldStyle` that stays valid until released, whatever is read meanwhile; the raw borrow this lesson describes is `resolvedStyle`, private to src/dom/style/engine.zig, where it still holds. See architecture-a-borrow-the-next-call-can-free-is-a-hold-in-the-type-not-a-comment.md.
**Lesson**: `style.computedStyle` returns a pointer that is valid only until the next style read of that element - and a read of any descendant counts, since it walks the lineage from the root and resolves every volatile ancestor again. Read every value you need into locals before calling anything that may read style (`rendered()`, `isBeingRendered*`, `hasBox`, a child's style).

**Why**: The engine caches one ComputedStyle per element and `ElementStyle.setCached` destroys the previous one when it stores a new one. A style that read per-element dynamic state (a formish element matched against `:checked`, `:default`, `:invalid`, `:read-write`... - `selector_matching.readsVolatileState`) is marked volatile and resolved anew on EVERY read, and a volatile parent makes the whole lineage below it resolve again. So "the next read" frees the pointer for exactly the elements whose style depends on state, which on an ordinary page are form controls - and only when a second read happens between the borrow and its last use.

**What Happened**: Lane a11y1's role batch made WebDriver's computed role build the CDP accessibility tree. Its A/B passed every production file but the bug-finding runner crashed on css/css-display/accessibility/display-contents-role-and-label.html: `hiddenViaStyle` borrowed a `<button style="display: contents">`'s style, called `rendered(element)` (which reads it again: volatile, re-resolved, the first one destroyed), then read `visibility` from the freed one. The production build read the stale bytes and got the right answer by luck. A devtools unit test (a display:contents button, a page rule `:checked{...}`) crashed at `0x5555...` - std.testing.allocator's poison - on the same line, every run; reading visibility and display into locals before `rendered()` made it green.

**Fix**:
1. In a function that reads a computed style, copy each value (`keyword(...)`, `display()`, a slice you need) into a local first, then call anything else that may read style.
2. Never hold a `*const ComputedStyle` across a call into another style-reading helper, including a read of a child (lineage re-resolution).
3. To make it red, give the element a volatile style: a formish element (button, input, select...) and a page rule with a state pseudo-class such as `:checked`; the unit test allocator's poison then faults deterministically.

**Takeaway**: **A computed style pointer lives until the next style read of its lineage; read what you need into locals first - production hides the use-after-free, only the poison (unit tests, the bug-finding run) shows it.**
