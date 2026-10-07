# Testing: Parser fixtures need explicit and implicit document roots

**Date**: 2026-10-07
**Lesson**: Ownership tests for tree construction must exercise both explicit tokens and implied nodes.

**Why**: An explicit html token and the implicitly created document element take different insertion paths. Both must transfer ownership when their node enters the document tree.

**What Happened**: Small template fixtures with an implied root passed. The whole template WPT directory then produced 19 crashes because an explicit root remained on a detached-node cleanup list after joining the document, so teardown freed it twice.

**Fix**: Release the explicit root from detached ownership immediately after insertion. Add an explicit-root parse-and-teardown regression under std.testing.allocator, and repeat the whole directory instead of relying on the small fixtures alone.

**Takeaway**: **An ownership transfer must cover every creation path; test implicit and explicit nodes.**
