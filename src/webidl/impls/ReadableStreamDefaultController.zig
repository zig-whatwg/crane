//! ReadableStreamDefaultController Implementation
//!
//! WHATWG Streams Standard: https://streams.spec.whatwg.org/#rsdfc-class
//!
//! Controls a ReadableStream, allowing enqueue/close/error operations.
//! Manages the internal queue and pull mechanism.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const ReadableStreamDefaultController = interfaces.ReadableStreamDefaultController;

// Import streams infrastructure
const streams_common = @import("streams_common");
const QueueWithSizes = @import("streams_queue").QueueWithSizes;

pub const State = ReadableStreamDefaultController.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    RangeError,
    InvalidState,
    OutOfMemory,
};

/// Internal state for ReadableStreamDefaultController
///
/// Per WHATWG Streams spec § 4.9 ReadableStreamDefaultController
/// These are the internal slots defined by the spec.
pub const InternalState = struct {
    /// [[stream]]: ReadableStream instance this controller controls
    stream: ?*runtime.Instance,

    /// [[queue]]: Queue of chunks waiting to be read
    /// Uses QueueWithSizes for queue management
    queue: QueueWithSizes,

    /// [[queueTotalSize]]: Total size of all chunks in queue
    /// Note: This is redundant with queue.queue_total_size but kept for clarity
    queue_total_size: f64,

    /// [[started]]: Whether start algorithm has completed
    started: bool,

    /// [[closeRequested]]: Whether close has been requested
    close_requested: bool,

    /// [[pullAgain]]: Whether to call pull again after current pull
    pull_again: bool,

    /// [[pulling]]: Whether pull algorithm is currently executing
    pulling: bool,

    /// [[strategySizeAlgorithm]]: Function to compute chunk size
    /// For now, defaults to returning 1
    strategy_size_algorithm: ?*const anyopaque,

    /// [[strategyHWM]]: High water mark for backpressure
    strategy_hwm: f64,

    /// [[pullAlgorithm]]: Underlying source pull callback
    pull_algorithm: ?*const anyopaque,

    /// [[cancelAlgorithm]]: Underlying source cancel callback
    cancel_algorithm: ?*const anyopaque,

    /// Resource management
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        // Clean up queue
        self.queue.deinit();

        // Free the internal state itself
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
    // TODO: Clean up your instance resources here
    runtime.Instance.deinit(instance);
}

/// Getter for desiredSize
///
/// Spec: https://streams.spec.whatwg.org/#rsdfc-desired-size
/// readonly attribute unrestricted double? desiredSize
///
/// Returns the desired size to fill the stream's internal queue.
/// Returns null if the stream is closed or errored.
///
/// ReadableStreamDefaultControllerGetDesiredSize(controller):
/// 1. Let stream be controller.[[stream]]
/// 2. Let state be stream.[[state]]
/// 3. If state is "errored", return null
/// 4. If state is "closed", return 0
/// 5. Return controller.[[strategyHWM]] - controller.[[queueTotalSize]]
pub fn get_desiredSize(instance: *runtime.Instance) ImplError!f64 {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Get stream state
    const stream_instance = internal.stream orelse return std.math.nan(f64);
    const stream_state = stream_instance.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return std.math.nan(f64);

    // Step 2-4: Check stream state
    // Note: Spec says return null for errored, but interface expects f64
    // We return NaN to represent null since unrestricted double allows NaN
    return switch (stream_internal.state) {
        .errored => std.math.nan(f64),
        .closed => 0.0,
        .readable => internal.strategy_hwm - internal.queue_total_size,
    };
}

/// Operation: error
///
/// Spec: https://streams.spec.whatwg.org/#rsdfc-error
/// undefined error(optional any e)
///
/// Steps:
/// 1. Perform ! ReadableStreamDefaultControllerError(this, e)
pub fn call_error(instance: *runtime.Instance, e: *const anyopaque) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Perform error
    readableStreamDefaultControllerError(internal, e);
}

/// ReadableStreamDefaultControllerError(controller, e)
///
/// Spec: https://streams.spec.whatwg.org/#readable-stream-default-controller-error
///
/// Steps:
/// 1. Let stream be controller.[[stream]]
/// 2. If stream.[[state]] is not "readable", return
/// 3. Perform ! ResetQueue(controller)
/// 4. Perform ! ReadableStreamDefaultControllerClearAlgorithms(controller)
/// 5. Perform ! ReadableStreamError(stream, e)
fn readableStreamDefaultControllerError(internal: *InternalState, e: *const anyopaque) void {
    // Step 1: Get stream
    const stream_instance = internal.stream orelse return;
    const stream_state = stream_instance.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return;

    // Step 2: Check stream state
    if (stream_internal.state != .readable) {
        return;
    }

    // Step 3: Reset queue
    internal.queue.resetQueue();
    internal.queue_total_size = 0.0;

    // Step 4: Clear algorithms
    readableStreamDefaultControllerClearAlgorithms(internal);

    // Step 5: Error the stream
    const ReadableStreamImpl = @import("ReadableStream.zig");
    ReadableStreamImpl.readableStreamError(stream_internal, e);
}

/// Operation: close
///
/// Spec: https://streams.spec.whatwg.org/#rsdfc-close
/// undefined close()
///
/// Steps:
/// 1. If ! ReadableStreamDefaultControllerCanCloseOrEnqueue(this) is false, throw TypeError
/// 2. Perform ! ReadableStreamDefaultControllerClose(this)
pub fn call_close(instance: *runtime.Instance) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Check if we can close
    if (!canCloseOrEnqueue(internal)) {
        return error.TypeError;
    }

    // Step 2: Perform close
    readableStreamDefaultControllerClose(internal);
}

