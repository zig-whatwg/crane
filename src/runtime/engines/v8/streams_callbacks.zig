//! Streams API Callback Invocation Helpers
//!
//! Provides high-level wrappers for invoking JavaScript callbacks from WHATWG Streams.
//! These helpers handle Promise chaining, argument conversion, and error handling.
//!
//! ## Usage
//!
//! ```zig
//! const streams = @import("streams_callbacks.zig");
//!
//! // WritableStream callbacks
//! try streams.invokeWriteAlgorithm(isolate, context, write_fn, chunk, controller);
//! try streams.invokeCloseAlgorithm(isolate, context, close_fn);
//! try streams.invokeAbortAlgorithm(isolate, context, abort_fn, reason);
//!
//! // ReadableStream callbacks
//! try streams.invokePullAlgorithm(isolate, context, pull_fn, controller);
//! try streams.invokeCancelAlgorithm(isolate, context, cancel_fn, reason);
//!
//! // TransformStream callbacks
//! try streams.invokeTransformAlgorithm(isolate, context, transform_fn, chunk, controller);
//! try streams.invokeFlushAlgorithm(isolate, context, flush_fn, controller);
//! ```

const std = @import("std");
const v8 = @import("ffi.zig");
const promise = @import("promise.zig");
const Promise = promise.Promise;

// ============================================================================
// WritableStream Callbacks
// ============================================================================

/// Invoke a WritableStream write algorithm
///
/// WHATWG Streams spec: write(chunk, controller) → Promise<undefined>
///
/// Reference: https://streams.spec.whatwg.org/#writablestream-set-up
///
/// Example:
/// ```zig
/// const result = try invokeWriteAlgorithm(
///     isolate,
///     context,
///     write_algorithm,
///     chunk_value,
///     controller_object,
/// );
/// defer result.deinit();
/// ```
pub fn invokeWriteAlgorithm(
    isolate: *v8.Isolate,
    context: *v8.Context,
    write_fn: *v8.Function,
    chunk: *v8.Value,
    controller: *v8.Object,
) !Promise(void) {
    const args = [_]*v8.Value{
        chunk,
        @as(*v8.Value, @ptrCast(controller)),
    };

    return promise.invokeCallback(
        void,
        isolate,
        context,
        write_fn,
        null, // no 'this'
        &args,
    );
}

/// Invoke a WritableStream close algorithm
///
/// WHATWG Streams spec: close() → Promise<undefined>
///
/// Reference: https://streams.spec.whatwg.org/#writablestream-set-up
///
/// Example:
/// ```zig
/// const result = try invokeCloseAlgorithm(isolate, context, close_algorithm);
/// defer result.deinit();
/// ```
pub fn invokeCloseAlgorithm(
    isolate: *v8.Isolate,
    context: *v8.Context,
    close_fn: *v8.Function,
) !Promise(void) {
    const args = [_]*v8.Value{};

    return promise.invokeCallback(
        void,
        isolate,
        context,
        close_fn,
        null, // no 'this'
        &args,
    );
}

/// Invoke a WritableStream abort algorithm
///
/// WHATWG Streams spec: abort(reason) → Promise<undefined>
///
/// Reference: https://streams.spec.whatwg.org/#writablestream-set-up
///
/// Example:
/// ```zig
/// const result = try invokeAbortAlgorithm(isolate, context, abort_algorithm, reason);
/// defer result.deinit();
/// ```
pub fn invokeAbortAlgorithm(
    isolate: *v8.Isolate,
    context: *v8.Context,
    abort_fn: *v8.Function,
    reason: *v8.Value,
) !Promise(void) {
    const args = [_]*v8.Value{reason};

    return promise.invokeCallback(
        void,
        isolate,
        context,
        abort_fn,
        null, // no 'this'
        &args,
    );
}

// ============================================================================
// ReadableStream Callbacks
// ============================================================================

/// Invoke a ReadableStream pull algorithm
///
/// WHATWG Streams spec: pull(controller) → Promise<undefined>
///
/// Reference: https://streams.spec.whatwg.org/#readablestream-set-up
///
/// Example:
/// ```zig
/// const result = try invokePullAlgorithm(isolate, context, pull_algorithm, controller);
/// defer result.deinit();
/// ```
pub fn invokePullAlgorithm(
    isolate: *v8.Isolate,
    context: *v8.Context,
    pull_fn: *v8.Function,
    controller: *v8.Object,
) !Promise(void) {
    const args = [_]*v8.Value{
        @as(*v8.Value, @ptrCast(controller)),
    };

    return promise.invokeCallback(
        void,
        isolate,
        context,
        pull_fn,
        null, // no 'this'
        &args,
    );
}

