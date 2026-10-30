# Testing: Extend characterization without replacing its history

**Date**: 2026-10-28
**Lesson**: When a characterization enumerates a type, a new member needs its own expected output while every existing member's expectation stays intact.

**Why**: A frozen characterization can protect an implementation migration and still enumerate the current type. Adding an enum member changes the output's shape even when all old behavior is preserved. Regenerating the entire golden file would also accept unrelated behavior changes.

**What Happened**: The computed-style storage characterization writes every Longhand's initial value before its case blocks. Adding will-change made its first mismatch an extra `will-change: auto` where the golden expected the first case heading. The original golden described 250 longhands; the new type had 251. That first mismatch alone said nothing about later case values.

**Fix**: Read the complete renderer and its assertion. Independently pin the new member's initial value, then add only its expected lines in enum order. New-member lines may also belong inside existing cases when their values differ from the initial baseline. Preserve every old member's line, case heading, renderer and assertion byte-for-byte. Run the unchanged full comparison afterward. Any old-member difference needs its own explanation and ruling; it is not part of extending the characterization.

**Takeaway**: **Add expectations for new members without replacing the evidence that protects old behavior.**
