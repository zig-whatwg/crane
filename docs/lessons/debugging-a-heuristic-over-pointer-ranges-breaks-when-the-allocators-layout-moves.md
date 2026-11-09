# Debugging: A heuristic over pointer ranges breaks when the allocator's layout moves

**Date**: 2026-11-09
**Lesson**: A guard that decides a pointer is "not a heap object" from its address range encodes one allocator's layout. The day a valid object lives somewhere else, the guard turns correct values into silent garbage.

**Why**: `v8_FunctionCallbackInfo_SetReturnValueGlobal` rejected any `Global<Value>*` in [0x100000000, 0x110000000). Its comment called that range "code/static" on macOS, and the guard returned `undefined` instead of the value. While every Global was a `new Global<T>` box from malloc, the guess never fired. The wrapper redesign's P2 constructs a node's wrapper Global in place, inside the node's NodeBase, which lives in the Browser's arena - and macOS maps that arena in exactly that range.

**What Happened**: After P2 every `createElement` in a tests/v8 page returned `undefined`, with one stderr line per call: "[SetReturnValueGlobal] REJECTED: Pointer 0x10c4989a8 looks like code/static address, not heap Global handle. Returning undefined." The tests failed far from the cause, on "Cannot set properties of undefined" and on missing platform objects. Linux mapped the arena elsewhere, so nothing failed there.

**Fix**: The range test went (lane wr1 batch 2, commit ae9111569c6). The checks that hold for any valid pointer stay: non-null, canonical, 8-aligned. The real defence against a stale handle is ownership: who disposes the Global, and when.

**Takeaway**: **Never classify a pointer by its address range. An allocator, an OS or a new owner of the bytes moves it, and the guard then corrupts values instead of catching bugs. Defend with ownership and type checks, not with where memory happens to be.**
