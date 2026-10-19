# Spec Compliance: Selected text keeps its rendering context

**Date**: 2026-10-18
**Lesson**: Bound rendered text with source offsets while preserving the surrounding text that controls whitespace and casing.

**Why**: A selected space can survive because unselected text precedes and follows it. Capitalization can depend on preceding inline text, and a case mapping can expand one DOM code unit into multiple output characters. Cutting the input substring before rendering loses that context; slicing rendered bytes with DOM offsets uses the wrong coordinate system.

**What Happened**: Selection.toString delegated to Range's raw descendant text. Sharing the innerText collector required more than filtering text nodes: a partially selected space in `one  two`, the inline `bc` in `a<span>bc</span>`, and uppercase `ß` all need the original text context and positions.

**Fix**: Collect text with per-run UTF-16 source bounds. Transform the complete runs, mapping selected offsets through each transformation. Feed unselected prefix and suffix text through the same whitespace processor without emitting their characters. Keep ordinary innerText specialized without range metadata, and keep Range.toString's DOM concatenation separate. The bounded collector test also injects every allocation failure.

**Takeaway**: **Selection bounds decide what is emitted, not all of the text that rendering must inspect.**
