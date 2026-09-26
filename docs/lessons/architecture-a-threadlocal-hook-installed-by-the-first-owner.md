# Architecture: A threadlocal hook installed by the first owner makes results depend on process history

**Date**: 2026-09-25
**Lesson**: `abort_algorithms.createDependent` returned `NotSupported` until some AbortSignal had installed the hook, and its comment reasoned that every signal passed in already exists. A plain `fetch(url)` passes « » (the Request constructor's step 30), so a page whose first fetch ran before any signal existed had every fetch rejected with "the Request could not be constructed".

**Why**: hooks are installed lazily from the owner's `init`, and into threadlocal state that outlives the page. In a sweep, one earlier page that made a signal installs the hook for every page after it. Alone, the page is the first.

**What Happened**: `event-handler-attributes-windowless-body.html` was OK 236 in 25 journals and ERROR in a fresh process. It turned up while calibrating chat.local against this machine, because the calibration slice ran files in a different order. `@errorReturnTrace()` with `std.debug.dumpErrorReturnTrace` named the hook in one run, where the rejection message named only the constructor.

**Fix**: when nothing is installed, `createDependent` makes a signal through `interfaces.AbortSignal.init`, which installs the implementation, and lets it go (`releaseIfUnwrapped`). `tests/wpt/crane/request-before-any-abortsignal.html` pins it, and it goes red only in a fresh process.

**Takeaway**: **Before trusting a lazily installed hook, ask whether its consumer can run before any owner exists.** A test that passes in a sweep and fails alone is often one where a previous page did the setup.
