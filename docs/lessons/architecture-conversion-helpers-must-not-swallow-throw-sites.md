# Architecture: V8 conversion helpers must leave JS exceptions pending to preserve throw sites

**Date**: 2026-11-25
**Lesson**: Inner `TryCatch` wrappers in V8 conversion helpers (`toNumber`, `toStringBytes`, `DOMString`/`USVString` conversion) destroy the original `v8::Message` throw site before an outer `v8_RunCatchingWithSite` can capture it for `.report` exception reporting.

**Why**: HTML's "report an exception" requires the filename and line number where script threw (including primitive throws like `throw 7` that have no `.stack` property). When a C++ helper catches a JS exception inside an inner `v8::TryCatch` and rethrows the value with `ThrowException`, V8 discards the original `Message` and line number.

**What Happened**: Moving `OnBeforeUnloadEventHandlerNonNull` and `XPathNSResolver.lookupNamespaceURI` onto the unified `invokeCallbackFunctionAs` / `callUserObjectOperationAs` paths runs the standard V8 conversion functions inside `v8_RunCatchingWithSite`. Helpers that used inner `v8_RunCatching` or `v8_Value_ToString_Safe` swallowed the throw site so `bf1_callback_return_test` could not observe line 2 of `bf1-return-conversion.js` on a primitive throw from `toString()`.

**Fix**: Switched `conversions.zig` string and number conversions to direct `v8_Value_ToString` and `v8_Value_ToNumber`, which leave V8's pending exception and original `v8::Message` intact for the enclosing `v8_RunCatchingWithSite` (or V8 binding boundary) to capture.

**Takeaway**: **Never wrap V8 `ToString`/`ToNumber` calls in an inner catch-and-rethrow helper inside conversion code; leave the exception pending so the outermost `TryCatch` captures the exact original throw site.**
