# Spec Compliance: A reflection cache is separate from the last assignment

**Date**: 2026-10-14
**Lesson**: An element-reference array setter replaces its explicit list; the getter updates the cached frozen array only when observed contents change.

**Why**: HTML 2.6.1 gives the reflected target both explicitly set elements and cached associated elements. Combining these slots makes unobserved assignments change object identity incorrectly.

**What Happened**: A first implementation plan cached a new frozen array at every assignment. Setting [a], reading it, then setting [b] and [a] without an intervening read would return a different object despite the getter still seeing the same contents. It also risks retaining an input array that script can mutate.

**Fix**: Convert each iterable item to Element before advancing, retain converted values across later iterator code and GC, and copy the complete input before committing. Keep explicit and cached lists separately. Let the getter compare contents and preserve the cached object when equal, including the null-versus-empty case. The existing traced-value protocol keeps frozen snapshots alive; generation checks on native identities cover teardown. Test duplicates, equal-content reassignment, unobserved intermediate writes, iterator exceptions and reentrant setters.

**Takeaway**: **Keep the spec's explicit value and observation cache separate, and validate before replacing either.**
