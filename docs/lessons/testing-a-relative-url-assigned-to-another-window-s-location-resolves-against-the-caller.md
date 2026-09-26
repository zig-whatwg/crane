# Testing: A relative URL assigned to another window's location resolves against the caller

**Date**: 2026-09-26
**Lesson**: `frame.contentWindow.location.href = "x.html"` resolves "x.html" against the entry settings object - the script doing the assigning - not the frame.

**Why**: HTML's Location setters parse against the entry settings object's API base URL.

**What Happened**: A new crane test assigned a URL written relative to the frame; the page loaded the parent directory's `x.html`, a 404, and the test read as an engine failure.

**Fix**: Write the URL relative to the assigning script.

**Takeaway**: **Write the URL relative to the script doing the assigning.**
