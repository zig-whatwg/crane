//! Implementation for ReadableByteStreamController interface
//!
//! Spec: https://streams.spec.whatwg.org/#rbs-controller-class
//!
//! Controls a readable byte stream for zero-copy operations.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const infra = @import("infra");
const ReadableByteStreamController = interfaces.ReadableByteStreamController;

// Import streams infrastructure
const streams_common = @import("streams_common");
const JSValue = streams_common.JSValue;
const Promise = streams_common.Promise;
const CancelAlgorithm = streams_common.CancelAlgorithm;
const PullAlgorithm = streams_common.PullAlgorithm;
const AsyncPromise = @import("streams_async_promise").AsyncPromise;

// BYOB infrastructure
const PullIntoDescriptorModule = @import("streams_pull_into_descriptor");
const PullIntoDescriptor = PullIntoDescriptorModule.PullIntoDescriptor;
const ArrayBuffer = PullIntoDescriptorModule.ArrayBuffer;
const ViewConstructor = PullIntoDescriptorModule.ViewConstructor;
const ReaderType = PullIntoDescriptorModule.ReaderType;

const ReadIntoRequestModule = @import("streams_read_into_request");
const ReadIntoRequest = ReadIntoRequestModule.ReadIntoRequest;

pub const State = ReadableByteStreamController.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    OutOfMemory,
    InvalidState,
    RangeError,
    NullValue, // TODO: Remove when interface generator handles nullable types correctly
};

/// Byte stream queue entry per WHATWG Streams Standard § 4.7.2
///
/// Represents a queued chunk in a byte stream with its buffer and byte range.
const ByteStreamQueueEntry = struct {
    /// The ArrayBuffer containing the queued bytes
    buffer: *ArrayBuffer,
    /// Byte offset into the buffer where this chunk starts
    byteOffset: u64,
    /// Length in bytes of this chunk
    byteLength: u64,
};

/// Internal state for ReadableByteStreamController
///
/// Spec: https://streams.spec.whatwg.org/#readablebytestreamcontroller
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// [[abortController]]: AbortController for signaling abort
    /// Spec: https://streams.spec.whatwg.org/#readablebytestreamcontroller-abortcontroller
    abort_controller: ?*runtime.Instance,

    /// [[autoAllocateChunkSize]]: Size for auto-allocated buffers
    auto_allocate_chunk_size: ?u64,

    /// [[byobRequest]]: Current BYOB request (or null)
    byob_request: ?*runtime.Instance,

    /// [[cancelAlgorithm]]: Algorithm for cancelation
    cancel_algorithm: CancelAlgorithm,

    /// [[closeRequested]]: boolean - stream closed by source but has queued chunks
    close_requested: bool,

    /// [[pullAgain]]: boolean - pull requested but previous pull still executing
    pull_again: bool,

    /// [[pullAlgorithm]]: Algorithm for pulling data
    pull_algorithm: PullAlgorithm,

    /// [[pulling]]: boolean - pull algorithm currently executing
    pulling: bool,

    /// [[pendingPullIntos]]: List of pending pull-into descriptors
    pending_pull_intos: std.ArrayList(*PullIntoDescriptor),

    /// [[queue]]: List of byte stream queue entries
    byte_queue: std.ArrayList(ByteStreamQueueEntry),

    /// [[queueTotalSize]]: Total size of all byte chunks in queue
    queue_total_size: f64,

    /// [[started]]: boolean - underlying source has finished starting
    started: bool,

    /// [[strategyHWM]]: High water mark for backpressure
    strategy_hwm: f64,

    /// [[stream]]: The ReadableStream instance controlled
    stream: ?*runtime.Instance,

    /// V8 context for callback invocation
    isolate: ?*anyopaque,
    v8_context: ?*anyopaque,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        // Clean up byte queue buffers
        for (self.byte_queue.items) |entry| {
            entry.buffer.deinit(self.allocator);
            self.allocator.destroy(entry.buffer);
        }
        self.byte_queue.deinit();

        // Clean up pending pull-intos
        for (self.pending_pull_intos.items) |descriptor| {
            descriptor.buffer.deinit(self.allocator);
            self.allocator.destroy(descriptor.buffer);
            self.allocator.destroy(descriptor);
        }
        self.pending_pull_intos.deinit();

        // Clean up algorithms
        self.cancel_algorithm.deinit();
        self.pull_algorithm.deinit();

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
    // InternalState is set up by SetUpReadableByteStreamController
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

