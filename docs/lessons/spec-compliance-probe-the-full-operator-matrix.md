# Spec Compliance: Probe the full operator matrix

**Date**: 2026-10-25
**Lesson**: When a browser's comparison grammar differs from the spec, test every operator pair and its negation before generalizing the result.

**Why**: A small positive probe can support an incorrect broad rule. Negation also distinguishes a valid false comparison from an unknown condition: unknown stays false at the top level even under not.

**What Happened**: Chrome accepted `1 = 1 = 1` and `1 < 2 = 2`, although the original CSS Conditional 5 range grammar permits only ascending or descending chains. It was tempting to allow equality throughout every chain. Reading Blink's `ConsumeStyleFeatureRange` together with `MediaQueryOperator` showed that the actual test used adjacent enum values. The complete 25-pair positive/negated probe confirmed that `=` followed by `<=` is rejected while `<=` followed by `>` is accepted.

**Fix**: Pin the measured matrix explicitly in native and script tests. The integrator's 1025k ruling applies that behavior because Chrome is the only shipping if() engine and the stricter grammar predates its implementation; a contradictory pinned WPT case would take precedence. The grammar uses an explicit acceptance table rather than depending on our own enum's ordinals. This is a compatibility decision, not a general mathematical rule.

**Takeaway**: **Read the constants behind a parser condition, then measure all combinations before turning examples into a rule.**

Design references (no code copied): [Blink range parser](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/css/parser/media_query_parser.cc), [operator enum](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/css/media_query_exp.h), and [the original spec change](https://github.com/w3c/csswg-drafts/pull/12401).