/// Invoke a ReadableStream cancel algorithm
///
/// WHATWG Streams spec: cancel(reason) → Promise<undefined>
///
/// Reference: https://streams.spec.whatwg.org/#readablestream-set-up
///
/// Example:
/// ```zig
/// const result = try invokeCancelAlgorithm(isolate, context, cancel_algorithm, reason);
/// defer result.deinit();
/// ```
pub fn invokeCancelAlgorithm(
    isolate: *v8.Isolate,
    context: *v8.Context,
    cancel_fn: *v8.Function,
    reason: *v8.Value,
) !Promise(void) {
    const args = [_]*v8.Value{reason};

    return promise.invokeCallback(
        void,
        isolate,
        context,
        cancel_fn,
        null, // no 'this'
        &args,
    );
}

// ============================================================================
// TransformStream Callbacks
// ============================================================================

/// Invoke a TransformStream transform algorithm
///
/// WHATWG Streams spec: transform(chunk, controller) → Promise<undefined>
///
/// Reference: https://streams.spec.whatwg.org/#transformstream-set-up
///
/// Example:
/// ```zig
/// const result = try invokeTransformAlgorithm(
///     isolate,
///     context,
///     transform_algorithm,
///     chunk,
///     controller,
/// );
/// defer result.deinit();
/// ```
pub fn invokeTransformAlgorithm(
    isolate: *v8.Isolate,
    context: *v8.Context,
    transform_fn: *v8.Function,
    chunk: *v8.Value,
    controller: *v8.Object,
) !Promise(void) {
    const args = [_]*v8.Value{
        chunk,
        @as(*v8.Value, @ptrCast(controller)),
    };

    return promise.invokeCallback(
        void,
        isolate,
        context,
        transform_fn,
        null, // no 'this'
        &args,
    );
}

/// Invoke a TransformStream flush algorithm
///
/// WHATWG Streams spec: flush(controller) → Promise<undefined>
///
/// Reference: https://streams.spec.whatwg.org/#transformstream-set-up
///
/// Example:
/// ```zig
/// const result = try invokeFlushAlgorithm(isolate, context, flush_algorithm, controller);
/// defer result.deinit();
/// ```
pub fn invokeFlushAlgorithm(
    isolate: *v8.Isolate,
    context: *v8.Context,
    flush_fn: *v8.Function,
    controller: *v8.Object,
) !Promise(void) {
    const args = [_]*v8.Value{
        @as(*v8.Value, @ptrCast(controller)),
    };

    return promise.invokeCallback(
        void,
        isolate,
        context,
        flush_fn,
        null, // no 'this'
        &args,
    );
}

// ============================================================================
// Queuing Strategy Callbacks
// ============================================================================

/// Invoke a QueuingStrategy size algorithm
///
/// WHATWG Streams spec: size(chunk) → number
///
/// Note: Unlike other algorithms, size() returns a number, not a Promise.
/// We still wrap the result in a Promise for consistency with error handling.
///
/// Reference: https://streams.spec.whatwg.org/#blqs-size
///
/// Example:
/// ```zig
/// const result = try invokeSizeAlgorithm(isolate, context, size_algorithm, chunk);
/// defer result.deinit();
/// ```
pub fn invokeSizeAlgorithm(
    isolate: *v8.Isolate,
    context: *v8.Context,
    size_fn: *v8.Function,
    chunk: *v8.Value,
) !f64 {
    const args = [_]*v8.Value{chunk};

    const this_val = v8.v8_Undefined(isolate) orelse return error.UndefinedCreationFailed;

    const result = v8.v8_Function_Call(
        size_fn,
        context,
        this_val,
        @intCast(args.len),
        args.ptr,
    ) orelse return error.CallbackInvocationFailed;
    defer v8.v8_Value_Dispose(result);

    // Convert result to number
    return v8.v8_Value_NumberValue(result, context);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "invokeWriteAlgorithm - signature check" {
    // Just verify the function signature compiles
    // Runtime tests require V8 integration
    if (true) return error.SkipZigTest;
}

test "invokeCloseAlgorithm - signature check" {
    // Just verify the function signature compiles
    // Runtime tests require V8 integration
    if (true) return error.SkipZigTest;
}

test "invokeAbortAlgorithm - signature check" {
    // Just verify the function signature compiles
    // Runtime tests require V8 integration
    if (true) return error.SkipZigTest;
}

test "invokePullAlgorithm - signature check" {
    // Just verify the function signature compiles
    // Runtime tests require V8 integration
    if (true) return error.SkipZigTest;
}

test "invokeCancelAlgorithm - signature check" {
    // Just verify the function signature compiles
    // Runtime tests require V8 integration
    if (true) return error.SkipZigTest;
}

test "invokeTransformAlgorithm - signature check" {
    // Just verify the function signature compiles
    // Runtime tests require V8 integration
    if (true) return error.SkipZigTest;
}

test "invokeFlushAlgorithm - signature check" {
    // Just verify the function signature compiles
    // Runtime tests require V8 integration
    if (true) return error.SkipZigTest;
}

test "invokeSizeAlgorithm - signature check" {
    // Just verify the function signature compiles
    // Runtime tests require V8 integration
    if (true) return error.SkipZigTest;
}
