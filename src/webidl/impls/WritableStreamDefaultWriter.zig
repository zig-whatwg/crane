//! WritableStreamDefaultWriter Implementation
//!
//! WHATWG Streams Standard: https://streams.spec.whatwg.org/#default-writer-class
//!
//! A writable stream writer designed to be vended by a WritableStream.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const WritableStreamDefaultWriter = interfaces.WritableStreamDefaultWriter;

// Import streams infrastructure
const AsyncPromise = @import("streams_async_promise").AsyncPromise;

pub const State = WritableStreamDefaultWriter.State;

pub const ImplError = error{

    TypeError,
    OutOfMemory,
    InvalidState,
};

/// Internal state for WritableStreamDefaultWriter
///
/// This mirrors the internal slots defined in WHATWG Streams spec § 4.6.4
pub const InternalState = struct {
    /// [[closedPromise]]: Promise returned by closed getter
    closed_promise: ?*AsyncPromise(void),

    /// [[readyPromise]]: Promise returned by ready getter
    ready_promise: ?*AsyncPromise(void),

    /// [[stream]]: WritableStream this writer is locked to
    stream: ?*runtime.Instance,

    /// Resource management
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        // Clean up promises if needed
        // Future: Properly manage promise lifecycle
        allocator.destroy(self);
    }
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(internal.allocator);
    }
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
///
/// Spec: https://streams.spec.whatwg.org/#writablestreamdefaultwriter-constructor
/// new WritableStreamDefaultWriter(stream)
///
/// Steps:
/// 1. Perform ? SetUpWritableStreamDefaultWriter(this, stream)
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, stream: *runtime.Instance) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &WritableStreamDefaultWriter.vtable, ctx);
    errdefer deinit(instance);

    // SetUpWritableStreamDefaultWriter
    try setUpWritableStreamDefaultWriter(instance, stream, allocator);

    return instance;
}

/// Getter for closed
///
/// Spec: https://streams.spec.whatwg.org/#default-writer-closed
/// Returns: Promise<undefined>
///
/// Steps:
/// 1. Return this.[[closedPromise]]
pub fn get_closed(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    if (internal.closed_promise) |promise| {
        return @ptrCast(promise);
    }

    return error.InvalidState;
}

/// Getter for desiredSize
///
/// Spec: https://streams.spec.whatwg.org/#default-writer-desired-size
/// Returns: unrestricted double? (nullable)
///
/// Steps:
/// 1. If this.[[stream]] is undefined, throw TypeError
/// 2. Return WritableStreamDefaultWriterGetDesiredSize(this)
pub fn get_desiredSize(instance: *runtime.Instance) ImplError!f64 {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // 1. If stream is undefined, throw TypeError
    const stream = internal.stream orelse return error.TypeError;

    // 2. Return WritableStreamDefaultWriterGetDesiredSize(this)
    return writableStreamDefaultWriterGetDesiredSize(stream);
}

/// Getter for ready
///
/// Spec: https://streams.spec.whatwg.org/#default-writer-ready
/// Returns: Promise<undefined>
///
/// Steps:
/// 1. Return this.[[readyPromise]]
pub fn get_ready(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    if (internal.ready_promise) |promise| {
        return @ptrCast(promise);
    }

    return error.InvalidState;
}

/// Operation: releaseLock
///
/// Spec: https://streams.spec.whatwg.org/#default-writer-release-lock
/// Steps:
/// 1. Let stream = this.[[stream]]
/// 2. If stream is undefined, return
/// 3. Assert: stream.[[writer]] is not undefined
/// 4. Perform WritableStreamDefaultWriterRelease(this)
pub fn call_releaseLock(instance: *runtime.Instance) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // 1. Let stream = this.[[stream]]
    const stream = internal.stream orelse return; // 2. If undefined, return

    // 4. Perform WritableStreamDefaultWriterRelease(this)
    writableStreamDefaultWriterRelease(instance, stream);
}

