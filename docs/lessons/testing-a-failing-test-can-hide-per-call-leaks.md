# Testing: A failing test can hide per-call leaks

**Date**: 2026-10-15
**Lesson**: Compare equal call counts as well as equal test files when a feature fix lets tests execute more of their bodies.

**Status**: 2026-10-15 - the adapter leak is fixed (lane setterleak): an `any` setter value is released once the setter returns (`setterValueIsBorrowed`); crane/ar-internals-array-replacement.html went 102 -> 2 leaks. See [A setter borrows an `any` and takes a callback - on every path](architecture-a-setter-borrows-an-any-and-takes-a-callback-on-every-path.md).

**Why**: The same file list is not always the same workload. A missing setter can stop each test at its first assignment, hiding leaks on later calls that a working implementation reaches.

**What Happened**: ElementInternals' ten-file fixture run reported 37 leaks on BASE and 131 on TIP. Both stacks named v8_FunctionCallbackInfo_GetArgument. A regression fixture that attempts all 100 array replacements before reporting its first error measured exactly 102 leaks and 2,704,992 bytes on both builds: two snapshot allocations and 100 argument handles. The getter's final snapshot assertions failed on BASE and passed on TIP.

**Fix**: Report both measurements: the raw increase is real, while the equal-call control identifies an existing per-call adapter leak. Preserve the stacks and file/line diagnosis. Here the binding's argHandleIsCopied says JSValue retains its argument handle, but freeConvertedValue does not release its handle arm. Fix that ownership in the adapter; an impl must not dispose a borrowed JSValue to compensate (docs/engine-protocol-recipes.md, 0.3-0.4). This lane leaves the adapter fix as a follow-up. The same leaked input can mask a missing holder edge in a GC test: clear the input array immediately after assignment, before dropping other references and collecting, so only the internal copy can keep its elements alive.

**Takeaway**: **A passing test can expose more of an old leak; equal-call controls distinguish that from a new allocation leak.**
