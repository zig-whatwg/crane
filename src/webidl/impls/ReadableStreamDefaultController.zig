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
const AsyncPromise = @import("streams_async_promise").AsyncPromise;
const Algorithm = @import("streams_algorithm").Algorithm;

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
    pull_algorithm: ?*Algorithm,

    /// [[cancelAlgorithm]]: Underlying source cancel callback
    cancel_algorithm: ?*Algorithm,

    /// Resource management
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        // Clean up algorithms
        if (self.pull_algorithm) |algo| {
            algo.deinit();
            allocator.destroy(algo);
        }
        if (self.cancel_algorithm) |algo| {
            algo.deinit();
            allocator.destroy(algo);
        }

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
    // InternalState is set up by SetUpReadableStreamDefaultController
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
    // Deinit and free algorithms
    if (internal.pull_algorithm) |algo| {
        algo.deinit();
        internal.allocator.destroy(algo);
    }
    if (internal.cancel_algorithm) |algo| {
        algo.deinit();
        internal.allocator.destroy(algo);
    }

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
pub fn canCloseOrEnqueue(internal: *InternalState) bool {
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
                .value = @constCast(chunk),
                .done = false,
            });
            return;
        }
    }

    // Step 4: Otherwise, enqueue in queue
    // Calculate chunk size (for now, always 1)
    const chunk_size: f64 = 1.0; // Future: Invoke strategySizeAlgorithm(chunk) for dynamic sizing

    // Enqueue the chunk
    // In the real implementation, chunk would be a JavaScript value
    // For now, we wrap the opaque pointer in a JSValue
    const chunk_ptr: *anyopaque = @constCast(chunk);
    const value: streams_common.JSValue = .{ .object = {} }; // Placeholder - in real impl would box the JS value
    _ = chunk_ptr; // Will be used when we properly handle JS values

    try internal.queue.enqueueValueWithSize(value, chunk_size);
    internal.queue_total_size = internal.queue.queue_total_size;

    // Call pull if needed
    readableStreamDefaultControllerCallPullIfNeeded(internal);
}

/// ReadableStreamDefaultControllerShouldCallPull(controller)
///
/// Spec: https://streams.spec.whatwg.org/#readable-stream-default-controller-should-call-pull
///
/// Steps:
/// 1. Let stream be controller.[[stream]]
/// 2. If ! ReadableStreamDefaultControllerCanCloseOrEnqueue(controller) is false, return false
/// 3. If controller.[[started]] is false, return false
/// 4. If ! IsReadableStreamLocked(stream) is true and ! ReadableStreamGetNumReadRequests(stream) > 0, return true
/// 5. Let desiredSize be ! ReadableStreamDefaultControllerGetDesiredSize(controller)
/// 6. Assert: desiredSize is not null
/// 7. If desiredSize > 0, return true
/// 8. Return false
fn shouldCallPull(internal: *InternalState) bool {
    // Step 1: Get stream
    const stream_instance = internal.stream orelse return false;
    const stream_state = stream_instance.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return false;

    // Step 2: Check if can close or enqueue
    if (!canCloseOrEnqueue(internal)) {
        return false;
    }

    // Step 3: Check if started
    if (!internal.started) {
        return false;
    }

    // Step 4: If locked with pending reads, should pull
    if (stream_internal.reader != .none) {
        const num_requests = readableStreamGetNumReadRequests(stream_internal);
        if (num_requests > 0) {
            return true;
        }
    }

    // Step 5: Get desired size
    const desired_size = switch (stream_internal.state) {
        .errored => return false, // null in spec, but we can't pull anyway
        .closed => 0.0,
        .readable => internal.strategy_hwm - internal.queue_total_size,
    };

    // Step 6: Assert desiredSize is not null (handled by switch above)
    // Step 7: If desiredSize > 0, return true
    if (desired_size > 0.0) {
        return true;
    }

    // Step 8: Return false
    return false;
}

