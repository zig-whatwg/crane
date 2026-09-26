# Testing: A drain guard keyed on a boolean strands a second document

**Date**: 2026-09-22
**Lesson**: Re-entrancy guards over per-document queues must record the
document, not a flag.

**Why**: A script run from a drain can insert a script into *another* document -
an iframe's, or one from `createHTMLDocument`. A global "already draining"
boolean suppresses that document's drain while nobody is walking its queues, and
the outer loop only ever rescans the document it was given, so the script sits
in the queue forever. The failure is a hang, not a crash, and only on pages with
two documents.

**Fix**: `var draining_document: ?*runtime.Instance`, compared against the
document being asked for. A different document nests (bounded by an explicit
depth cap for the mutually-recursive case); the same document returns and lets
the outer loop pick the new entry up.

**Takeaway**: **A guard against re-entrancy has to be as fine-grained as the
state it protects, or it turns recursion into deadlock.**
