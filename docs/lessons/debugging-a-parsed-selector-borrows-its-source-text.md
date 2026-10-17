# Debugging: A parsed selector borrows its source text

**Date**: 2026-10-17
**Lesson**: `selector.parse` decodes only escaped tokens; every other name in the AST is a slice of the text it parsed, so a SelectorList kept past its call must keep its text too.

**Why**: The parser was written for querySelector, matches() and closest(), which parse, match and free within one call. Nothing had kept a parsed selector longer than its source, so the borrow was never visible.

**What Happened**: The style engine (lane style1) compiled each style rule's selector once and kept it in the sheet's rule set, parsing from the rule's prelude, which `css.rules.parseStyleSheetContents` owned and the compiler freed once the sheet was compiled. Every type, class and id name then pointed into freed memory: no UA rule and no author rule matched (getComputedStyle answered initial values everywhere), while the style attribute - no selector - applied. The reads were of freed memory, so a different allocator pattern could have matched garbage or crashed instead.

**Fix**: Each compiled `StyleRule` owns a copy of its prelude and parses from it (src/dom/style/sheet.zig); the copy is freed with the rule.

**Takeaway**: **Before keeping a parse result, find out what it borrows: an AST of slices lives no longer than its source.**
