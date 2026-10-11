# Testing: A union conversion needs a case per member type

**Date**: 2026-10-10
**Lesson**: Test a buffer-source conversion with one value of every flattened member type, a view with an offset, and a detached buffer; the common member passing proves nothing about the rest.

**Why**: A conversion written for its first caller handles that caller's inputs. TextDecoder's tests decode typed arrays, so a conversion that handled only typed arrays looked complete, and a view kind the adapter's kind table lacked was rejected everywhere without one test noticing.

**What Happened**: Two such gaps, found by lane bufsrc on 2026-10-10.
- `convertAllowSharedBufferSource`, the V8 adapter's conversion for (ArrayBuffer or SharedArrayBuffer or [AllowShared] ArrayBufferView), accepted only `IsTypedArray`/`IsDataView` and measured a DataView with the typed-array accessors: `new TextDecoder().decode(arrayBuffer)` threw TypeError and `decode(dataView)` returned "". Found only because a WebCrypto test decoded its decrypted ArrayBuffer.
- `CraneViewKind` (v8_wrapper.cpp, mirrored in ffi.ViewKind, engine.ViewType and webidl's ArrayBufferView union) had no Float16Array, so every BufferSource and ArrayBufferView conversion rejected one, though V8 and WebIDL both have it.

**Fix**: tests/v8/allow_shared_buffer_source_test.zig converts an ArrayBuffer, a SharedArrayBuffer, typed arrays and DataViews with offsets over both kinds of buffer, detached buffers and views, and non-buffers (red: 5 of 7 failing). tests/v8/float16_buffer_source_test.zig checks every typed array kind through Describe, plus Float16Array through every adapter path. The conversion now reads all four through `v8_AllowSharedBufferSource_Bytes`, and the kind enum gained `float16`, appended so the ABI numbers hold.

**Takeaway**: **Enumerate the flattened member types from the IDL and give each its own case - plus an offset view and a detached buffer - before calling a conversion done.**