/// Operation: abort
///
/// Spec: https://streams.spec.whatwg.org/#default-writer-abort
/// Arguments:
///   reason: Abort reason (optional)
/// Returns: Promise<undefined>
///
/// Steps:
/// 1. If this.[[stream]] is undefined, return promise rejected with TypeError
/// 2. Return WritableStreamDefaultWriterAbort(this, reason)
pub fn call_abort(instance: *runtime.Instance, reason: *const anyopaque) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // 1. If stream is undefined, return promise rejected with TypeError
    const stream = internal.stream orelse return error.TypeError;

    // 2. Return WritableStreamDefaultWriterAbort(this, reason)
    return writableStreamDefaultWriterAbort(instance, stream, reason);
}

/// Operation: write
///
/// Spec: https://streams.spec.whatwg.org/#default-writer-write
/// Arguments:
///   chunk: Data to write
/// Returns: Promise<undefined>
///
/// Steps:
/// 1. If this.[[stream]] is undefined, return promise rejected with TypeError
/// 2. Return WritableStreamDefaultWriterWrite(this, chunk)
pub fn call_write(instance: *runtime.Instance, chunk: *const anyopaque) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // 1. If stream is undefined, return promise rejected with TypeError
    const stream = internal.stream orelse return error.TypeError;

    // 2. Return WritableStreamDefaultWriterWrite(this, chunk)
    return writableStreamDefaultWriterWrite(instance, stream, chunk);
}

