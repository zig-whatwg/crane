# Architecture: curl's header callback delivers every header block

**Date**: 2026-09-25
**Lesson**: The header callback delivers 1xx blocks and trailers as well as the final block, so a response's headers are only the final block's lines, up to its blank line.

**What Happened**: trailers were read as headers, and `getresponseheader-chunked-trailer.htm` failed 0/1 until the scheduler tracked block boundaries (the networking lane, ae9ffd4b2).

**Takeaway**: **Track header-block boundaries in the callback; a header line alone does not say which block it belongs to.**
