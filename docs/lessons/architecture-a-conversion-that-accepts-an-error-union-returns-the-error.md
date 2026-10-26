# Architecture: A conversion that accepts an error union returns the error as a value

**Date**: 2026-10-26
**Lesson**: A value conversion with an error-union branch turns a failed call into a normal result, so a binding has to unwrap the impl's error union and throw before it converts anything.

**Why**: `conv.toV8Value` accepts any Zig type. For an error union, its branch makes an `Error` object from the error's name and returns it as an ordinary value. A binding that hands the conversion an impl's whole `anyerror!T` therefore compiles, runs, and sets an Error object as the call's return value. Nothing throws, and no compile error or failing test tells you.

**What Happened**: The namespace binding's operation path (src/runtime/engines/v8/namespace.zig, generateCallback) passed the whole `anyerror!T` to `toV8Value`. Every failing namespace operation returned an Error object instead of throwing: CSS.registerProperty's TypeError, SyntaxError and InvalidModificationError, and console's and TestUtils' errors. Row 120's `crane/pr1-register-basic.html` reported "did not throw", and 163 of its subtests waited on the fix. The getter path in the same file was already right, because it caught the error before converting. The interface binding was also right. Only the one path that relied on the conversion was wrong.

**Fix**:
1. In the callback, compute the payload type from the impl's return type. Unwrap with `catch |err|` and throw through `conv.throwWebIDLErrorFromContext`. Convert only the payload.
2. On `error.ExceptionPending`, throw nothing. Script's own exception stays pending, as `interface.zig` throwMemberError does.
3. Test the binding with a hand-written namespace (tests/v8/namespace_operation_errors_test.zig). Check that a DOMException name throws that DOMException, `error.TypeError` throws a TypeError, a success returns its value, and a pending exception is rethrown unchanged.
4. Survey who else reaches the conversion's error-union branch. A temporary `@compileLog` in the branch over `zig build crane-check` printed nothing at the fixed tip, so no other binding path depends on it.

**Takeaway**: **Throwing is the binding's job, never the conversion's: unwrap an impl's error union before converting, and treat an error-union branch in a generic value conversion as a trap.**
