# Architecture: Take error information while the TryCatch still holds it

**Date**: 2026-09-27
**Lesson**: `v8::Exception::CreateMessage`, asked after a call has returned, cannot locate a thrown value that is not an Error; the location has to come from the Message of the TryCatch that caught it, taken before that TryCatch goes.

**Why**: CreateMessage reads the stack an Error object captured when it was constructed. A thrown string or number has no such stack, so CreateMessage captures the current one - and once the call has returned, the current stack is the adapter's, with no script frame on it. The TryCatch's Message was made at the throw, and knows the script, line and column.

**What Happened**: The protocol's callback invocations (`invokeCallbackFunction` and `callUserObjectOperation` with the "report" behavior) built the Reporter's ErrorInfo with `v8_Exception_GetErrorInfo` - CreateMessage - after the call. A MutationObserver or IntersectionObserver callback doing `throw "x"` reached `window.onerror` with filename "undefined" and line 0 (crane/proto-observer-report-location.html). Moving the observers' reporters from report_exception's re-derivation to `reportErrorInfo` (the engine's information) changed nothing: the engine's information had been re-derived the same way inside the adapter. An Error object hid the bug everywhere, because it carries its own stack.

**Fix**: `v8_Function_CallCatchingWithSite` and `v8_Object_GetCatchingWithSite` take the throw site from the TryCatch (`errorInfoAtThrowSite`) while it still holds the exception. protocol_callbacks.zig carries it with the thrown value (`Thrown.site`) to the report, and frees it on the rethrow path. CreateMessage stays only as the fallback for an exception the adapter made itself. Blink does the same: `V8Initializer::MessageHandlerInMainThread` builds the ErrorEvent's location with `CaptureSourceLocation(isolate, message, context)` from the message V8 made at the throw.

**Takeaway**: **Error information belongs to the throw, not to the value: take it from the TryCatch that caught the exception, before the TryCatch goes. Re-deriving it from the value works only for Error objects, so test with a thrown string.**