// ============================================================================
// WebIDL Interface Methods
// ============================================================================

/// Getter for byobRequest
///
/// Spec: https://streams.spec.whatwg.org/#rbs-controller-byob-request
/// NOTE: Interface generator bug - should return ?*runtime.Instance per IDL
pub fn get_byobRequest(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    // TODO: Fix interface generator to handle nullable types correctly
    return internal.byob_request orelse error.NullValue;
}

/// Getter for desiredSize
///
/// Spec: https://streams.spec.whatwg.org/#rbs-controller-desired-size
/// NOTE: Interface generator bug - should return ?f64 per IDL
pub fn get_desiredSize(instance: *runtime.Instance) ImplError!f64 {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Spec: § 4.7.3 "The desiredSize getter steps are:"
    // Step 1: Return ! ReadableByteStreamControllerGetDesiredSize(this)
    // TODO: Fix interface generator to handle nullable types correctly
    return getDesiredSizeInternal(internal) orelse error.NullValue;
}

/// Operation: close
///
/// Spec: § 4.7.3 "The close() method steps are:"
pub fn call_close(instance: *runtime.Instance) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: If closeRequested is true, throw TypeError
    if (internal.close_requested) {
        return error.TypeError;
    }

    // Step 2: If stream state is not "readable", throw TypeError
    const stream = internal.stream orelse return error.InvalidState;
    const stream_state = stream.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.InvalidState;

    if (stream_internal.state != .readable) {
        return error.TypeError;
    }

    // Step 3: Perform ! ReadableByteStreamControllerClose(this)
    closeInternal(internal);
}

/// Operation: enqueue
///
/// Spec: § 4.7.3 "The enqueue(chunk) method steps are:"
pub fn call_enqueue(instance: *runtime.Instance, chunk: typedefs.ArrayBufferView) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: If chunk ByteLength is 0, throw TypeError
    // TODO: Proper ArrayBufferView handling
    _ = chunk;

    // Step 2: If buffer ByteLength is 0, throw TypeError
    // TODO: Get buffer from chunk and check

    // Step 3: If closeRequested is true, throw TypeError
    if (internal.close_requested) {
        return error.TypeError;
    }

    // Step 4: If stream state is not "readable", throw TypeError
    const stream = internal.stream orelse return error.InvalidState;
    const stream_state = stream.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.InvalidState;

    if (stream_internal.state != .readable) {
        return error.TypeError;
    }

    // Step 5: Perform ReadableByteStreamControllerEnqueue
    // TODO: Implement enqueueInternal
    return error.NotImplemented;
}

/// Operation: error
///
/// Spec: § 4.7.3 "The error(e) method steps are:"
pub fn call_error(instance: *runtime.Instance, e: *const anyopaque) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Convert e to JSValue
    // TODO: Proper conversion
    _ = e;
    const error_value = JSValue{ .string = "Byte stream error" };

    errorInternal(internal, error_value);
}

// ============================================================================
// Internal Algorithms
// ============================================================================

/// ReadableByteStreamControllerGetDesiredSize(controller)
///
/// Spec: § 4.7.4 "Compute desired size for backpressure"
fn getDesiredSizeInternal(internal: *InternalState) ?f64 {
    const stream = internal.stream orelse return null;
    const stream_state = stream.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return null;

    // Step 1: Let state be controller.[[stream]].[[state]]
    const state = stream_internal.state;

    // Step 2: If state is "errored", return null
    if (state == .errored) {
        return null;
    }

    // Step 3: If state is "closed", return 0
    if (state == .closed) {
        return 0.0;
    }

    // Step 4: Return controller.[[strategyHWM]] − controller.[[queueTotalSize]]
    return internal.strategy_hwm - internal.queue_total_size;
}

