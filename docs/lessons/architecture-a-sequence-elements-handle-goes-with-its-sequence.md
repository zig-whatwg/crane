# Architecture: A sequence element's handle goes with its sequence, on every path that frees it

**Date**: 2026-10-16
**Lesson**: A `sequence<any>` or `sequence<object>` element keeps its Get handle as its `.handle` (the IDL value refers to the object), and nothing released it: the sequence free released strings only, and each conversion's error path freed elements one by one with the same rule.

**Why**: The release rule for `any` was written per argument (`releaseAnyArgument`), and a dictionary member's `any` got it too; a sequence element was left on "the conservative answer (kept)" until its keepers were read. Variadic `any...` arguments were released one by one by their own loop, which hid the gap: every sequence a test exercised looked clean.

**What Happened**: lane serial's leaks --atExit named a 16-byte `v8_Object_Get` handle per `structuredClone(v, {transfer: [...]})` call - StructuredSerializeOptions.transfer, a `sequence<object>` member. tests/v8/per_call_handle_test.zig measured 2,048 global handle bytes over 64 calls, on success and when the second element's [[Get]] threw.

**Fix**: `interface.freeSequenceElement` frees an element as `freeArgument` frees an argument; the slice free, fromV8Sequence's and sequenceFromIterable's error paths all use it. The keepers were read first: only StructuredSerializeOptions.transfer has readers (structuredClone and four postMessage steps), and they hand the list to the serializer, which takes Globals of its own.

**Takeaway**: **A release rule belongs to the value, so apply it wherever the value is freed - the container's free and every error path - and read the keepers before switching a conservative "kept" to "released".**
