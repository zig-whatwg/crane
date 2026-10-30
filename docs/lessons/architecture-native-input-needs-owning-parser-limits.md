# Architecture: Native Input Needs the Owning Parser's Limits

**Date**: 2026-10-27
**Lesson**: An iterative native input adapter must preserve the limits that keep the existing downstream algorithms safe.

**Why**: Bypassing tokenization also bypasses its depth and parser-call counters. An iterative adapter can create a tree that a recursive downstream simplifier or copier was never designed to receive.

**What Happened**: Typed OM's graph snapshot was iterative and its ordinary numeric graph traversal supported deep constructor graphs. The property input path then called the existing math Builder.simplify and compute-time Builder.copy. A5000-level unresolved min/max constructor graph could reach those recursive functions without passing through Parser.nested's128-depth/4096-call budgets. Q85 authorized shared numeric ceilings at the native property entry, under CSS Values4 §10.8; ordinary numeric objects retain their unrestricted graph behavior.

**Fix**: Share the parser's named constants and check them during the same snapshot walk when used for property input. Reject before further expansion or property mutation, translate the invalid value to TypeError, and preserve OutOfMemory. Keep the raw snapshot and numeric object algorithms separate from the property-only limit. Q89 clarified that the units differ: the text parser counts function and primary calls, while the property walk counts operation depth and expanded operations. Measure each boundary separately, keep the text parser unchanged, and test the guaranteed32-level mixed graph round-trip. Pin accepted boundary values, rejected depths and operation counts, atomic rollback and allocation failure cleanup.

**Takeaway**: **An adapter must preserve downstream preconditions as well as its own memory safety.**
