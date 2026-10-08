# Architecture: Load-delay notification is not permission to run script

**Date**: 2026-10-08
**Lesson**: A synchronous load-delay notification may update readiness and queue work, but parser and deferred-script continuation belongs to a document task.

**Why**: Removing an iframe, canceling a resource, and releasing a media load delay all notify the document lifecycle from their caller's stack. The HTML parser's waits and "the end" steps 5 and 7 spin the event loop; they do not authorize an unrelated DOM operation to execute waiting script inline.

**What Happened**: Document's shared load-delay hook resumed the input stream and drained deferred scripts immediately. After removing a blocking stylesheet, removing a child iframe produced `parser,after` instead of `after,parser`. Direct resource undelay and load-delay recheck reproduced the same ordering.

**Fix**: Split synchronous readiness notification from task-only continuation. Reuse the document-associated script-delivery task with its parser epoch, slab generation, active-document and abort guards. Keep load-event readiness checks synchronous only where they queue the load task. Allocation failure or task drop has no inline execution fallback.

**Takeaway**: **Audit a notification's callers before putting script execution inside it; a readiness change and its continuation can belong to different tasks.**
