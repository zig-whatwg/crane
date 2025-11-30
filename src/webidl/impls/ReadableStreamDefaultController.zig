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

    /// [[startAlgorithm]]: Underlying source start callback
    /// Stored for invocation after constructor returns (when V8 wrapper exists)
    start_algorithm: ?*Algorithm,

    /// [[pullAlgorithm]]: Underlying source pull callback
    pull_algorithm: ?*Algorithm,

    /// [[cancelAlgorithm]]: Underlying source cancel callback
    cancel_algorithm: ?*Algorithm,

    /// Resource management
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        // Clean up algorithms
        if (self.start_algorithm) |algo| {
            algo.deinit();
            allocator.destroy(algo);
        }
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
pub fn get_desiredSize(instance: *runtime.Instance) anyerror!?f64 {
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
pub fn call_error(instance: *runtime.Instance, e: webidl.Opt(*const anyopaque)) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Perform error
    const error_ptr: *const anyopaque = if (e.was_passed) e.value else @ptrFromInt(1);
    readableStreamDefaultControllerError(internal, error_ptr);
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
pub fn readableStreamDefaultControllerError(internal: *InternalState, e: *const anyopaque) void {
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
pub fn call_close(instance: *runtime.Instance) anyerror!void {
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

/// ReadableStreamDefaultController.[[CancelSteps]](reason)
///
/// Spec: https://streams.spec.whatwg.org/#readable-stream-default-controller-cancel-steps
///
/// Steps:
/// 1. Perform ! ResetQueue(controller)
/// 2. Let result be the result of performing controller.[[cancelAlgorithm]], passing reason
/// 3. Perform ! ReadableStreamDefaultControllerClearAlgorithms(controller)
/// 4. Return result
///
/// Returns: A promise resolved when the cancel algorithm completes
pub fn cancelSteps(controller: *runtime.Instance, reason: *const anyopaque) !*AsyncPromise(void) {
    const state = controller.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Reset queue
    internal.queue.resetQueue();
    internal.queue_total_size = 0.0;

    // Step 2: Perform cancel algorithm
    const cancel_result: ?*AsyncPromise(void) = if (internal.cancel_algorithm) |algo| blk: {
        // Invoke the cancel algorithm with the reason
        const result = algo.invokeWithArg(controller, reason) catch {
            // On error, create a rejected promise
            const stream_instance_for_loop = internal.stream orelse return error.InvalidState;
            const loop = stream_instance_for_loop.ctx.getEventLoop() catch return error.InvalidState;
            const promise = try AsyncPromise(void).init(internal.allocator, loop);
            const exception = try webidl.errors.Exception.typeError(internal.allocator, "Cancel algorithm failed");
            promise.reject(exception);
            break :blk promise;
        };
        break :blk result;
    } else null;

    // Step 3: Clear algorithms (but don't free cancel_algorithm yet since we might be using it)
    // Note: We need to clear AFTER the cancel algorithm runs per spec
    if (internal.pull_algorithm) |algo| {
        algo.deinit();
        internal.allocator.destroy(algo);
    }
    internal.pull_algorithm = null;
    internal.strategy_size_algorithm = null;

    // Now clear cancel_algorithm since we've finished using it
    if (internal.cancel_algorithm) |algo| {
        algo.deinit();
        internal.allocator.destroy(algo);
    }
    internal.cancel_algorithm = null;

    // Step 4: Return result
    if (cancel_result) |result| {
        return result;
    }

    // No cancel algorithm - return a resolved promise
    const stream_instance_for_promise = internal.stream orelse return error.InvalidState;
    const loop = stream_instance_for_promise.ctx.getEventLoop() catch return error.InvalidState;
    const promise = try AsyncPromise(void).init(internal.allocator, loop);
    promise.fulfill({});
    return promise;
}

/// ReadableStreamDefaultController.[[CancelSteps]](reason) - optional reason version
///
/// Same as cancelSteps but accepts optional reason (null = undefined in JS)
pub fn cancelStepsWithOptReason(controller: *runtime.Instance, reason: ?*anyopaque) !*AsyncPromise(void) {
    const state = controller.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Reset queue
    internal.queue.resetQueue();
    internal.queue_total_size = 0.0;

    // Step 2: Perform cancel algorithm (with optional reason)
    const cancel_result: ?*AsyncPromise(void) = if (internal.cancel_algorithm) |algo| blk: {
        // Invoke the cancel algorithm with the optional reason
        // Note: invokeWithOptArg handles null by not passing the arg to V8
        const result = algo.invokeWithOptArg(controller, reason) catch {
            // On error, create a rejected promise
            const stream_instance_for_loop = internal.stream orelse return error.InvalidState;
            const loop = stream_instance_for_loop.ctx.getEventLoop() catch return error.InvalidState;
            const promise = try AsyncPromise(void).init(internal.allocator, loop);
            const exception = try webidl.errors.Exception.typeError(internal.allocator, "Cancel algorithm failed");
            promise.reject(exception);
            break :blk promise;
        };
        break :blk result;
    } else null;

    // Step 3: Clear algorithms
    if (internal.pull_algorithm) |algo| {
        algo.deinit();
        internal.allocator.destroy(algo);
    }
    internal.pull_algorithm = null;
    internal.strategy_size_algorithm = null;

    if (internal.cancel_algorithm) |algo| {
        algo.deinit();
        internal.allocator.destroy(algo);
    }
    internal.cancel_algorithm = null;

    // Step 4: Return result
    if (cancel_result) |result| {
        return result;
    }

    // No cancel algorithm - return a resolved promise
    const stream_instance_for_promise = internal.stream orelse return error.InvalidState;
    const loop = stream_instance_for_promise.ctx.getEventLoop() catch return error.InvalidState;
    const promise = try AsyncPromise(void).init(internal.allocator, loop);
    promise.fulfill({});
    return promise;
}

/// Operation: enqueue
///
/// Spec: https://streams.spec.whatwg.org/#rsdfc-enqueue
/// undefined enqueue(optional any chunk)
///
/// Steps:
/// 1. If ! ReadableStreamDefaultControllerCanCloseOrEnqueue(this) is false, throw TypeError
/// 2. Perform ? ReadableStreamDefaultControllerEnqueue(this, chunk)
pub fn call_enqueue(instance: *runtime.Instance, chunk: webidl.Opt(*const anyopaque)) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Check if we can enqueue
    if (!canCloseOrEnqueue(internal)) {
        return error.TypeError;
    }

    // Step 2: Perform enqueue
    const chunk_ptr: *const anyopaque = if (chunk.was_passed) chunk.value else @ptrFromInt(1);
    try readableStreamDefaultControllerEnqueue(internal, chunk_ptr);
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
            .byob => return error.InvalidState, // BYOB readers use ReadableByteStreamController, not DefaultController
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
    // The chunk is a V8 Global<Value>* pointer from JavaScript
    // Store it directly as v8_value so it can be passed back unchanged
    const value: streams_common.JSValue = .{ .v8_value = @constCast(chunk) };

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

/// ReadableStreamDefaultControllerHasBackpressure(controller)
///
/// Spec: https://streams.spec.whatwg.org/#readable-stream-default-controller-has-backpressure
///
/// Used by TransformStream to determine if backpressure should be applied.
///
/// Steps:
/// 1. If ! ReadableStreamDefaultControllerShouldCallPull(controller) is true, return false.
/// 2. Otherwise, return true.
pub fn hasBackpressure(instance: *runtime.Instance) bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return true; // Safe default

    // HasBackpressure is simply the inverse of shouldCallPull
    return !shouldCallPull(internal);
}

/// ReadableStreamGetNumReadRequests(stream)
///
/// Returns the number of pending read requests on the stream's reader
fn readableStreamGetNumReadRequests(stream_internal: *const @import("ReadableStream.zig").InternalState) usize {
    // Get reader
    const reader_instance = switch (stream_internal.reader) {
        .default => |r| r,
        .byob => return 0, // BYOB readers use ReadableByteStreamController, not DefaultController
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

        // Handle promise settlement (sync or async)
        // Step 7-8: Chain promise to fulfillment/rejection handlers
        handlePullPromise(internal, controller_instance, pull_promise);
    } else {
        // No pull algorithm - fulfill immediately
        handlePullFulfillment(internal);
    }
}

/// Handle pull algorithm fulfillment
/// Spec: § 4.9.5 Step 7
fn handlePullFulfillment(internal: *InternalState) void {
    // Step 7.1: Set pulling to false
    internal.pulling = false;

    // Step 7.2: If pullAgain is true, call pull again
    if (internal.pull_again) {
        internal.pull_again = false;
        readableStreamDefaultControllerCallPullIfNeeded(internal);
    }
}

/// Handle pull promise settlement
/// Supports both synchronous (for testing) and asynchronous (with event loop) promises
/// Spec: § 4.9.5 Steps 7-8
fn handlePullPromise(internal: *InternalState, instance: *runtime.Instance, pull_promise: *AsyncPromise(void)) void {
    // Step 7: Upon fulfillment of pullPromise
    if (pull_promise.isFulfilled()) {
        handlePullFulfillment(internal);
        return;
    }

    // Step 8: Upon rejection of pullPromise with reason e
    if (pull_promise.isRejected()) {
        onPullRejected(internal, pull_promise.state.rejected);
        return;
    }

    // Promise is still pending - use async handling via onSettleCtx
    // This attaches handlers without creating a chained promise (no memory leak)
    pull_promise.onSettleCtx(
        pullPromiseFulfilledCallback,
        pullPromiseRejectedCallback,
        @ptrCast(internal),
    ) catch {
        // If we can't attach handlers, assume immediate fulfillment
        handlePullFulfillment(internal);
    };
    _ = instance; // Instance kept for consistency with ReadableByteStreamController pattern
}

/// Context for async pull promise handling
const PullPromiseContext = struct {
    internal: *InternalState,
};

/// Callback for pull promise fulfillment (async handling)
fn pullPromiseFulfilledCallback(ctx_ptr: *anyopaque, _: void) anyerror!void {
    const internal: *InternalState = @ptrCast(@alignCast(ctx_ptr));
    handlePullFulfillment(internal);
}

/// Callback for pull promise rejection (async handling)
fn pullPromiseRejectedCallback(ctx_ptr: *anyopaque, exception: webidl.errors.Exception) anyerror!void {
    const internal: *InternalState = @ptrCast(@alignCast(ctx_ptr));
    onPullRejected(internal, exception);
}

/// Handle pull promise rejection
/// Spec: § 4.9.5 Step 8
fn onPullRejected(internal: *InternalState, error_value: webidl.errors.Exception) void {
    // Step 8.1: Perform ! ReadableStreamDefaultControllerError(controller, e)
    const error_msg = switch (error_value) {
        .simple => |s| s.message,
        else => "Pull algorithm failed",
    };

    const js_error = streams_common.JSValue{ .string = error_msg };
    readableStreamDefaultControllerError(internal, @ptrCast(&js_error));
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

        // Extract the V8 value from JSValue
        // If it's a v8_value, use the stored pointer directly
        // Otherwise, create a pointer to the JSValue for conversion
        const value_ptr: ?*anyopaque = switch (chunk) {
            .v8_value => |v| v,
            else => blk: {
                // Allocate the JSValue on the heap so it can be passed as *anyopaque
                const chunk_ptr = try internal.allocator.create(streams_common.JSValue);
                chunk_ptr.* = chunk;
                break :blk @ptrCast(chunk_ptr);
            },
        };

        read_promise.*.fulfill(ReadableStreamDefaultReaderImpl.ReadResult{
            .value = value_ptr,
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
    const allocator = controller_instance.ctx.getAllocator();
    const internal = try allocator.create(InternalState);
    internal.* = .{
        .stream = stream_instance,
        .queue = QueueWithSizes.init(allocator),
        .queue_total_size = 0.0,
        .started = false,
        .close_requested = false,
        .pull_again = false,
        .pulling = false,
        .strategy_size_algorithm = null,
        .strategy_hwm = strategy_hwm,
        .start_algorithm = null, // Already started via CreateReadableStream
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
