# Architecture: A cache keyed on its source string must update the source on every write path

**Date**: 2026-09-26
**Lesson**: `Location` re-parses its URL only when the document's URL string differs from the one it cached, and `setURLFromString` changed the URL record without changing that string.

**Why**: One writer updated the value but not the key the cache compares.

**What Happened**: Going back over a fragment navigation compared equal to the stale string and kept the fragment.

**Fix**: Every write path sets both the record and its source string (lane/navigation).

**Takeaway**: **Every writer of the value must also write its key.**