/// ReadableByteStreamControllerClose(controller)
///
/// Spec: § 4.7.4 "Close the controller"
fn closeInternal(internal: *InternalState) void {
    const stream = internal.stream orelse return;

    // Step 1: If controller.[[closeRequested]] is true or controller.[[stream]].[[state]] is not "readable", return
    const stream_state = stream.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return;

    if (internal.close_requested or stream_internal.state != .readable) {
        return;
    }

    // Step 2: If controller.[[queueTotalSize]] > 0
    if (internal.queue_total_size > 0) {
        // Step 2.1: Set controller.[[closeRequested]] to true
        internal.close_requested = true;
        return;
    }

    // Step 3: If controller.[[pendingPullIntos]] is not empty
    if (internal.pending_pull_intos.items.len > 0) {
        // Step 3.1: Let firstPendingPullInto be controller.[[pendingPullIntos]][0]
        const first_pending = internal.pending_pull_intos.items[0];

        // Step 3.2: If remainder of firstPendingPullInto's bytes filled > 0
        // TODO: Calculate remainder
        _ = first_pending;

        // For now, just set close requested
        internal.close_requested = true;
        return;
    }

    // Step 4: Perform ! ReadableByteStreamControllerClearAlgorithms(controller)
    clearAlgorithms(internal);

    // Step 5: Perform ! ReadableStreamClose(controller.[[stream]])
    const ReadableStreamImpl = @import("ReadableStream.zig");
    ReadableStreamImpl.closeInternal(stream);
}

/// ReadableByteStreamControllerError(controller, e)
///
/// Spec: § 4.7.4 "Error the controller"
fn errorInternal(internal: *InternalState, e: JSValue) void {
    const stream = internal.stream orelse return;

    // Step 1: Let stream be controller.[[stream]]
    // Step 2: If stream.[[state]] is not "readable", return
    const stream_state = stream.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return;

    if (stream_internal.state != .readable) {
        return;
    }

    // Step 3: Perform ! ReadableByteStreamControllerClearPendingPullIntos(controller)
    clearPendingPullIntos(internal);

    // Step 4: Perform ! ResetQueue(controller)
    resetQueue(internal);

    // Step 5: Perform ! ReadableByteStreamControllerClearAlgorithms(controller)
    clearAlgorithms(internal);

    // Step 6: Perform ! ReadableStreamError(stream, e)
    const ReadableStreamImpl = @import("ReadableStream.zig");
    ReadableStreamImpl.errorInternal(stream, e);
}

/// ReadableByteStreamControllerClearAlgorithms(controller)
///
/// Spec: § 4.7.4 "Clear algorithms to allow GC"
fn clearAlgorithms(internal: *InternalState) void {
    internal.pull_algorithm.deinit();
    internal.cancel_algorithm.deinit();

    // Replace with no-op algorithms
    internal.pull_algorithm = defaultPullAlgorithm();
    internal.cancel_algorithm = defaultCancelAlgorithm();
}

/// ReadableByteStreamControllerClearPendingPullIntos(controller)
///
/// Spec: § 4.7.4 "Clear pending pull-intos"
fn clearPendingPullIntos(internal: *InternalState) void {
    // Clean up all pending pull-into descriptors
    for (internal.pending_pull_intos.items) |descriptor| {
        descriptor.buffer.deinit(internal.allocator);
        internal.allocator.destroy(descriptor.buffer);
        internal.allocator.destroy(descriptor);
    }
    internal.pending_pull_intos.clearRetainingCapacity();
}

/// ResetQueue(container)
///
/// Spec: § 4.7.4 "Reset the queue"
fn resetQueue(internal: *InternalState) void {
    // Clean up byte queue
    for (internal.byte_queue.items) |entry| {
        entry.buffer.deinit(internal.allocator);
        internal.allocator.destroy(entry.buffer);
    }
    internal.byte_queue.clearRetainingCapacity();
    internal.queue_total_size = 0.0;
}

/// ReadableByteStreamControllerCallPullIfNeeded(controller)
///
/// Spec: § 4.7.4 "Call pull if needed"
pub fn callPullIfNeeded(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;

    // Step 1: Let shouldPull be ! ReadableByteStreamControllerShouldCallPull(controller)
    const should_pull = shouldCallPull(internal);

    // Step 2: If shouldPull is false, return
    if (!should_pull) {
        return;
    }

    // Step 3: If controller.[[pulling]] is true
    if (internal.pulling) {
        // Step 3.1: Set controller.[[pullAgain]] to true
        internal.pull_again = true;
        return;
    }

    // Step 4: Assert: controller.[[pullAgain]] is false
    std.debug.assert(!internal.pull_again);

    // Step 5: Set controller.[[pulling]] to true
    internal.pulling = true;

    // Step 6: Let pullPromise be the result of performing controller.[[pullAlgorithm]]
    const pull_promise = internal.pull_algorithm.call();

    // Step 7: Upon fulfillment of pullPromise
    if (pull_promise.isFulfilled()) {
        // Step 7.1: Set controller.[[pulling]] to false
        internal.pulling = false;

        // Step 7.2: If controller.[[pullAgain]] is true
        if (internal.pull_again) {
            // Step 7.2.1: Set controller.[[pullAgain]] to false
            internal.pull_again = false;
            // Step 7.2.2: Perform ! ReadableByteStreamControllerCallPullIfNeeded(controller)
            callPullIfNeeded(instance);
        }
    }

    // Step 8: Upon rejection of pullPromise with reason r
    if (pull_promise.isRejected()) {
        // Step 8.1: Perform ! ReadableByteStreamControllerError(controller, r)
        const error_value = JSValue{ .string = "Pull failed" };
        errorInternal(internal, error_value);
    }
}

