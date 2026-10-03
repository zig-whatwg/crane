# Architecture: Key conversion results own their arrays

**Date**: 2026-10-03
**Lesson**: A key returned by recursive conversion must own every allocated child and its array storage.

**Why**: Returning a slice into a conversion function's stack makes its contents invalid as soon as that function returns. Borrowed string or binary children also cannot survive the input value's lifetime.

**What Happened**: IndexedDB's legacy key conversion returned a borrowed array backed by a local 256-key buffer. Index key generation used that path, while multiEntry conversion allocated an array without attaching its allocator. New allocator-backed tests exposed invalid array results and leaked nested keys. The index implementation also discarded nested array subkeys, although the specification unpacks only the outer array.

**Fix**: Route extraction through the owning converter, state the ownership contract on the public result, and release generated index keys after entries clone them. Keep a cleanup guard on each child until append succeeds. Retain valid nested arrays as individual index keys.

**Takeaway**: **Ownership applies recursively: an owned array result must own its storage and every child.**
