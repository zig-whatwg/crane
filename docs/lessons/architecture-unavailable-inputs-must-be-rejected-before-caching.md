# Architecture: Reject unavailable inputs before caching their results

**Date**: 2026-10-28
**Lesson**: An unavailable numeric input must be detected before a computed value or a substitution choice enters shared storage.

**Why**: A scalar evaluator may need a numeric placeholder to finish safely when a host cannot supply geometry. If a shorthand caches a choice made using that placeholder, later consumers can reuse it with a clean availability note and mistake it for a real result.

**What Happened**: Row 127's container support needed to distinguish small-viewport fallback from eligible-but-unavailable geometry. The first native HTML run showed unavailable scalar values winning instead of lower declarations. The next run showed a `random-item` key caching `12px` across a margin shorthand instead of preserving the four lower side values. Registered scalar lists and unregistered custom text had equivalent storage boundaries. Ordinary longhand lengths may remain unresolved for geometry consumers. Registered custom values cannot: their computed length belongs to the declaring element, and retained relative text would be reinterpreted in a descendant's context. A mixed-writing-mode inheritance audit exposed that distinction (Q104).

**Fix**: Carry a borrowed, synchronous note through existing math contexts. Bind a fresh stack note for each candidate and restore the enclosing note on every exit. Apply one availability rule before longhand storage, typed custom serialization, and pending substitution caching. Cache the existing unavailable outcome when control math lacks its input. A registered invalid value still defaults; any registered unavailable candidate, length or scalar, instead retries the exact next declaration, preserving revert bookkeeping. Unregistered custom properties remain token text computed at the consumer. Keep that distinction in a private return record rather than a persistent value flag. Test multiple shorthand consumers, lower candidates in the same layer, lists, union syntax, unused branches, clean outer notes and allocation failures.

**Takeaway**: **Availability belongs to the computation that made the decision; reject an invalid placeholder at every cache boundary it can cross.**