/// ReadableByteStreamControllerShouldCallPull(controller)
///
/// Spec: § 4.7.4 "Determine if pull should be called"
fn shouldCallPull(internal: *InternalState) bool {
    const stream = internal.stream orelse return false;
    const stream_state = stream.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return false;

    // Step 1: Let stream be controller.[[stream]]
    // Step 2: If stream.[[state]] is not "readable", return false
    if (stream_internal.state != .readable) {
        return false;
    }

    // Step 3: If controller.[[closeRequested]] is true, return false
    if (internal.close_requested) {
        return false;
    }

    // Step 4: If controller.[[started]] is false, return false
    if (!internal.started) {
        return false;
    }

    // Step 5: If ! ReadableStreamHasDefaultReader(stream) is true and ! ReadableStreamGetNumReadRequests(stream) > 0, return true
    // TODO: Check for default reader and read requests

    // Step 6: If ! ReadableStreamHasBYOBReader(stream) is true and ! ReadableStreamGetNumReadIntoRequests(stream) > 0, return true
    // TODO: Check for BYOB reader and read-into requests

    // Step 7: Let desiredSize be ! ReadableByteStreamControllerGetDesiredSize(controller)
    const desired_size = getDesiredSizeInternal(internal);

    // Step 8: Assert: desiredSize is not null
    // Step 9: If desiredSize > 0, return true
    if (desired_size) |size| {
        if (size > 0) {
            return true;
        }
    }

    // Step 10: Return false
    return false;
}

// ============================================================================
// Default Algorithms
// ============================================================================

/// Default pull algorithm (no-op)
fn defaultPullAlgorithm() PullAlgorithm {
    const vtable = struct {
        fn call(_: *anyopaque) Promise(void) {
            return Promise(void).fulfilled({});
        }
        fn deinitFn(_: *anyopaque) void {}
    };

    const static = struct {
        var dummy: u8 = 0;
    };

    return PullAlgorithm{
        .ptr = &static.dummy,
        .vtable = &.{
            .call = vtable.call,
            .deinit = vtable.deinitFn,
        },
    };
}

/// Default cancel algorithm (no-op)
fn defaultCancelAlgorithm() CancelAlgorithm {
    const vtable = struct {
        fn call(_: *anyopaque, _: JSValue) Promise(void) {
            return Promise(void).fulfilled({});
        }
        fn deinitFn(_: *anyopaque) void {}
    };

    const static = struct {
        var dummy: u8 = 0;
    };

    return CancelAlgorithm{
        .ptr = &static.dummy,
        .vtable = &.{
            .call = vtable.call,
            .deinit = vtable.deinitFn,
        },
    };
}

// ============================================================================
// Public Helper Methods (for other components)
// ============================================================================

/// Check if controller can close or enqueue
pub fn canCloseOrEnqueue(instance: *runtime.Instance) bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return false;

    if (internal.close_requested) {
        return false;
    }

    const stream = internal.stream orelse return false;
    const stream_state = stream.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return false;

    return stream_internal.state == .readable;
}

/// Check if controller has backpressure
pub fn hasBackpressure(instance: *runtime.Instance) bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return false;

    const desired_size = getDesiredSizeInternal(internal) orelse return false;
    return desired_size <= 0;
}

/// Close the controller (called from other components)
pub fn close(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    closeInternal(internal);
}

/// Error the controller (called from other components)
pub fn raiseError(instance: *runtime.Instance, e: JSValue) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    errorInternal(internal, e);
}