/// Operation: close
pub fn call_close(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // 1. Let stream = this.[[stream]]
    const stream = internal.stream orelse {
        // 2. If stream is undefined, return promise rejected with TypeError
        return error.TypeError;
    };

    // 3. If WritableStreamCloseQueuedOrInFlight(stream) is true, return promise rejected with TypeError
    const stream_state = stream.getState(interfaces.WritableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.InvalidState;

    if (writableStreamCloseQueuedOrInFlight(stream_internal)) {
        return error.TypeError;
    }

    // 4. Return WritableStreamDefaultWriterClose(this)
    return writableStreamDefaultWriterClose(instance);
}

// ============================================================================
// Abstract Operations
// ============================================================================

/// SetUpWritableStreamDefaultWriter
///
/// Spec: https://streams.spec.whatwg.org/#set-up-writable-stream-default-writer
/// Arguments:
///   writer: WritableStreamDefaultWriter instance
///   stream: WritableStream to lock to
fn setUpWritableStreamDefaultWriter(
    writer: *runtime.Instance,
    stream: *runtime.Instance,
    allocator: std.mem.Allocator,
) !void {
    const writer_state = writer.getState(State);
    const stream_state = stream.getState(interfaces.WritableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.InvalidState;

    // 1. If ! IsWritableStreamLocked(stream) is true, throw a TypeError exception
    if (isWritableStreamLocked(stream_internal)) {
        return error.TypeError;
    }

    // Create writer internal state
    const writer_internal = try allocator.create(InternalState);
    errdefer allocator.destroy(writer_internal);

    // Get event loop from stream
    const loop = stream_internal.event_loop;

    // Initialize promises
    // Future: Create proper AsyncPromise instances
    const closed_promise = try AsyncPromise(void).init(allocator, loop);
    const ready_promise = try AsyncPromise(void).init(allocator, loop);

    writer_internal.* = .{
        .closed_promise = closed_promise,
        .ready_promise = ready_promise,
        .stream = stream,
        .allocator = allocator,
    };

    writer_state.own._internal = writer_internal;

    // 2. Set writer.[[stream]] to stream
    // (already done above)

    // 3. Set stream.[[writer]] to writer
    stream_internal.writer = .{ .default = writer };

    // 4. Set up promises based on stream state
    switch (stream_internal.state) {
        .writable => {
            // If backpressure, ready stays pending; else fulfill it
            if (stream_internal.backpressure) {
                // ready_promise stays pending
            } else {
                ready_promise.fulfill({});
            }
            // closed_promise stays pending
        },
        .erroring => {
            // Both promises stay pending
            // Future: Implement proper promise state
        },
        .closed => {
            // Fulfill ready and closed promises
            ready_promise.fulfill({});
            closed_promise.fulfill({});
        },
        .errored => {
            // Reject both promises with stored error
            // Future: Properly reject with stored_error
            ready_promise.fulfill({}); // Placeholder
            closed_promise.fulfill({}); // Placeholder
        },
    }
}

/// IsWritableStreamLocked
///
/// Spec: https://streams.spec.whatwg.org/#is-writable-stream-locked
fn isWritableStreamLocked(stream_internal: *const @import("WritableStream.zig").InternalState) bool {
    return stream_internal.writer != .none;
}

/// WritableStreamCloseQueuedOrInFlight
///
/// Spec: https://streams.spec.whatwg.org/#writable-stream-close-queued-or-in-flight
fn writableStreamCloseQueuedOrInFlight(stream_internal: *const @import("WritableStream.zig").InternalState) bool {
    return stream_internal.close_request != null or stream_internal.in_flight_close_request != null;
}

/// WritableStreamDefaultWriterClose
///
/// Spec: https://streams.spec.whatwg.org/#writable-stream-default-writer-close
/// Returns: Promise<undefined>
///
/// Simplified for now - returns a placeholder promise
fn writableStreamDefaultWriterClose(writer: *runtime.Instance) !*const anyopaque {
    const state = writer.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Future: Implement full WritableStreamClose algorithm
    // For now, just return the closed promise
    if (internal.closed_promise) |promise| {
        return @ptrCast(promise);
    }

    return error.InvalidState;
}

/// WritableStreamDefaultWriterGetDesiredSize
///
/// Spec: https://streams.spec.whatwg.org/#writable-stream-default-writer-get-desired-size
/// Arguments:
///   stream: WritableStream instance
/// Returns: unrestricted double? (nullable double)
///
/// Steps:
/// 1. Let stream = writer.[[stream]]
/// 2. Let state = stream.[[state]]
/// 3. If state is "errored" or "erroring", return null
/// 4. If state is "closed", return 0
/// 5. Return WritableStreamDefaultControllerGetDesiredSize(stream.[[controller]])
fn writableStreamDefaultWriterGetDesiredSize(stream: *runtime.Instance) !f64 {
    const stream_state = stream.getState(interfaces.WritableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.InvalidState;

    // 2. Let state = stream.[[state]]
    const state = stream_internal.state;

    // 3. If state is "errored" or "erroring", return null
    // Note: WebIDL doesn't have nullable primitives, so we return NaN for null
    if (state == .errored or state == .erroring) {
        return std.math.nan(f64);
    }

    // 4. If state is "closed", return 0
    if (state == .closed) {
        return 0.0;
    }

    // 5. Return WritableStreamDefaultControllerGetDesiredSize(stream.[[controller]])
    if (stream_internal.controller) |controller| {
        return writableStreamDefaultControllerGetDesiredSize(controller);
    }

    return error.InvalidState;
}

/// WritableStreamDefaultControllerGetDesiredSize
///
/// Spec: https://streams.spec.whatwg.org/#writable-stream-default-controller-get-desired-size
/// Arguments:
///   controller: WritableStreamDefaultController instance
/// Returns: double (high water mark - queue total size)
fn writableStreamDefaultControllerGetDesiredSize(controller: *runtime.Instance) f64 {
    const controller_state = controller.getState(interfaces.WritableStreamDefaultController.State);
    const controller_internal = controller_state.own._internal orelse return std.math.nan(f64);

    return controller_internal.strategy_hwm - controller_internal.queue_total_size;
}

/// WritableStreamDefaultWriterRelease
///
/// Spec: https://streams.spec.whatwg.org/#writable-stream-default-writer-release
/// Arguments:
///   writer: WritableStreamDefaultWriter instance
///   stream: WritableStream instance
///
/// Simplified for now - just releases the lock
fn writableStreamDefaultWriterRelease(writer: *runtime.Instance, stream: *runtime.Instance) void {
    const writer_state = writer.getState(State);
    const writer_internal = writer_state.own._internal orelse return;

    const stream_state = stream.getState(interfaces.WritableStream.State);
    const stream_internal = stream_state.own._internal orelse return;

    // Release lock
    stream_internal.writer = .none;
    writer_internal.stream = null;

    // Future: Reject pending promises
}

/// WritableStreamDefaultWriterAbort
///
/// Spec: https://streams.spec.whatwg.org/#writable-stream-default-writer-abort
/// Arguments:
///   writer: WritableStreamDefaultWriter instance
///   stream: WritableStream instance
///   reason: Abort reason
/// Returns: Promise<undefined>
///
/// Simplified - returns placeholder promise
fn writableStreamDefaultWriterAbort(
    writer: *runtime.Instance,
    stream: *runtime.Instance,
    reason: *const anyopaque,
) !*const anyopaque {
    const writer_state = writer.getState(State);
    const writer_internal = writer_state.own._internal orelse return error.InvalidState;

    // Future: Implement full WritableStreamAbort algorithm
    _ = stream;
    _ = reason;

    // For now, return closed promise as placeholder
    if (writer_internal.closed_promise) |promise| {
        return @ptrCast(promise);
    }

    return error.InvalidState;
}

/// WritableStreamDefaultWriterWrite
///
/// Spec: https://streams.spec.whatwg.org/#writable-stream-default-writer-write
/// Arguments:
///   writer: WritableStreamDefaultWriter instance
///   stream: WritableStream instance
///   chunk: Data to write
/// Returns: Promise<undefined>
///
/// Steps:
/// 1. Let stream be writer.[[stream]]
/// 2. Assert: stream is not undefined
/// 3. Let controller be stream.[[controller]]
/// 4. Let chunkSize be WritableStreamDefaultControllerGetChunkSize(controller, chunk)
/// 5. If stream is not equal to writer.[[stream]], return promise rejected with TypeError
/// 6. Let state be stream.[[state]]
/// 7. If state is "errored", return promise rejected with stream.[[storedError]]
/// 8. If WritableStreamCloseQueuedOrInFlight(stream) or state is "closed",
///    return promise rejected with TypeError
/// 9. If state is "erroring", return promise rejected with stream.[[storedError]]
/// 10. Assert: state is "writable"
/// 11. Let promise be WritableStreamDefaultControllerWrite(controller, chunk, chunkSize)
/// 12. Return promise
fn writableStreamDefaultWriterWrite(
    writer: *runtime.Instance,
    stream: *runtime.Instance,
    chunk: *const anyopaque,
) !*const anyopaque {
    const writer_state = writer.getState(State);
    const writer_internal = writer_state.own._internal orelse return error.InvalidState;

    // 1-2. Get stream (already passed in, verify it matches)
    if (writer_internal.stream != stream) {
        return error.TypeError; // 5. Stream mismatch
    }

    // 3. Get controller
    const stream_state = stream.getState(interfaces.WritableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.InvalidState;
    const controller = stream_internal.controller orelse return error.InvalidState;

    // 4. Get chunk size (simplified - use 1.0 for now)
    // Future: Call WritableStreamDefaultControllerGetChunkSize
    const chunk_size: f64 = 1.0;

    // 6. Let state be stream.[[state]]
    const current_state = stream_internal.state;

    // 7. If errored, reject with stored error
    if (current_state == .errored) {
        return error.TypeError; // Future: Reject with actual stored_error
    }

    // 8. If close queued/in-flight or closed, reject with TypeError
    if (writableStreamCloseQueuedOrInFlight(stream_internal) or current_state == .closed) {
        return error.TypeError;
    }

    // 9. If erroring, reject with stored error
    if (current_state == .erroring) {
        return error.TypeError; // Future: Reject with actual stored_error
    }

    // 10. Assert: state is "writable"
    if (current_state != .writable) {
        return error.InvalidState;
    }

    // 11. Let promise be WritableStreamDefaultControllerWrite(controller, chunk, chunkSize)
    const WritableStreamDefaultController = @import("WritableStreamDefaultController.zig");
    const write_promise = try WritableStreamDefaultController.write(controller, chunk, chunk_size);

    // 12. Return promise
    return @ptrCast(write_promise);
}