/// ReadableStreamGetNumReadRequests(stream)
///
/// Returns the number of pending read requests on the stream's reader
fn readableStreamGetNumReadRequests(stream_internal: *const @import("ReadableStream.zig").InternalState) usize {
    // Get reader
    const reader_instance = switch (stream_internal.reader) {
        .default => |r| r,
        .byob => return 0, // TODO: BYOB not yet supported
        .none => return 0,
    };

    const reader_state = reader_instance.getState(interfaces.ReadableStreamDefaultReader.State);
    const reader_internal = reader_state.own._internal orelse return 0;

    return reader_internal.read_requests.items.len;
}

/// ReadableStreamDefaultControllerCallPullIfNeeded(controller)
///
/// Spec: https://streams.spec.whatwg.org/#readable-stream-default-controller-call-pull-if-needed
///
/// Steps:
/// 1. Let shouldPull be ! ReadableStreamDefaultControllerShouldCallPull(controller)
/// 2. If shouldPull is false, return
/// 3. If controller.[[pulling]] is true,
///    1. Set controller.[[pullAgain]] to true
///    2. Return
/// 4. Assert: controller.[[pullAgain]] is false
/// 5. Set controller.[[pulling]] to true
/// 6. Let pullPromise be the result of performing controller.[[pullAlgorithm]]
/// 7. Upon fulfillment of pullPromise,
///    1. Set controller.[[pulling]] to false
///    2. If controller.[[pullAgain]] is true,
///       1. Set controller.[[pullAgain]] to false
///       2. Perform ! ReadableStreamDefaultControllerCallPullIfNeeded(controller)
/// 8. Upon rejection of pullPromise with reason e,
///    1. Perform ! ReadableStreamDefaultControllerError(controller, e)
pub fn readableStreamDefaultControllerCallPullIfNeeded(internal: *InternalState) void {
    // Step 1: Should we pull?
    const should_pull = shouldCallPull(internal);

    // Step 2: If not, return
    if (!should_pull) {
        return;
    }

    // Step 3: If already pulling, set pullAgain flag
    if (internal.pulling) {
        internal.pull_again = true;
        return;
    }

    // Step 4: Assert pullAgain is false
    std.debug.assert(!internal.pull_again);

    // Step 5: Set pulling to true
    internal.pulling = true;

    // Step 6: Perform pullAlgorithm
    if (internal.pull_algorithm) |algo| {
        // Get the controller instance from stream
        const stream_instance = internal.stream orelse {
            handlePullFulfillment(internal);
            return;
        };
        const stream_state = stream_instance.getState(interfaces.ReadableStream.State);
        const stream_internal = stream_state.own._internal orelse {
            handlePullFulfillment(internal);
            return;
        };
        const controller_instance = stream_internal.controller;

        // Invoke pull algorithm with controller as argument
        const pull_promise = algo.invoke(controller_instance) catch |err| {
            // On error, error the controller
            const err_value: *const anyopaque = @ptrCast(&err);
            readableStreamDefaultControllerError(internal, err_value);
            return;
        };

        // TODO: Chain the returned promise properly:
        // - On fulfillment: call handlePullFulfillment
        // - On rejection: call ReadableStreamDefaultControllerError with reason
        _ = pull_promise;

        // Simulate immediate fulfillment (until we have proper promise handling)
        handlePullFulfillment(internal);
    } else {
        // No pull algorithm - fulfill immediately
        handlePullFulfillment(internal);
    }
}

/// Handle pull algorithm fulfillment
fn handlePullFulfillment(internal: *InternalState) void {
    // Step 7.1: Set pulling to false
    internal.pulling = false;

    // Step 7.2: If pullAgain is true, call pull again
    if (internal.pull_again) {
        internal.pull_again = false;
        readableStreamDefaultControllerCallPullIfNeeded(internal);
    }
}

