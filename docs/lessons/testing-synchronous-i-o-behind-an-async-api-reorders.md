# Testing: Synchronous I/O behind an async API reorders script against the parser

**Date**: 2026-09-25
**Lesson**: A file failing on `null` from `document.body`, or from an element later in the page, may be failing on ordering rather than on a missing feature.

**Why**: While `fetch()` blocked, `fetch(...).then(...)` settled at the end of the first script, before the parser had reached the elements after it.

**What Happened**: `event-handler-attributes-frameset-window.html` went from ERROR 0/0 to OK 376/376 when fetch became asynchronous. Nothing about event handlers changed.

**Takeaway**: **Before chasing a feature a whole file seems to lack, check what an API that should be asynchronous is doing synchronously.**
