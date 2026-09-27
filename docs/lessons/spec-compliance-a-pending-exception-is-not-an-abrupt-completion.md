# Spec Compliance: A pending exception is not an abrupt completion

**Date**: 2026-09-27
**Lesson**: When a spec algorithm takes a completion ("interpreting the result as a completion record; if it is an abrupt completion, ..."), a conversion that throws must be caught as that completion - leaving the exception pending hands it to whatever script runs next, and the algorithm's own abrupt-completion steps never run.

**Why**: Engine conversions (ToNumber, ToString) report a throw by leaving the exception pending - right when the spec says "?" and the binding rethrows, wrong when the spec consumes the completion. V8's `NumberValue` also answers 0 on failure, so nothing even looked wrong.

**What Happened**: WritableStreamDefaultControllerGetChunkSize performs the size algorithm - invoke `size()`, then convert its result to `unrestricted double` - and step 3 errors the stream if that completion is abrupt. The call's throw was caught (streams_js's call is a catching call), but the conversion ran after it, through `v8_Value_NumberValue`: a `size()` returning `{ valueOf() { throw e } }` let `e` escape from `writer.write()` and left the stream writable. streams_readable has the same shape. The protocol had no way to catch what a step leaves pending.

**Fix**: `engine.completionOf(realm, steps, data) Error!?Owned` - ECMAScript Completion(...): run the steps; null on a normal completion, the thrown value (OWNED, nothing pending) on a throw completion. The size conversion runs under it, and the thrown value errors the stream (add343ddb). Test: crane/eb-writable-size-valueof.html.

**Takeaway**: **Wherever the spec reads a completion instead of writing "?", run the step under `engine.completionOf` - a conversion's throw is part of the algorithm's result, not the caller's problem.**
