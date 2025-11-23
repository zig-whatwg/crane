//! WritableStreamDefaultController Implementation
//!
//! WHATWG Streams Standard: https://streams.spec.whatwg.org/#ws-default-controller-class
//!
//! Controller that allows control of a WritableStream's state and queue.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const WritableStreamDefaultController = interfaces.WritableStreamDefaultController;

// Import streams infrastructure
const queue_with_sizes = @import("streams_queue");
const AsyncPromise = @import("streams_async_promise").AsyncPromise;

pub const State = WritableStreamDefaultController.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    OutOfMemory,
    InvalidState,
};

/// Queue value type - can be a chunk or the close sentinel
pub const QueueValue = union(enum) {
    chunk: *anyopaque,
    close_sentinel: void,
};

/// Internal state for WritableStreamDefaultController
///
/// This mirrors the internal slots defined in WHATWG Streams spec § 4.5.4
pub const InternalState = struct {
    /// [[stream]]: WritableStream instance this controller controls
    stream: ?*runtime.Instance,

    /// [[writeAlgorithm]]: Underlying sink write callback
    write_algorithm: ?*const anyopaque,

    /// [[closeAlgorithm]]: Underlying sink close callback
    close_algorithm: ?*const anyopaque,

    /// [[abortAlgorithm]]: Underlying sink abort callback
    abort_algorithm: ?*const anyopaque,

    /// [[strategyHWM]]: High water mark for backpressure
    strategy_hwm: f64,

    /// [[strategySizeAlgorithm]]: Function to compute chunk size
    strategy_size_algorithm: ?*const anyopaque,

    /// [[started]]: Whether start algorithm has completed
    started: bool,

    /// [[queue]]: Internal queue of chunks (list of QueueValue)
    queue: std.ArrayList(QueueValue),

    /// [[queueTotalSize]]: Total size of all chunks in queue
    queue_total_size: f64,

    /// [[abortController]]: AbortController for canceling operations
    /// Future: Create proper AbortController instance
    abort_controller: ?*runtime.Instance,

    /// Resource management
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        // Clean up queue
        self.queue.deinit(allocator);
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
    // InternalState is set up by SetUpWritableStreamDefaultController
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

/// Getter for signal
///
/// Spec: https://streams.spec.whatwg.org/#ws-default-controller-signal
/// Returns: An AbortSignal that can be used to abort pending write/close operations
pub fn get_signal(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Return the AbortController's signal
    // Future: Implement proper AbortController.signal getter
    if (internal.abort_controller) |controller| {
        return controller;
    }

    return error.NotImplemented;
}

/// Operation: error
///
/// Spec: https://streams.spec.whatwg.org/#ws-default-controller-error
/// Arguments:
///   e: Error to error the stream with (optional, defaults to undefined)
///
/// Steps:
/// 1. Let state = this.[[stream]].[[state]]
/// 2. If state is not "writable", return
/// 3. Perform WritableStreamDefaultControllerError(this, e)
pub fn call_error(instance: *runtime.Instance, e: *const anyopaque) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Get the stream
    const stream = internal.stream orelse return error.InvalidState;
    const stream_state = stream.getState(interfaces.WritableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.InvalidState;

    // 1. Let state = this.[[stream]].[[state]]
    const current_state = stream_internal.state;

    // 2. If state is not "writable", return
    if (current_state != .writable) {
        return;
    }

    // 3. Perform WritableStreamDefaultControllerError(this, e)
    writableStreamDefaultControllerError(instance, e);
}

// ============================================================================
// Abstract Operations
// ============================================================================

/// WritableStreamDefaultControllerError
///
/// Spec: https://streams.spec.whatwg.org/#writable-stream-default-controller-error
/// Arguments:
///   controller: WritableStreamDefaultController instance
///   error_value: Error to error the stream with
///
/// Steps per spec - simplified for now
fn writableStreamDefaultControllerError(controller: *runtime.Instance, error_value: *const anyopaque) void {
    const state = controller.getState(State);
    const internal = state.own._internal orelse return;

    // Get the stream
    const stream = internal.stream orelse return;

    // For now, just mark stream as errored
    // Future: Implement full WritableStreamStartErroring algorithm
    const stream_state = stream.getState(interfaces.WritableStream.State);
    if (stream_state.own._internal) |stream_internal| {
        stream_internal.state = .errored;
        stream_internal.stored_error = @constCast(error_value);
    }
}

/// ResetQueue - Clear the controller's queue
///
/// Spec: https://streams.spec.whatwg.org/#reset-queue
fn resetQueue(controller: *runtime.Instance) void {
    const state = controller.getState(State);
    const internal = state.own._internal orelse return;

    internal.queue.clearRetainingCapacity();
    internal.queue_total_size = 0.0;
}

// ============================================================================
// Internal Methods (called by WritableStream)
// ============================================================================

/// WritableStreamDefaultControllerWrite - Queue a write operation
///
/// Spec: https://streams.spec.whatwg.org/#writable-stream-default-controller-write
/// Arguments:
///   controller: WritableStreamDefaultController instance
///   chunk: The chunk to write
///   chunk_size: Size of the chunk
/// Returns: Promise that resolves when write completes
///
/// Steps:
/// 1. Let writeAlgorithm be this.[[writeAlgorithm]]
/// 2. Let writeRecord be a new write record with chunk and a new promise
/// 3. Enqueue writeRecord to this.[[queue]]
/// 4. Let stream be this.[[stream]]
/// 5. If WritableStreamCloseQueuedOrInFlight(stream) is false and stream.[[state]] is "writable",
///    perform WritableStreamDefaultControllerAdvanceQueueIfNeeded(this)
/// 6. Return writeRecord's promise
pub fn write(controller: *runtime.Instance, chunk: *const anyopaque, chunk_size: f64) !*AsyncPromise(void) {
    const state = controller.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const allocator = internal.allocator;

    // Import modules
    const write_request = @import("streams_write_request");
    const common = @import("streams_common");

    // 1. Get stream to access event loop
    const stream = internal.stream orelse return error.InvalidState;
    const stream_state = stream.getState(interfaces.WritableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.InvalidState;

    // 2. Wrap chunk in JSValue (simplified - treat as opaque object for now)
    const js_chunk = common.JSValue{ .object = {} };

    // 3. Create write request with chunk and promise
    const request = try write_request.WriteRequest.init(
        allocator,
        stream_internal.event_loop,
        js_chunk,
    );
    errdefer request.deinit();

    // 4. Enqueue to controller's queue (using QueueValue wrapper from this module)
    const value = QueueValue{ .chunk = @constCast(chunk) };
    try internal.queue.append(allocator, value);
    internal.queue_total_size += chunk_size;

    // 5. Store WriteRequest in stream's write_requests queue
    try stream_internal.write_requests.append(allocator, request);

    // 6. If stream is writable and no close pending, advance the queue
    const close_pending = stream_internal.close_request != null or stream_internal.in_flight_close_request != null;
    if (stream_internal.state == .writable and !close_pending) {
        writableStreamDefaultControllerAdvanceQueueIfNeeded(controller);
    }

    // 7. Return the write request's promise
    return request.promise;
}

/// WritableStreamDefaultControllerAdvanceQueueIfNeeded - Process write queue
///
/// Spec: https://streams.spec.whatwg.org/#writable-stream-default-controller-advance-queue-if-needed
/// Arguments:
///   controller: WritableStreamDefaultController instance
///
/// Steps:
/// 1. Let controller be this
/// 2. If controller.[[started]] is false, return
/// 3. Let stream be controller.[[stream]]
/// 4. If stream.[[inFlightWriteRequest]] is not undefined, return
/// 5. Let state be stream.[[state]]
/// 6. Assert: state is not "closed" or "errored"
/// 7. If state is "erroring", perform WritableStreamFinishErroring(stream) and return
/// 8. If controller.[[queue]] is empty, return
/// 9. Let value be PeekQueueValue(controller)
/// 10. If value is close sentinel, perform WritableStreamDefaultControllerProcessClose(controller)
/// 11. Otherwise, perform WritableStreamDefaultControllerProcessWrite(controller, value)
fn writableStreamDefaultControllerAdvanceQueueIfNeeded(controller: *runtime.Instance) void {
    const state = controller.getState(State);
    const internal = state.own._internal orelse return;

    // 1-2. If controller not started, return
    if (!internal.started) {
        return;
    }

    // 3. Get stream
    const stream = internal.stream orelse return;
    const stream_state = stream.getState(interfaces.WritableStream.State);
    const stream_internal = stream_state.own._internal orelse return;

    // 4. If there's an in-flight write, return
    if (stream_internal.in_flight_write_request != null) {
        return;
    }

    // 5-6. Check stream state
    const current_state = stream_internal.state;
    if (current_state == .closed or current_state == .errored) {
        return; // Assert violation in spec, but we handle gracefully
    }

    // 7. If erroring, finish erroring
    if (current_state == .erroring) {
        // Future: Call WritableStreamFinishErroring
        return;
    }

    // 8. If queue is empty, return
    if (internal.queue.items.len == 0) {
        return;
    }

    // 9. Peek at next value
    const value = internal.queue.items[0];

    // 10-11. Process close or write
    switch (value) {
        .close_sentinel => {
            // Future: Call WritableStreamDefaultControllerProcessClose
            // For now, just advance queue recursively
            writableStreamDefaultControllerAdvanceQueueIfNeeded(controller);
        },
        .chunk => |chunk| {
            writableStreamDefaultControllerProcessWrite(controller, chunk);
        },
    }
}

/// WritableStreamDefaultControllerProcessWrite - Execute underlying sink write
///
/// Spec: https://streams.spec.whatwg.org/#writable-stream-default-controller-process-write
/// Arguments:
///   controller: WritableStreamDefaultController instance
///   chunk: The chunk to write
///
/// Steps:
/// 1. Let stream be controller.[[stream]]
/// 2. Assert: stream.[[state]] is "writable"
/// 3. Dequeue writeRecord from stream.[[writeRequests]]
/// 4. Set stream.[[inFlightWriteRequest]] to writeRecord
/// 5. Let sink be controller.[[writeAlgorithm]]
/// 6. Upon fulfillment of sink(chunk, controller):
///    - Resolve writeRecord's promise
///    - Set stream.[[inFlightWriteRequest]] to undefined
///    - Update backpressure and advance queue
/// 7. Upon rejection: handle error
fn writableStreamDefaultControllerProcessWrite(controller: *runtime.Instance, chunk: *const anyopaque) void {
    const state = controller.getState(State);
    const internal = state.own._internal orelse return;

    // 1-2. Get stream and verify state
    const stream = internal.stream orelse return;
    const stream_state = stream.getState(interfaces.WritableStream.State);
    const stream_internal = stream_state.own._internal orelse return;

    if (stream_internal.state != .writable) {
        return; // Assert violation
    }

    // 3. Dequeue the write request from stream's write_requests
    if (stream_internal.write_requests.items.len == 0) {
        return; // No write requests
    }
    const write_request = stream_internal.write_requests.orderedRemove(0);

    // Also dequeue from controller's internal queue
    const value = internal.queue.orderedRemove(0);

    // Get size and update total
    // TODO: Use actual chunk size from strategy (currently hardcoded to 1.0)
    const chunk_size = 1.0;
    internal.queue_total_size -= chunk_size;

    // 4. Mark as in-flight
    stream_internal.in_flight_write_request = write_request;

    // 5. Invoke underlying sink write algorithm
    // TODO: Actually call write_algorithm callback when runtime supports it
    // For now, we'll immediately fulfill the write promise
    //
    // The real implementation would be:
    // const result = internal.write_algorithm.?(chunk, controller);
    // result.then(onFulfilled, onRejected)
    //
    // Where onFulfilled = writableStreamDefaultControllerFinishWrite
    // And onRejected = writableStreamDefaultControllerError
    _ = chunk;
    _ = value;

    // 6. Simulate immediate fulfillment (placeholder)
    writableStreamDefaultControllerFinishWrite(controller, stream);
}

/// WritableStreamDefaultControllerFinishWrite - Complete a write operation
///
/// Called when underlying sink write succeeds
/// Arguments:
///   controller: WritableStreamDefaultController instance
///   stream: WritableStream instance
fn writableStreamDefaultControllerFinishWrite(controller: *runtime.Instance, stream: *runtime.Instance) void {
    const stream_state = stream.getState(interfaces.WritableStream.State);
    const stream_internal = stream_state.own._internal orelse return;

    // Fulfill the write request's promise
    if (stream_internal.in_flight_write_request) |request| {
        request.fulfill();
    }

    // Clear in-flight write request
    stream_internal.in_flight_write_request = null;

    // Update backpressure (TODO: Implement in Phase 2)
    // writableStreamDefaultControllerUpdateBackpressure(controller);

    // Advance the queue to process next write
    writableStreamDefaultControllerAdvanceQueueIfNeeded(controller);
}

/// [[AbortSteps]] - Handle abort request
///
/// Spec: https://streams.spec.whatwg.org/#ws-default-controller-internal-abort
/// Arguments:
///   controller: WritableStreamDefaultController instance
///   reason: Abort reason
/// Returns: Promise<undefined> from abort algorithm
///
/// Steps:
/// 1. Let result = perform this.[[abortAlgorithm]], passing reason
/// 2. Perform WritableStreamDefaultControllerClearAlgorithms(this)
/// 3. Return result
pub fn abortSteps(controller: *runtime.Instance, reason: *const anyopaque) !*AsyncPromise(void) {
    const state = controller.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const allocator = internal.allocator;

    // 1. Perform abort algorithm
    // Future: Actually invoke the abort callback
    _ = reason;

    // 2. Clear algorithms
    writableStreamDefaultControllerClearAlgorithms(controller);

    // 3. Return fulfilled promise
    // Future: Return actual promise from abort algorithm
    const promise = try AsyncPromise(void).init(allocator);
    promise.resolve({});
    return promise;
}

/// [[ErrorSteps]] - Handle error state
///
/// Spec: https://streams.spec.whatwg.org/#ws-default-controller-internal-error
/// Steps:
/// 1. Perform ResetQueue(this)
pub fn errorSteps(controller: *runtime.Instance) void {
    resetQueue(controller);
}

/// WritableStreamDefaultControllerClearAlgorithms
///
/// Spec: https://streams.spec.whatwg.org/#writable-stream-default-controller-clear-algorithms
/// Steps:
/// 1. Set this.[[writeAlgorithm]] to undefined
/// 2. Set this.[[closeAlgorithm]] to undefined
/// 3. Set this.[[abortAlgorithm]] to undefined
/// 4. Set this.[[strategySizeAlgorithm]] to undefined
fn writableStreamDefaultControllerClearAlgorithms(controller: *runtime.Instance) void {
    const state = controller.getState(State);
    const internal = state.own._internal orelse return;

    internal.write_algorithm = null;
    internal.close_algorithm = null;
    internal.abort_algorithm = null;
    internal.strategy_size_algorithm = null;
}
