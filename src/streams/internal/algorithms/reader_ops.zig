//! ReadableStreamDefaultReader Algorithms
//!
//! WHATWG Streams Standard: https://streams.spec.whatwg.org/#default-reader-class
//!
//! Extracted algorithms for reader operations, enabling reuse by:
//! - ReadableStreamDefaultReader methods
//! - ReadableStreamAsyncIterator
//! - Other stream infrastructure
//!
//! ## Architecture Note
//!
//! This file is part of the streams implementation infrastructure. Per Golden Rule #12,
//! we use interfaces for public API calls (constructor, releaseLock). However, some
//! internal algorithms (pullSteps, readableStreamCancelFromReaderWithOptReason) are
//! NOT exposed through interfaces because they bypass public API checks (e.g., lock
//! validation). These internal calls legitimately require direct impl access.
//!
//! ## Type Safety
//!
//! This module uses typed callback interfaces from common.zig:
//! - `TypedReadCallbacks(Context)` for compile-time type safety
//! - `ErasedReadCallbacks` for runtime polymorphism
//!
//! Callbacks receive `common.JSValue` for chunk/error values instead of raw `*anyopaque`.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const AsyncPromise = @import("async_promise").AsyncPromise;
const event_loop_mod = @import("event_loop");
const v8_mod = @import("v8");
const pointer_tag = v8_mod.pointer_tag;
const common = @import("common");

// Internal impl access for algorithms that bypass public API checks
// (e.g., pullSteps, internal cancel without lock check)
const impls = @import("impls");

// Re-export typed callback types for convenience
pub const TypedReadCallbacks = common.TypedReadCallbacks;
pub const ErasedReadCallbacks = common.ErasedReadCallbacks;
pub const JSValue = common.JSValue;

/// AcquireReadableStreamDefaultReader
///
/// Spec: https://streams.spec.whatwg.org/#acquire-readable-stream-reader
///
/// Creates a new ReadableStreamDefaultReader and acquires a lock on the stream.
///
/// Steps (embedded in ReadableStreamDefaultReader constructor):
/// 1. If stream is locked, throw TypeError
/// 2. Create reader
/// 3. ReadableStreamReaderGenericInitialize(reader, stream)
/// 4. Set reader.[[readRequests]] to empty list
///
/// Returns: ReadableStreamDefaultReader instance
pub fn acquireReadableStreamDefaultReader(
    ctx: runtime.Context,
    stream: *runtime.Instance,
) !*runtime.Instance {
    // This delegates to ReadableStreamDefaultReader constructor
    // which performs all the acquisition steps
    // Use interface instead of impl (per Golden Rule #12)
    return interfaces.ReadableStreamDefaultReader.call_constructor(ctx, stream);
}

/// ReadableStreamDefaultReaderRead (callback-based version)
///
/// Spec: https://streams.spec.whatwg.org/#readable-stream-default-reader-read
///
/// Reads from a ReadableStreamDefaultReader using a read request with callbacks.
///
/// Steps:
/// 1. Let stream be reader.[[stream]]
/// 2. Assert: stream is not undefined
/// 3. Set stream.[[disturbed]] to true
/// 4. If stream.[[state]] is "closed", perform readRequest's close steps
/// 5. If stream.[[state]] is "errored", perform readRequest's error steps with stream.[[storedError]]
/// 6. Otherwise, perform ! stream.[[controller]].[[PullSteps]](readRequest)
///
/// This is a callback-based version used by async iterator.
/// For promise-based version, use ReadableStreamDefaultReader.call_read()
///
/// ## Type Safety
///
/// Uses `ErasedReadCallbacks` which provides typed callbacks:
/// - `chunk_steps(ctx, JSValue)` - receives chunk as typed JSValue
/// - `close_steps(ctx)` - called when stream closes
/// - `error_steps(ctx, JSValue)` - receives error as typed JSValue
///
/// For compile-time type safety, create callbacks using `TypedReadCallbacks(Context)`
/// and convert with `.erase()`:
/// ```zig
/// const typed = TypedReadCallbacks(MyContext){
///     .context = &my_ctx,
///     .chunk_steps = MyContext.onChunk,
///     .close_steps = MyContext.onClose,
///     .error_steps = MyContext.onError,
/// };
/// try readableStreamDefaultReaderRead(reader, typed.erase());
/// ```
pub fn readableStreamDefaultReaderRead(
    reader: *runtime.Instance,
    callbacks: ErasedReadCallbacks,
) !void {
    const reader_state = reader.getState(interfaces.ReadableStreamDefaultReader.State);
    const reader_internal = reader_state.own._internal orelse return error.TypeError;

    // Step 1: Let stream be reader.[[stream]]
    const stream = reader_internal.stream orelse return error.TypeError;

    // Step 2: Assert: stream is not undefined (checked above)

    // Step 3: Set stream.[[disturbed]] to true
    const stream_state = stream.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.TypeError;
    stream_internal.disturbed = true;

    // Step 4: If stream.[[state]] is "closed", perform close steps
    if (stream_internal.state == .closed) {
        callbacks.executeCloseSteps();
        return;
    }

    // Step 5: If stream.[[state]] is "errored", perform error steps
    if (stream_internal.state == .errored) {
        // Pass the stored error as a JSValue
        const error_value = if (stream_internal.stored_error) |e|
            JSValue.createError(e)
        else
            JSValue.createTypeError("Stream errored");
        callbacks.executeErrorSteps(error_value);
        return;
    }

    // Step 6: Otherwise, perform ! stream.[[controller]].[[PullSteps]](readRequest)
    // We wrap the callbacks in a promise-based interface that the controller expects
    // NOTE: pullSteps is an internal method - see module-level comment for why impls is used

    // Get controller from stream
    const controller = stream_internal.controller;

    // Create a promise that will be fulfilled by the controller
    const promise = try AsyncPromise(impls.ReadableStreamDefaultReader.ReadResult).init(
        reader_internal.allocator,
        reader_internal.event_loop,
    );

    // Create context that holds both the original callbacks
    const callback_ctx = try reader_internal.allocator.create(ReadCallbackContext);
    callback_ctx.* = .{
        .callbacks = callbacks,
        .allocator = reader_internal.allocator,
    };

    // Attach handlers to the promise that will call the appropriate callbacks
    try promise.onSettleCtx(
        onReadFulfilled,
        onReadRejected,
        @ptrCast(callback_ctx),
    );

    // Call controller.pullSteps with the promise
    try impls.ReadableStreamDefaultController.pullSteps(controller, promise);
}

