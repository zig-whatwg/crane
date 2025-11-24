//! ReadableStreamDefaultReader Algorithms
//!
//! WHATWG Streams Standard: https://streams.spec.whatwg.org/#default-reader-class
//!
//! Extracted algorithms for reader operations, enabling reuse by:
//! - ReadableStreamDefaultReader methods
//! - ReadableStreamAsyncIterator
//! - Other stream infrastructure

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const AsyncPromise = @import("../async_promise").AsyncPromise;
const event_loop_mod = @import("../event_loop");

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
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    stream: *runtime.Instance,
) !*runtime.Instance {
    // This delegates to ReadableStreamDefaultReader constructor
    // which performs all the acquisition steps
    const ReaderImpl = @import("../../webidl/impls/ReadableStreamDefaultReader.zig");
    return ReaderImpl.call_constructor(allocator, ctx, stream);
}

/// ReadableStreamDefaultReaderRead
///
/// Spec: https://streams.spec.whatwg.org/#readable-stream-default-reader-read
///
/// Reads from a ReadableStreamDefaultReader using a read request.
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
pub fn readableStreamDefaultReaderRead(
    reader: *runtime.Instance,
    context: *anyopaque,
    chunk_steps: *const fn (ctx: *anyopaque, chunk: *anyopaque) void,
    close_steps: *const fn (ctx: *anyopaque) void,
    error_steps: *const fn (ctx: *anyopaque, err: *anyopaque) void,
) !void {
    const ReaderImpl = @import("../../webidl/impls/ReadableStreamDefaultReader.zig");
    const reader_state = reader.getState(interfaces.ReadableStreamDefaultReader.State);
    const reader_internal = reader_state.own._internal orelse return error.TypeError;

    // Step 1: Get stream
    const stream = reader_internal.stream orelse return error.TypeError;

    // Step 2: Assert stream is not undefined (checked above)

    const stream_state = stream.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.InvalidState;

    // Step 3: Set stream.[[disturbed]] to true
    stream_internal.disturbed = true;

    // Steps 4-6: Handle based on stream state
    switch (stream_internal.state) {
        .closed => {
            // Step 4: Perform close steps
            close_steps(context);
        },
        .errored => {
            // Step 5: Perform error steps with stored error
            const err = stream_internal.stored_error orelse @as(*anyopaque, @ptrCast(@constCast(&"Stream errored")));
            error_steps(context, err);
        },
        .readable => {
            // Step 6: Delegate to controller's PullSteps
            const controller = stream_internal.controller;
            const ControllerImpl = @import("../../webidl/impls/ReadableStreamDefaultController.zig");

            // Create a read request wrapper that calls the provided callbacks
            const ReadRequest = struct {
                ctx: *anyopaque,
                chunk_fn: *const fn (ctx: *anyopaque, chunk: *anyopaque) void,
                close_fn: *const fn (ctx: *anyopaque) void,
                error_fn: *const fn (ctx: *anyopaque, err: *anyopaque) void,

                pub fn onChunk(self: *anyopaque, chunk: *anyopaque) void {
                    const req: *@This() = @ptrCast(@alignCast(self));
                    req.chunk_fn(req.ctx, chunk);
                }

                pub fn onClose(self: *anyopaque) void {
                    const req: *@This() = @ptrCast(@alignCast(self));
                    req.close_fn(req.ctx);
                }

                pub fn onError(self: *anyopaque, err: *anyopaque) void {
                    const req: *@This() = @ptrCast(@alignCast(self));
                    req.error_fn(req.ctx, err);
                }
            };

            const request = try reader_internal.allocator.create(ReadRequest);
            request.* = .{
                .ctx = context,
                .chunk_fn = chunk_steps,
                .close_fn = close_steps,
                .error_fn = error_steps,
            };

            // Add to read requests queue
            // Note: We're using promises in the current implementation
            // For async iterator, we'll need to adapt the controller
            // to support callback-based read requests

            // TODO: This is a simplified implementation
            // The full implementation requires adapting the controller
            // to accept callback-based read requests
            _ = ControllerImpl;
            _ = request;

            // For now, return not implemented
            return error.NotImplemented;
        },
    }
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
    const ReaderImpl = @import("../../webidl/impls/ReadableStreamDefaultReader.zig");
    try ReaderImpl.call_releaseLock(reader);
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
/// Returns: Promise<void> that fulfills when cancellation completes
pub fn readableStreamReaderGenericCancel(
    reader: *runtime.Instance,
    reason: ?*anyopaque,
) !*AsyncPromise(void) {
    const ReaderImpl = @import("../../webidl/impls/ReadableStreamDefaultReader.zig");
    const reader_state = reader.getState(interfaces.ReadableStreamDefaultReader.State);
    const reader_internal = reader_state.own._internal orelse return error.TypeError;

    // Step 1: Get stream
    const stream = reader_internal.stream orelse return error.TypeError;

    // Step 2: Assert stream is not undefined (checked above)

    // Step 3: Cancel the stream
    const cancel_promise_ptr = try interfaces.ReadableStream.call_cancel(stream, reason);

    // Cast the returned pointer to AsyncPromise(void)
    const cancel_promise: *AsyncPromise(void) = @ptrCast(@alignCast(@constCast(cancel_promise_ptr)));

    return cancel_promise;
}

/// Get event loop from reader
///
/// Helper to extract event loop for promise creation
pub fn getReaderEventLoop(reader: *runtime.Instance) event_loop_mod.EventLoop {
    const ReaderImpl = @import("../../webidl/impls/ReadableStreamDefaultReader.zig");
    const reader_state = reader.getState(interfaces.ReadableStreamDefaultReader.State);
    const reader_internal = reader_state.own._internal orelse unreachable; // Should never happen
    return reader_internal.event_loop;
}
