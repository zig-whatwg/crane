# Spec Compliance: Check source when cached Markdown drops grammar

**Date**: 2026-10-25
**Lesson**: Confirm suspicious punctuation-dependent grammar in the spec's source before interpreting a converted Markdown sentence.

**Why**: A format conversion can lose literal syntax while leaving a sentence that still reads naturally but means something broader.

**What Happened**: CSS Values 5 §3.1.1 in the cached Markdown restricted top-level “commas or blocks.” The Bikeshed source explicitly said “commas or {} blocks.” Treating the converted sentence literally rejected valid square and round blocks in if() values. The existing pending-value helper repeated that interpretation, so copying its design would have repeated the defect.

**Fix**: Read the full upstream change, [csswg-drafts e6c29632](https://github.com/w3c/csswg-drafts/commit/e6c29632edd757f5b6902b30d2e2bc9377809da0) (2026-04-06), then add a failing native case for `[a;b] (x:y)` before fixing the parser. Keep browser behavior decisions separate: the if() branch-brace preservation decision came from the three-browser probe, not from this conversion issue.

**Takeaway**: **A missing pair of braces can change the grammar. Use the original source to resolve conversion ambiguity.**