/// Context for callback-based read using typed callbacks
const ReadCallbackContext = struct {
    /// Type-erased callbacks for runtime polymorphism
    callbacks: ErasedReadCallbacks,
    /// Allocator for cleanup
    allocator: std.mem.Allocator,
};

/// Handler for read promise fulfillment
fn onReadFulfilled(ctx_ptr: *anyopaque, result: @import("impls").ReadableStreamDefaultReader.ReadResult) anyerror!void {
    const ctx: *ReadCallbackContext = @ptrCast(@alignCast(ctx_ptr));
    defer ctx.allocator.destroy(ctx);

    if (result.done) {
        // Stream closed - call close steps
        ctx.callbacks.executeCloseSteps();
    } else if (result.value) |chunk_value| {
        // Got a chunk - call chunk steps with typed JSValue
        // Convert runtime.JSValue to common.JSValue for the callback
        const chunk_js_value = runtimeJSValueToCommonJSValue(chunk_value, ctx.allocator) catch {
            // If conversion fails, treat as close
            ctx.callbacks.executeCloseSteps();
            return;
        };
        ctx.callbacks.executeChunkSteps(chunk_js_value);
    } else {
        // No value but not done - shouldn't happen per spec
        ctx.callbacks.executeCloseSteps();
    }
}

/// Handler for read promise rejection
fn onReadRejected(ctx_ptr: *anyopaque, exception: webidl.errors.Exception) anyerror!void {
    const ctx: *ReadCallbackContext = @ptrCast(@alignCast(ctx_ptr));
    defer ctx.allocator.destroy(ctx);

    // Convert exception to JSValue and call error steps
    const error_value = exceptionToJSValue(exception);
    ctx.callbacks.executeErrorSteps(error_value);
}

/// Convert runtime.JSValue to common.JSValue
///
/// Bridges the runtime module's JSValue type to the streams internal JSValue type.
/// This preserves type information through the conversion.
fn runtimeJSValueToCommonJSValue(value: runtime.JSValue, allocator: std.mem.Allocator) !JSValue {
    return switch (value) {
        .undefined => JSValue.undefined_value(),
        .null => JSValue.null_value(),
        .boolean => |b| JSValue.fromBool(b),
        .number => |n| JSValue.fromNumber(n),
        .string => |s| JSValue.fromString(s),
        .handle => |h| try JSValue.fromEnginePtr(allocator, h.ptr),
        .instance => |ptr| try JSValue.fromEnginePtr(allocator, ptr),
    };
}

