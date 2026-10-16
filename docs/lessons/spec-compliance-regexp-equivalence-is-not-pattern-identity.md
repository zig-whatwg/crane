# Spec Compliance: Regexp equivalence is not pattern identity

**Date**: 2026-10-12
**Lesson**: URLPattern classifies a segment wildcard by the exact generated regexp spelling.

**Why**: The parser's part type controls both serialization and the script-visible `hasRegExpGroups` property. Equivalent regular expressions need not have the same part type.

**What Happened**: The parser recognized hard-coded `[^/]+?` and `[^.]+?` strings, while the regexp generator escaped their delimiters. It classified the spec's generated spellings as custom regexp parts and the unescaped spellings as segment wildcards. The shortcut also ignored other delimiter options.

**Fix**: Use the same segment-wildcard generator when initializing the parser, then compare exact strings in add-a-part step 11. Test both generated spellings and equivalent unescaped spellings, including a nonstandard delimiter. Keep allocation-failure coverage for the parser-owned generated string.

**Takeaway**: **When a spec defines identity through a generator, share that generator rather than approximating its output.**