/// [[PullSteps]](readRequest)
///
/// Spec: https://streams.spec.whatwg.org/#readable-stream-default-controller-pull-steps
///
/// This is called by ReadableStreamDefaultReaderRead when a read() is requested.
///
/// Steps:
/// 1. Let stream be this.[[stream]]
/// 2. If this.[[queue]] is not empty,
///    1. Let chunk be ! DequeueValue(this)
///    2. If this.[[closeRequested]] is true and this.[[queue]] is empty,
///       1. Perform ! ReadableStreamDefaultControllerClearAlgorithms(this)
///       2. Perform ! ReadableStreamClose(stream)
///    3. Otherwise, perform ! ReadableStreamDefaultControllerCallPullIfNeeded(this)
///    4. Perform readRequest's chunk steps, given chunk
/// 3. Otherwise,
///    1. Perform ! ReadableStreamAddReadRequest(stream, readRequest)
///    2. Perform ! ReadableStreamDefaultControllerCallPullIfNeeded(this)
pub fn pullSteps(
    instance: *runtime.Instance,
    read_promise: *AsyncPromise(@import("ReadableStreamDefaultReader.zig").ReadResult),
) !void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Get stream
    const stream_instance = internal.stream orelse return error.InvalidState;
    const stream_state = stream_instance.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.InvalidState;

    // Step 2: If queue is not empty
    if (internal.queue.queue.len > 0) {
        // Step 2.1: Dequeue chunk
        const chunk = try internal.queue.dequeueValue();
        internal.queue_total_size = internal.queue.queue_total_size;

        // Step 2.2: If closeRequested and queue empty, close stream
        if (internal.close_requested and internal.queue.queue.len == 0) {
            // Step 2.2.1: Clear algorithms
            readableStreamDefaultControllerClearAlgorithms(internal);

            // Step 2.2.2: Close stream
            const ReadableStreamImpl = @import("ReadableStream.zig");
            ReadableStreamImpl.readableStreamClose(stream_internal);
        } else {
            // Step 2.3: Otherwise, call pull if needed
            readableStreamDefaultControllerCallPullIfNeeded(internal);
        }

        // Step 2.4: Perform chunk steps (fulfill promise with chunk)
        const ReadableStreamDefaultReaderImpl = @import("ReadableStreamDefaultReader.zig");

        // Allocate the chunk on the heap so it can be passed as *const anyopaque
        // In a real implementation, chunks would be JavaScript values managed by the runtime
        const chunk_ptr = try internal.allocator.create(streams_common.JSValue);
        chunk_ptr.* = chunk;

        read_promise.*.fulfill(ReadableStreamDefaultReaderImpl.ReadResult{
            .value = @ptrCast(chunk_ptr),
            .done = false,
        });
    } else {
        // Step 3: Queue is empty
        // Note: The promise is already added to read_requests by the reader
        // We just need to call pull if needed

        // Step 3.2: Call pull if needed
        readableStreamDefaultControllerCallPullIfNeeded(internal);
    }
}

/// SetUpReadableStreamDefaultController
///
/// Helper function to initialize a ReadableStreamDefaultController with algorithms
///
/// Parameters:
/// - stream: The ReadableStream instance to control
/// - controller: The ReadableStreamDefaultController instance
/// - pull_algorithm: The pull algorithm (optional)
/// - cancel_algorithm: The cancel algorithm (optional)
/// - strategy_hwm: High water mark for backpressure
pub fn setUpReadableStreamDefaultController(
    stream_instance: *runtime.Instance,
    controller_instance: *runtime.Instance,
    pull_algorithm: ?*Algorithm,
    cancel_algorithm: ?*Algorithm,
    strategy_hwm: f64,
) !void {
    const controller_state = controller_instance.getState(State);

    // Create internal state
    const allocator = controller_instance.allocator;
    const internal = try allocator.create(InternalState);
    internal.* = .{
        .stream = stream_instance,
        .queue = try QueueWithSizes.init(allocator),
        .queue_total_size = 0.0,
        .started = false,
        .close_requested = false,
        .pull_again = false,
        .pulling = false,
        .strategy_size_algorithm = null,
        .strategy_hwm = strategy_hwm,
        .pull_algorithm = pull_algorithm,
        .cancel_algorithm = cancel_algorithm,
        .allocator = allocator,
    };

    controller_state.own._internal = internal;

    // Mark as started
    internal.started = true;

    // Call pull if needed
    readableStreamDefaultControllerCallPullIfNeeded(internal);
}