/// Convert webidl.errors.Exception to JSValue
///
/// Creates a typed error JSValue from a WebIDL exception.
fn exceptionToJSValue(exception: webidl.errors.Exception) JSValue {
    const message = switch (exception) {
        .simple => |s| s.message,
        .dom => |d| d.message,
    };

    // Determine error type from exception
    const error_type = switch (exception) {
        .simple => |s| switch (s.type) {
            .TypeError => common.ErrorType.type_error,
            .RangeError => common.ErrorType.range_error,
            .SyntaxError => common.ErrorType.syntax_error,
            else => common.ErrorType.generic,
        },
        .dom => common.ErrorType.generic,
    };

    return .{ .error_value = .{ .error_type = error_type, .message = message } };
}

/// ReadableStreamDefaultReaderRelease
///
/// Spec: https://streams.spec.whatwg.org/#abstract-opdef-readablestreamdefaultreaderrelease
///
/// Releases a reader's lock on the stream.
///
/// Delegates to ReadableStreamReaderGenericRelease which:
/// 1. Gets stream from reader.[[stream]]
/// 2. Asserts stream is not undefined
/// 3. Asserts stream.[[reader]] is reader
/// 4. If stream.[[state]] is "readable", rejects reader.[[closedPromise]] with TypeError
/// 5. Otherwise, sets reader.[[closedPromise]] to rejected promise with TypeError
/// 6. Sets promise.[[PromiseIsHandled]] to true
/// 7. Performs stream.[[controller]].[[ReleaseSteps]]()
/// 8. Sets stream.[[reader]] to undefined
/// 9. Sets reader.[[stream]] to undefined
pub fn readableStreamDefaultReaderRelease(reader: *runtime.Instance) !void {
    // This delegates to the releaseLock() method
    // Use interface instead of impl (per Golden Rule #12)
    try interfaces.ReadableStreamDefaultReader.call_releaseLock(reader);
}

/// ReadableStreamReaderGenericCancel
///
/// Spec: https://streams.spec.whatwg.org/#readable-stream-reader-generic-cancel
///
/// Cancels the stream through a reader.
///
/// Steps:
/// 1. Let stream be reader.[[stream]]
/// 2. Assert: stream is not undefined
/// 3. Return ! ReadableStreamCancel(stream, reason)
///
/// Note: This calls the internal ReadableStreamCancel algorithm directly,
/// NOT the public cancel() method. The public method has a lock check that
/// would fail because the reader holds the lock. The internal algorithm
/// bypasses this check as intended by the spec.
///
/// ## Type Safety
///
/// Takes an optional `runtime.JSValue` for the cancellation reason instead of
/// raw `*anyopaque`. This preserves type information through the call chain.
///
/// Returns: Promise<void> that fulfills when cancellation completes
pub fn readableStreamReaderGenericCancel(
    reader: *runtime.Instance,
    reason: ?runtime.JSValue,
) !*AsyncPromise(void) {
    const reader_state = reader.getState(interfaces.ReadableStreamDefaultReader.State);
    const reader_internal = reader_state.own._internal orelse return error.TypeError;

    // Step 1: Get stream
    const stream = reader_internal.stream orelse return error.TypeError;

    // Step 2: Assert stream is not undefined (checked above)

    // Step 3: Cancel the stream using internal algorithm (bypasses lock check)
    // Use the internal cancel function that bypasses the lock check
    // This is correct per spec: ReadableStreamReaderGenericCancel calls
    // ReadableStreamCancel directly, not the public cancel() method
    // NOTE: This internal method bypasses lock check - see module-level comment
    //
    // Convert runtime.JSValue to ?*anyopaque for the impl function
    // The impl still uses anyopaque internally but we provide type safety at this boundary
    const reason_ptr: ?*anyopaque = if (reason) |r| r.asEngineHandle() else null;
    const cancel_promise_js_value = try impls.ReadableStream.readableStreamCancelFromReaderWithOptReason(stream, reason_ptr);

    // Cast the returned JSValue to AsyncPromise(void)
    // Extract the handle pointer from JSValue and untag V8 pointer before casting (V8 uses pointer tagging)
    const handle_ptr: *anyopaque = switch (cancel_promise_js_value) {
        .handle => |h| h.ptr,
        .instance => |ptr| ptr,
        else => return error.TypeError,
    };
    const untagged = pointer_tag.untagPointer(handle_ptr);
    const cancel_promise: *AsyncPromise(void) = @ptrCast(@alignCast(untagged.ptr));

    return cancel_promise;
}

/// Get event loop from reader
///
/// Helper to extract event loop for promise creation
pub fn getReaderEventLoop(reader: *runtime.Instance) event_loop_mod.EventLoop {
    const reader_state = reader.getState(interfaces.ReadableStreamDefaultReader.State);
    const reader_internal = reader_state.own._internal orelse unreachable; // Should never happen
    return reader_internal.event_loop;
}
