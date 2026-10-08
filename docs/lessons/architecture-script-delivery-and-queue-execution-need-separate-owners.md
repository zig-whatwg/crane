# Architecture: Script delivery and queue execution need separate owners

**Date**: 2026-10-07
**Lesson**: A result-delivery task finishes before a ready deferred script
behind an unready head can execute. The document queue must keep that script
alive beyond the task's return.

**Why**: The former synchronous fetch path made all deferred results available
together, hiding the interval between delivery and execution. With parallel
fetching, the second script's delivery task may end while the first still
loads. Document script lists contain bare instance pointers, which are not
collector edges.

**What Happened**: The execution root could not reuse keepPlatformObjectAlive:
the engine protocol explicitly defines it as one shared per-instance flag,
not an owner-counted hold. Ending the task's flag would also end a queue's hold
if both reused that mechanism.

**Fix**: Each scheduled element has an independent engine.Owned execution root
for its document queue. Removing the entry transfers the root to a local
across execution; abort, parser replacement and destruction explicitly release
their applicable entries. Element deinit is a fallback, not the only release
path for a self-rooted wrapper. Ordinary document.open drops parser blockers
and deferred work, preserving the document's ASAP and in-order queues.

WebKit separates
[HTMLScriptRunner's parser queues](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/html/parser/HTMLScriptRunner.cpp)
from the document's
[ScriptRunner queues](https://github.com/WebKit/WebKit/blob/main/Source/WebCore/dom/ScriptRunner.cpp).
Its Document::implicitOpen detaches the former while retaining the latter.

**Takeaway**: **Name the end of each owner's lifetime. Delivering a result and
executing it are separate endpoints when an ordered queue can wait.**
