# Architecture: A hand-over every callee must take leaks at every callee that does not

**Date**: 2026-10-25
**Lesson**: When the binding hands a converted value over and only the callee's take frees it, every stub, every return before the take and every dictionary member a callee ignores leaks it. Make the value borrowed for the call, so the binding frees it, and let a keeper take a hold of its own.

**Why**: "The callee owns it" is the unsafe default over an open set of callees. The open set here is about 29 stub entries, the consumers of 24 dictionaries with callback members, and every stub codegen will write next with `_ = callback;`. AGENTS.md asks an ownership gate to default to the safe answer. A hand-over defaults to a leak, and nothing in the callee's code shows it.

**What Happened**: Row 117's in-process leak pass over 147 image files found one 16 B Global: ROOT malloc in `v8_FunctionCallbackInfo_GetArgument` <- `V8Interface(ResizeObserver).constructorCallback`.
- The integrator's isolation run of the one file read 0 leaks, so the leak was queued as order-dependent. That run was not an in-process, debuggable measurement.
- Lane leaks7 re-measured in-process on a get-task-allow copy of main's runner. 40 constructions leaked 40, and the file alone leaked 1.
- The cause: ResizeObserver's stub constructor never took its callback, and `engine.takeCallbackFunction` ADOPTED the argument's Global, so nothing else would free it.
- `canvas.toBlob(fn)` and `new Observable(fn)` leaked one per call the same way.

**Fix** (integrator ruling B):
1. A callback-function value is BORROWED, like every argument. `interface.freeConvertedArg` frees it with the rest of the value, in every shape: an argument, a dictionary member, a union arm, a sequence element, an overload variant's argument. `setterValueIsBorrowed` covers an attribute's value too.
2. `engine.takeCallbackFunction` moves the function into a Global of the taker's own. `v8_Global_TakeOver` uses Global's move constructor, so no V8 handle is made: one 16 B box. The binding then deletes its emptied Global.
3. Only one consumer kept the binding's address past the take: EventTarget's handler map, whose getter returns it. It now records its own hold's address.
4. `tests/v8/callback_argument_borrowed_test.zig` pins every shape against V8's live handle count. On base, each untaken shape left 64 handles per 64 calls.

Mark-the-box-taken (no new malloc) is not safe. The taker may release its hold during the call, and the binding would then read a freed box to learn whether it was taken.

**Takeaway**: **Make "borrowed for the call" the default for every converted value, and have keepers take their own hold: a hand-over that each callee must remember to take leaks at every callee that forgets. And before theorising that a leak depends on order, re-run the isolation in-process on a debuggable runner.**