/// ReadableStreamDefaultControllerClose(controller)
///
/// Spec: https://streams.spec.whatwg.org/#readable-stream-default-controller-close
///
/// Steps:
/// 1. If ! ReadableStreamDefaultControllerCanCloseOrEnqueue(controller) is false, return
/// 2. Let stream be controller.[[stream]]
/// 3. Set controller.[[closeRequested]] to true
/// 4. If controller.[[queue]] is empty, perform ! ReadableStreamDefaultControllerClearAlgorithms and ReadableStreamClose
fn readableStreamDefaultControllerClose(internal: *InternalState) void {
    // Step 1: Check if we can close
    if (!canCloseOrEnqueue(internal)) {
        return;
    }

    // Step 2: Get stream
    const stream_instance = internal.stream orelse return;
    const stream_state = stream_instance.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return;

    // Step 3: Set closeRequested
    internal.close_requested = true;

    // Step 4: If queue is empty, close the stream
    if (internal.queue.queue.len == 0) {
        // Clear algorithms
        readableStreamDefaultControllerClearAlgorithms(internal);

        // Close stream
        const ReadableStreamImpl = @import("ReadableStream.zig");
        ReadableStreamImpl.readableStreamClose(stream_internal);
    }
}

/// ReadableStreamDefaultControllerClearAlgorithms(controller)
fn readableStreamDefaultControllerClearAlgorithms(internal: *InternalState) void {
    internal.pull_algorithm = null;
    internal.cancel_algorithm = null;
    internal.strategy_size_algorithm = null;
}

/// Operation: enqueue
///
/// Spec: https://streams.spec.whatwg.org/#rsdfc-enqueue
/// undefined enqueue(optional any chunk)
///
/// Steps:
/// 1. If ! ReadableStreamDefaultControllerCanCloseOrEnqueue(this) is false, throw TypeError
/// 2. Perform ? ReadableStreamDefaultControllerEnqueue(this, chunk)
pub fn call_enqueue(instance: *runtime.Instance, chunk: *const anyopaque) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Check if we can enqueue
    if (!canCloseOrEnqueue(internal)) {
        return error.TypeError;
    }

    // Step 2: Perform enqueue
    try readableStreamDefaultControllerEnqueue(internal, chunk);
}

/// ReadableStreamDefaultControllerCanCloseOrEnqueue(controller)
fn canCloseOrEnqueue(internal: *InternalState) bool {
    const stream_instance = internal.stream orelse return false;
    const stream_state = stream_instance.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return false;

    // Can close or enqueue if:
    // - closeRequested is false AND
    // - stream state is "readable"
    return !internal.close_requested and stream_internal.state == .readable;
}

/// ReadableStreamDefaultControllerEnqueue(controller, chunk)
///
/// Spec: https://streams.spec.whatwg.org/#readable-stream-default-controller-enqueue
///
/// Steps:
/// 1. If ! ReadableStreamDefaultControllerCanCloseOrEnqueue(controller) is false, return
/// 2. Let stream be controller.[[stream]]
/// 3. If ! IsReadableStreamLocked(stream) is true and ! ReadableStreamGetNumReadRequests(stream) > 0,
///    perform ! ReadableStreamFulfillReadRequest(stream, chunk, false)
/// 4. Otherwise, enqueue chunk in queue
fn readableStreamDefaultControllerEnqueue(internal: *InternalState, chunk: *const anyopaque) !void {
    // Step 1: Double-check we can enqueue
    if (!canCloseOrEnqueue(internal)) {
        return;
    }

    // Step 2: Get stream
    const stream_instance = internal.stream orelse return error.InvalidState;
    const stream_state = stream_instance.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.InvalidState;

    // Step 3: If stream has reader with pending read requests, fulfill immediately
    if (stream_internal.reader != .none) {
        // Get reader's read requests
        const reader_instance = switch (stream_internal.reader) {
            .default => |r| r,
            .byob => return error.NotImplemented, // TODO: BYOB not yet supported
            .none => unreachable,
        };

        const reader_state = reader_instance.getState(interfaces.ReadableStreamDefaultReader.State);
        const reader_internal = reader_state.own._internal orelse return error.InvalidState;

        // If there are pending read requests, fulfill the first one
        if (reader_internal.read_requests.items.len > 0) {
            const read_request = reader_internal.read_requests.orderedRemove(0);

            // Fulfill with chunk
            const ReadableStreamDefaultReaderImpl = @import("ReadableStreamDefaultReader.zig");
            read_request.*.fulfill(ReadableStreamDefaultReaderImpl.ReadResult{
                .value = chunk,
                .done = false,
            });
            return;
        }
    }

    // Step 4: Otherwise, enqueue in queue
    // Calculate chunk size (for now, always 1)
    const chunk_size: f64 = 1.0; // TODO: Call strategySizeAlgorithm

    // Enqueue the chunk (chunk is already *const anyopaque, need to convert to Value)
    const value: streams_common.JSValue = @ptrCast(@constCast(chunk));
    try internal.queue.enqueueValueWithSize(value, chunk_size);
    internal.queue_total_size = internal.queue.queue_total_size;

    // Call pull if needed
    // TODO: Implement ReadableStreamDefaultControllerCallPullIfNeeded
}
