# Codegen: Event-handler fallbacks need ancestor state

**Date**: 2026-10-14
**Lesson**: A generated fallback is usable only when the receiver has the ancestor state that owns its behavior.

**Why**: Generated event-handler getters and setters delegate to dom.event_handlers when an impl override is absent. EventTarget's setter requires a registered InternalState. A legacy constructor can bypass the generated parent chain and leave that state absent.

**What Happened**: Performance had NotImplemented onresourcetimingbufferfull accessors. Removing them selected the generated fallback, but setters then threw InvalidStateError: Performance.init makes its own runtime instance and timeline without running EventTarget.initOwn. Its legacy deinit also bypasses the generated parent chain. Focused WPT caught the setter failure, and matched leaks --atExit found one additional 16-byte callback-argument handle on the failed path (3 leaks / 2703408 bytes BASE, 4 / 2703424 candidate).

**Resolution**: Reverted the uncommitted accessor removal. The receiver's construction/destruction migration and the failed setter's handle ownership need their owning lanes; they were outside this lane's state/lifetime grant. Keep the failing Crane fixtures, including one that leaves a handler installed for realm teardown. Do not add private callback storage or change a generated interface to conceal missing ancestor initialization.

**Takeaway**: **Check both dispatch and construction: a working shared implementation cannot supply receiver state that was never initialized.**
