# Architecture: Whoever ends a weak arm inherits V8's Reset obligation

**Date**: 2026-09-22
**Lesson**: `v8_Global_ClearWeak` is the only `releaseWeakArm` caller that hands
the `Global` back, and it was treated like the ones that delete it.

**Why**: when V8 has already queued a first-pass callback (node NEAR_DEATH,
`IsWeak()` false), the callback WILL run. `releaseWeakArm` detached the record
and nulled its back-pointer so the callback would do nothing. That is right for
a disposer - `Reset(); delete;` is on the next line, and the caller's own Reset
discharges V8's obligation. `ClearWeak` has no such next line, so nothing ever
reset that node.

**What Happened**:

    # Fatal error in , line 0
    # Check failed: Handle not reset in first callback.
    #   See comments on |v8::WeakCallbackInfo|.
      GlobalHandles::InvokeFirstPassWeakCallbacks
      Heap::PerformGarbageCollection

`wrapper_cache.zig` disarms on six paths on every DOM wrapper, so all this needs
is a GC landing between V8 queuing the callback and running it. What made that
reliable was creating a child context: `registerAllTemplatesOnly` instantiates
1,263 interface templates and forces a collection in the middle of
`appendChild`. Four `template/additions-to-the-in-body-insertion-mode/ignore-*`
files died on it, all of them via `testInIFrame`.

**Fix**: `releaseWeakArm` takes a `WeakArmEnd`. `handle_survives` keeps the
back-pointer so the queued callback resets the node, and leaves the record in
`armedWeakData` under that handle - not as an arm (`callback` is nulled, so the
Zig finalizer cannot run on state the disarmer is tearing down) but so a LATER
dispose of the same handle can still find it and cut the pointer. Without that
second half, ClearWeak-then-Dispose in one tick puts `Reset()` on freed memory.

**Takeaway**: **"Release the arm" is two different operations depending on
whether the handle outlives the call.** V8 verifies the difference and aborts
the process, so the parameter is not optional documentation.
