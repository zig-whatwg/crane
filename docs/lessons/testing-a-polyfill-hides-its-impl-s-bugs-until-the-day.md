# Testing: A polyfill hides its impl's bugs until the day it is removed

**Date**: 2026-09-25
**Lesson**: WorkerLocation's getters returned the internal location's own slices. The binding frees what a getter returns, so the second read of `location.search` was a double free. It never ran while the worker global's `location` was a JavaScript polyfill.

**Takeaway**: **When a native or polyfill gives way to a bound impl, read each of its getters twice before trusting it.**
