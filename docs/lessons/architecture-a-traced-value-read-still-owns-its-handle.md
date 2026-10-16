# Architecture: A traced value read still owns its handle

**Date**: 2026-10-16
**Lesson**: A traced edge keeps a JavaScript value alive, but reading it through `engine.tracedValue` creates an owned handle with a separate release obligation.

**Why**: The protocol returns `?Owned` from `tracedValue`. A getter can transfer that result to the binding with `take()`, because the binding releases a getter's returned handle. A generated toJSON result record has a different contract: conversion borrows a nested `runtime.JSValue.handle`. It cannot tell that this particular handle was created for the call.

**What Happened**: Resource Timing needed its `serverTiming` FrozenArray in both the getter and default toJSON. Keeping one array in a traced slot correctly preserves array identity and lifetime. It does not make the handles returned by successive reads borrowed. Putting `tracedValue(...).?.take()` in the JSON record would leak a Global on every call. Releasing the handle before returning the record would leave a dead handle, even though the underlying array remained reachable. This was caught from the protocol and conversion contracts before shipping that path (codex-timing3 Q1/Q3).

**Fix**:
1. Keep the array by a traced edge and transfer each getter result normally.
2. Do not pass an owned read into a record whose converter only borrows it.
3. The integrator deferred the JSON member until generated result records can express member ownership. A Crane regression pins that temporary omission and must change with the binding fix. No second persistent handle or engine-protocol shortcut was added.

**Takeaway**: **Object identity, reachability, and ownership of the handle used to return it are three separate questions. Read the return contract at every boundary.**
