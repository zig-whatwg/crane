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
const event_loop = @import("streams_event_loop");

// BYOB infrastructure
const PullIntoDescriptorModule = @import("streams_pull_into_descriptor");
const PullIntoDescriptor = PullIntoDescriptorModule.PullIntoDescriptor;
const ArrayBuffer = PullIntoDescriptorModule.ArrayBuffer;
const ViewConstructor = PullIntoDescriptorModule.ViewConstructor;
const ReaderType = PullIntoDescriptorModule.ReaderType;

const ReadIntoRequestModule = @import("streams_read_into_request");
const ReadIntoRequest = ReadIntoRequestModule.ReadIntoRequest;

// ArrayBufferView introspection
const ArrayBufferViewModule = runtime.arraybuffer_view;
const ViewType = ArrayBufferViewModule.ViewType;

pub const State = ReadableByteStreamController.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    OutOfMemory,
    InvalidState,
    RangeError,
    NullValue, // Workaround: interface generator doesn't handle nullable return types yet
    BufferDetached, // From ArrayBuffer.transfer()
    NoEventLoop,
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
    pending_pull_intos: infra.List(*PullIntoDescriptor),

    /// [[queue]]: List of byte stream queue entries
    byte_queue: infra.List(ByteStreamQueueEntry),

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

    /// Event loop for async promise scheduling
    loop: ?event_loop.EventLoop,

    /// Controller instance pointer (for callbacks)
    controller_instance: ?*runtime.Instance,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        // Clean up byte queue buffers
        for (self.byte_queue.toSlice()) |entry| {
            entry.buffer.deinit(self.allocator);
            self.allocator.destroy(entry.buffer);
        }
        self.byte_queue.deinit();

        // Clean up pending pull-intos
        for (self.pending_pull_intos.toSlice()) |descriptor| {
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

/// Initialize the internal state for the controller
/// Called from ReadableStream.setUpReadableByteStreamController
pub fn initInternalState(
    internal: *InternalState,
    allocator: std.mem.Allocator,
    stream: *runtime.Instance,
    highWaterMark: f64,
    autoAllocateChunkSize: ?u64,
    pull_algorithm: PullAlgorithm,
    cancel_algorithm: CancelAlgorithm,
) !void {
    initInternalStateWithV8(internal, allocator, stream, highWaterMark, autoAllocateChunkSize, pull_algorithm, cancel_algorithm, null, null);
}

/// Initialize the internal state with V8 context for view construction
/// Called from ReadableStream.setUpReadableByteStreamController when V8 is active
pub fn initInternalStateWithV8(
    internal: *InternalState,
    allocator: std.mem.Allocator,
    stream: *runtime.Instance,
    highWaterMark: f64,
    autoAllocateChunkSize: ?u64,
    pull_algorithm: PullAlgorithm,
    cancel_algorithm: CancelAlgorithm,
    isolate: ?*anyopaque,
    v8_context: ?*anyopaque,
) void {
    // Initialize with empty Lists using infra.List
    const byte_queue = infra.List(ByteStreamQueueEntry).init(allocator);
    const pending_pull_intos = infra.List(*PullIntoDescriptor).init(allocator);

    internal.* = .{
        .allocator = allocator,
        .stream = stream,
        .pull_again = false,
        .pulling = false,
        .byob_request = null,
        .byte_queue = byte_queue,
        .queue_total_size = 0.0,
        .close_requested = false,
        .started = false,
        .strategy_hwm = highWaterMark,
        .pull_algorithm = pull_algorithm,
        .cancel_algorithm = cancel_algorithm,
        .auto_allocate_chunk_size = autoAllocateChunkSize,
        .pending_pull_intos = pending_pull_intos,
        .abort_controller = null,
        .isolate = isolate,
        .v8_context = v8_context,
        .loop = null,
        .controller_instance = null,
    };
}

/// Set the event loop and controller instance for async operations
/// Called after controller is fully initialized
pub fn setEventLoop(instance: *runtime.Instance, loop: event_loop.EventLoop) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.loop = loop;
        internal.controller_instance = instance;
    }
}

/// Set the V8 context for an existing controller
/// Used when V8 context becomes available after initial setup
pub fn setV8Context(instance: *runtime.Instance, isolate: ?*anyopaque, v8_context: ?*anyopaque) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.isolate = isolate;
        internal.v8_context = v8_context;
    }
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
pub fn get_byobRequest(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    // Note: Returns NullValue error when byobRequest is null because interface generator
    // doesn't handle nullable return types yet. Caller should catch and convert to null.
    return internal.byob_request orelse error.NullValue;
}

/// Getter for desiredSize
///
/// Spec: https://streams.spec.whatwg.org/#rbs-controller-desired-size
/// NOTE: Interface generator bug - should return ?f64 per IDL
pub fn get_desiredSize(instance: *runtime.Instance) anyerror!?f64 {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Spec: § 4.7.3 "The desiredSize getter steps are:"
    // Step 1: Return ! ReadableByteStreamControllerGetDesiredSize(this)
    // Note: Returns NullValue error when desiredSize is null because interface generator
    // doesn't handle nullable return types yet. Caller should catch and convert to null.
    return getDesiredSizeInternal(internal) orelse error.NullValue;
}

/// Operation: close
///
/// Spec: § 4.7.3 "The close() method steps are:"
pub fn call_close(instance: *runtime.Instance) anyerror!void {
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
pub fn call_enqueue(instance: *runtime.Instance, chunk: typedefs.ArrayBufferView) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: If chunk ByteLength is 0, throw TypeError
    const chunk_byte_length = getViewByteLength(chunk);
    if (chunk_byte_length == 0) {
        return error.TypeError;
    }

    // Step 2: If buffer ByteLength is 0, throw TypeError
    // (Buffer byte length is checked via view detachment)

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
    try enqueueInternal(instance, chunk);
}

/// Operation: error
///
/// Spec: § 4.7.3 "The error(e) method steps are:"
pub fn call_error(instance: *runtime.Instance, e: webidl.Opt(*const anyopaque)) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Convert e to JSValue
    // Note: e is *anyopaque which could be a V8 Value or other error object.
    // For now, we create a simple error message. Full V8 integration would
    // use v8 conversions to extract the actual error value.
    _ = e;
    const error_value = JSValue.createError("Byte stream error");

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
    if (internal.pending_pull_intos.len > 0) {
        // Step 3.1: Let firstPendingPullInto be controller.[[pendingPullIntos]][0]
        const first_pending = internal.pending_pull_intos.get(0) orelse unreachable;

        // Step 3.2: If remainder of firstPendingPullInto's bytes filled > 0
        const remainder = first_pending.bytes_filled % first_pending.element_size;
        if (remainder > 0) {
            // Step 3.2.1: Let e be a new TypeError
            // Step 3.2.2: Perform ! ReadableByteStreamControllerError(controller, e)
            const type_error = JSValue.createTypeError("Pending pull-into bytes are not element-aligned");
            errorInternal(internal, type_error);
            return;
        }

        // Step 3.3: Set controller.[[closeRequested]] to true
        internal.close_requested = true;
        return;
    }

    // Step 4: Perform ! ReadableByteStreamControllerClearAlgorithms(controller)
    clearAlgorithms(internal);

    // Step 5: Perform ! ReadableStreamClose(controller.[[stream]])
    const ReadableStreamImpl = @import("ReadableStream.zig");
    ReadableStreamImpl.readableStreamClose(stream_internal);
}

/// ReadableByteStreamControllerError(controller, e)
///
/// Spec: § 4.7.4 "Error the controller"
pub fn errorInternal(internal: *InternalState, e: JSValue) void {
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
    ReadableStreamImpl.readableStreamError(stream_internal, @ptrCast(&e));
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
    for (internal.pending_pull_intos.toSlice()) |descriptor| {
        descriptor.buffer.deinit(internal.allocator);
        internal.allocator.destroy(descriptor.buffer);
        internal.allocator.destroy(descriptor);
    }
    internal.pending_pull_intos.clear();
}

/// ResetQueue(container)
///
/// Spec: § 4.7.4 "Reset the queue"
fn resetQueue(internal: *InternalState) void {
    // Clean up byte queue
    for (internal.byte_queue.toSlice()) |entry| {
        entry.buffer.deinit(internal.allocator);
        internal.allocator.destroy(entry.buffer);
    }
    internal.byte_queue.clear();
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

    // Handle promise settlement (sync or async)
    // For synchronous promises (testing), handle immediately
    // For async promises, use event loop callbacks
    handlePullPromise(internal, instance, pull_promise);
}

/// Handle pull promise settlement
/// Supports both synchronous (for testing) and asynchronous (with event loop) promises
fn handlePullPromise(internal: *InternalState, instance: *runtime.Instance, pull_promise: Promise(void)) void {
    // Step 7: Upon fulfillment of pullPromise
    if (pull_promise.isFulfilled()) {
        onPullFulfilled(internal, instance);
        return;
    }

    // Step 8: Upon rejection of pullPromise with reason r
    if (pull_promise.isRejected()) {
        onPullRejected(internal, pull_promise.error_value);
        return;
    }

    // Promise is still pending - need async handling
    // For now, schedule a check on the event loop if available
    if (internal.loop) |loop| {
        // Create context for the callback
        const ctx = internal.allocator.create(PullPromiseContext) catch return;
        ctx.* = .{
            .internal = internal,
            .instance = instance,
            .promise = pull_promise,
        };

        // Schedule microtask to check promise state
        loop.queueMicrotask(.{
            .callback = pullPromiseCheckCallback,
            .context = ctx,
        });
    }
    // If no event loop, the synchronous check above handles it
}

/// Context for async pull promise handling
const PullPromiseContext = struct {
    internal: *InternalState,
    instance: *runtime.Instance,
    promise: Promise(void),
};

/// Callback to check pull promise state (for async handling)
fn pullPromiseCheckCallback(ctx_ptr: ?*anyopaque) void {
    const ctx: *PullPromiseContext = @ptrCast(@alignCast(ctx_ptr orelse return));
    defer ctx.internal.allocator.destroy(ctx);

    if (ctx.promise.isFulfilled()) {
        onPullFulfilled(ctx.internal, ctx.instance);
    } else if (ctx.promise.isRejected()) {
        onPullRejected(ctx.internal, ctx.promise.error_value);
    }
    // If still pending, the promise will settle eventually
    // Real async would re-queue, but our sync Promise(void) settles immediately
}

/// Handle pull promise fulfillment
/// Spec: § 4.7.4 Step 7
fn onPullFulfilled(internal: *InternalState, instance: *runtime.Instance) void {
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

/// Handle pull promise rejection
/// Spec: § 4.7.4 Step 8
fn onPullRejected(internal: *InternalState, error_value: ?webidl.errors.Exception) void {
    // Step 8.1: Perform ! ReadableByteStreamControllerError(controller, r)
    const error_msg = if (error_value) |err| blk: {
        break :blk switch (err) {
            .simple => |s| s.message,
            else => "Pull algorithm failed",
        };
    } else "Pull algorithm failed";

    const js_error = JSValue{ .string = error_msg };
    errorInternal(internal, js_error);
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
    const ReadableStreamImpl = @import("ReadableStream.zig");
    if (ReadableStreamImpl.hasDefaultReader(stream) and ReadableStreamImpl.getNumReadRequests(stream) > 0) {
        return true;
    }

    // Step 6: If ! ReadableStreamHasBYOBReader(stream) is true and ! ReadableStreamGetNumReadIntoRequests(stream) > 0, return true
    if (ReadableStreamImpl.hasBYOBReader(stream) and ReadableStreamImpl.getNumReadIntoRequests(stream) > 0) {
        return true;
    }

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
        fn call(_: *anyopaque, _: ?JSValue) Promise(void) {
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

// ============================================================================
// BYOB Request Fulfillment
// ============================================================================

/// [[ReleaseSteps]]() for ReadableByteStreamController
///
/// Spec: § 4.7.4 "Release steps"
///
/// Called when a reader releases its lock on the stream.
/// Clears pending pull-into descriptors that reference the released reader.
pub fn releaseSteps(instance: ?*runtime.Instance) void {
    if (instance == null) return;

    const state = instance.?.getState(State);
    const internal = state.own._internal orelse return;

    // Step 1: If this.[[pendingPullIntos]] is not empty
    if (internal.pending_pull_intos.len > 0) {
        // Step 1.1: Let firstPendingPullInto be this.[[pendingPullIntos]][0]
        const first_descriptor = internal.pending_pull_intos.get(0) orelse return;

        // Step 1.2: Set firstPendingPullInto's reader type to "none"
        first_descriptor.reader_type = .none;

        // Step 1.3: Set this.[[pendingPullIntos]] to a list containing only firstPendingPullInto
        // Clear all but the first item
        while (internal.pending_pull_intos.len > 1) {
            const descriptor = internal.pending_pull_intos.remove(internal.pending_pull_intos.len - 1) catch break;
            // Clean up the removed descriptor's buffer
            descriptor.buffer.deinit(internal.allocator);
            internal.allocator.destroy(descriptor.buffer);
            internal.allocator.destroy(descriptor);
        }
    }
}

/// ReadableByteStreamControllerPullInto(controller, view, min, readIntoRequest)
///
/// Spec: § 4.10.11 "Pull data into a provided buffer"
///
/// This is the main entry point for BYOB (bring-your-own-buffer) reads.
pub fn pullInto(
    instance: *runtime.Instance,
    view: typedefs.ArrayBufferView,
    min: u64,
    readIntoRequest: ReadIntoRequest,
) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Let stream be controller.[[stream]]
    const stream = internal.stream orelse return error.InvalidState;

    // Steps 2-4: Determine element size and constructor from view
    const element_size = getViewElementSize(view);
    const ctor = getViewConstructor(view);

    // Step 5: Calculate minimum fill
    const minimum_fill = min * element_size;

    // Steps 8-9: Extract byteOffset and byteLength
    const byteOffset = getViewByteOffset(view);
    const byteLength = getViewByteLength(view);

    // Step 10: Transfer the ArrayBuffer
    const buffer_ptr = try extractViewBuffer(internal.allocator, view);

    // Step 13: Create pull-into descriptor
    const pullIntoDescriptor = try internal.allocator.create(PullIntoDescriptor);
    pullIntoDescriptor.* = PullIntoDescriptor.init(
        buffer_ptr,
        buffer_ptr.byte_length,
        byteOffset,
        byteLength,
        minimum_fill,
        element_size,
        ctor,
        .byob,
    );

    // Step 17: Append descriptor to pending list
    try internal.pending_pull_intos.append(pullIntoDescriptor);

    // Step 18: Add readIntoRequest to stream's readIntoRequests list
    const ReadableStreamImpl = @import("ReadableStream.zig");
    try ReadableStreamImpl.addReadIntoRequest(stream, @ptrCast(&readIntoRequest));

    // Step 19: Call pull if needed
    callPullIfNeeded(instance);
}

/// ReadableByteStreamControllerRespond(controller, bytesWritten)
///
/// Spec: § 4.10.11 "Respond with bytes written to BYOB buffer"
pub fn respond(instance: *runtime.Instance, bytesWritten: u64) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Assert controller.[[pendingPullIntos]] is not empty
    if (internal.pending_pull_intos.len == 0) {
        return error.InvalidState;
    }

    // Step 2: Let firstDescriptor be controller.[[pendingPullIntos]][0]
    const firstDescriptor = internal.pending_pull_intos.get(0) orelse return error.InvalidState;

    // Step 3: Let state be controller.[[stream]].[[state]]
    const stream = internal.stream orelse return error.InvalidState;
    const stream_state = stream.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.InvalidState;
    const read_state = stream_internal.state;

    // Step 4: If state is "closed"
    if (read_state == .closed) {
        // Step 4.1: If bytesWritten is not 0, throw TypeError
        if (bytesWritten != 0) {
            return error.TypeError;
        }
    } else {
        // Step 5: Otherwise (state is "readable")
        // Step 5.1: Assert state is "readable"
        if (read_state != .readable) {
            return error.InvalidState;
        }

        // Step 5.2: If bytesWritten is 0, throw TypeError
        if (bytesWritten == 0) {
            return error.TypeError;
        }

        // Step 5.3: If firstDescriptor's bytes filled + bytesWritten > firstDescriptor's byte length, throw RangeError
        if (firstDescriptor.bytes_filled + bytesWritten > firstDescriptor.byte_length) {
            return error.RangeError;
        }
    }

    // Step 6: Set firstDescriptor's buffer to ! TransferArrayBuffer(firstDescriptor's buffer)
    const old_buffer = firstDescriptor.buffer;
    const transferred = try old_buffer.transfer();
    const transferred_ptr = try internal.allocator.create(ArrayBuffer);
    transferred_ptr.* = transferred;
    firstDescriptor.buffer = transferred_ptr;
    internal.allocator.destroy(old_buffer);

    // Step 7: Perform ? ReadableByteStreamControllerRespondInternal(controller, bytesWritten)
    try respondInternal(instance, bytesWritten);
}

/// ReadableByteStreamControllerRespondWithNewView(controller, view)
///
/// Spec: § 4.10.11 "Respond with a new view (replacement buffer)"
pub fn respondWithNewView(instance: *runtime.Instance, view: typedefs.ArrayBufferView) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Assert: controller.[[pendingPullIntos]] is not empty
    if (internal.pending_pull_intos.isEmpty()) {
        return error.InvalidState;
    }

    // Step 2: Assert: ! IsDetachedBuffer(view.[[ViewedArrayBuffer]]) is false
    if (isViewDetached(view)) {
        return error.TypeError;
    }

    // Step 3: Let firstDescriptor be controller.[[pendingPullIntos]][0]
    const firstDescriptor = internal.pending_pull_intos.get(0) orelse return error.InvalidState;

    // Step 4: Let state be controller.[[stream]].[[state]]
    const stream = internal.stream orelse return error.InvalidState;
    const stream_state = stream.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.InvalidState;
    const read_state = stream_internal.state;

    // Extract view properties
    const view_byteOffset = getViewByteOffset(view);
    const view_byteLength = getViewByteLength(view);

    // Step 5: If state is "closed"
    if (read_state == .closed) {
        // Step 5.1: If view.[[ByteLength]] is not 0, throw TypeError
        if (view_byteLength != 0) {
            return error.TypeError;
        }
    } else {
        // Step 6: Otherwise (state is "readable")
        // Step 6.1: Assert: state is "readable"
        if (read_state != .readable) {
            return error.InvalidState;
        }

        // Step 6.2: If view.[[ByteLength]] is 0, throw TypeError
        if (view_byteLength == 0) {
            return error.TypeError;
        }
    }

    // Step 7: If firstDescriptor's byte offset + firstDescriptor's bytes filled is not view.[[ByteOffset]], throw RangeError
    if (firstDescriptor.byte_offset + firstDescriptor.bytes_filled != view_byteOffset) {
        return error.RangeError;
    }

    // Step 8: If firstDescriptor's buffer byte length is not view.[[ViewedArrayBuffer]].[[ByteLength]], throw RangeError
    const view_buffer_byte_length = view.getViewedArrayBuffer().byteLength();
    if (firstDescriptor.buffer.byte_length != view_buffer_byte_length) {
        return error.RangeError;
    }

    // Step 9: If firstDescriptor's bytes filled + view.[[ByteLength]] > firstDescriptor's byte length, throw RangeError
    if (firstDescriptor.bytes_filled + view_byteLength > firstDescriptor.byte_length) {
        return error.RangeError;
    }

    // Step 11: Set firstDescriptor's buffer to ? TransferArrayBuffer(view.[[ViewedArrayBuffer]])
    const transferred_ptr = try extractViewBuffer(internal.allocator, view);

    // Free old buffer before replacing
    firstDescriptor.buffer.deinit(internal.allocator);
    internal.allocator.destroy(firstDescriptor.buffer);
    firstDescriptor.buffer = transferred_ptr;

    // Step 12: Perform ? ReadableByteStreamControllerRespondInternal(controller, viewByteLength)
    try respondInternal(instance, view_byteLength);
}

/// ReadableByteStreamControllerRespondInternal(controller, bytesWritten)
///
/// Spec: § 4.10.11 "Internal respond implementation"
fn respondInternal(instance: *runtime.Instance, bytesWritten: u64) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Let firstDescriptor be controller.[[pendingPullIntos]][0]
    const firstDescriptor = internal.pending_pull_intos.get(0) orelse return error.InvalidState;

    // Step 2: Assert: ! CanTransferArrayBuffer(firstDescriptor's buffer) is true
    // (Already transferred in respond())

    // Step 3: Perform ! ReadableByteStreamControllerInvalidateBYOBRequest(controller)
    invalidateBYOBRequest(internal);

    // Step 4: Let state be controller.[[stream]].[[state]]
    const stream = internal.stream orelse return error.InvalidState;
    const stream_state = stream.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.InvalidState;
    const read_state = stream_internal.state;

    // Step 5: If state is "closed"
    if (read_state == .closed) {
        // Step 5.1: Assert: bytesWritten is 0
        // Step 5.2: Perform ! ReadableByteStreamControllerRespondInClosedState(controller, firstDescriptor)
        try respondInClosedState(internal, firstDescriptor);
    } else {
        // Step 6: Otherwise (state is "readable")
        // Step 6.1: Assert: state is "readable"
        // Step 6.2: Assert: bytesWritten > 0
        // Step 6.3: Perform ? ReadableByteStreamControllerRespondInReadableState(controller, bytesWritten, firstDescriptor)
        try respondInReadableState(internal, bytesWritten, firstDescriptor);
    }

    // Step 7: Perform ! ReadableByteStreamControllerCallPullIfNeeded(controller)
    callPullIfNeeded(instance);
}

/// ReadableByteStreamControllerInvalidateBYOBRequest(controller)
///
/// Spec: § 4.10.11 "Invalidate BYOB request"
fn invalidateBYOBRequest(internal: *InternalState) void {
    if (internal.byob_request) |byob| {
        // Invalidate the BYOB request (clears controller and view)
        const BYOBRequestImpl = @import("ReadableStreamBYOBRequest.zig");
        BYOBRequestImpl.invalidate(byob);
    }
    internal.byob_request = null;
}

/// ReadableByteStreamControllerRespondInClosedState(controller, firstDescriptor)
///
/// Spec: § 4.10.11 "Respond when stream is in closed state"
fn respondInClosedState(
    internal: *InternalState,
    firstDescriptor: *PullIntoDescriptor,
) ImplError!void {
    // Step 1: Assert: the remainder after dividing firstDescriptor's bytes filled by firstDescriptor's element size is 0
    // (Assertion - caller ensures this)

    // Step 2: If firstDescriptor's reader type is "none", perform ! ReadableByteStreamControllerShiftPendingPullInto(controller)
    if (firstDescriptor.reader_type == .none) {
        _ = shiftPendingPullInto(internal);
    }

    // Step 3: Let stream be controller.[[stream]]
    const stream = internal.stream orelse return;

    // Step 4: If ! ReadableStreamHasBYOBReader(stream) is true
    const ReadableStreamImpl = @import("ReadableStream.zig");
    if (ReadableStreamImpl.hasBYOBReader(stream)) {
        // Step 4.1: While there are pending read-into requests
        while (ReadableStreamImpl.getNumReadIntoRequests(stream) > 0) {
            // Step 4.1.1: Process pull-into descriptors from queue
            var filled_pull_intos = try processPullIntoDescriptorsUsingQueue(internal);
            defer filled_pull_intos.deinit();

            // If no more descriptors could be processed, break
            if (filled_pull_intos.len == 0) {
                break;
            }

            // Step 4.1.2: For each filledPullInto, commit it
            for (0..filled_pull_intos.len) |i| {
                if (filled_pull_intos.get(i)) |filled_descriptor| {
                    // Commit with done=true since we're in closed state
                    try commitPullIntoDescriptor(internal, filled_descriptor);
                }
            }
        }
    }
}

/// ReadableByteStreamControllerRespondInReadableState(controller, bytesWritten, pullIntoDescriptor)
///
/// Spec: § 4.10.11 "Respond when stream is in readable state"
fn respondInReadableState(
    internal: *InternalState,
    bytesWritten: u64,
    pullIntoDescriptor: *PullIntoDescriptor,
) ImplError!void {
    // Step 2: Fill the descriptor
    fillHeadPullIntoDescriptor(pullIntoDescriptor, bytesWritten);

    // Step 3: Handle reader type "none"
    if (pullIntoDescriptor.reader_type == .none) {
        try enqueueDetachedPullIntoToQueue(internal, pullIntoDescriptor);
        // Process any additional pull-into descriptors using the queue
        var filled_pull_intos = try processPullIntoDescriptorsUsingQueue(internal);
        defer filled_pull_intos.deinit();

        // Commit each filled descriptor
        for (0..filled_pull_intos.len) |i| {
            if (filled_pull_intos.get(i)) |filled_descriptor| {
                try commitPullIntoDescriptor(internal, filled_descriptor);
            }
        }
        return;
    }

    // Step 4: Check if minimum fill is met
    if (pullIntoDescriptor.bytes_filled < pullIntoDescriptor.minimum_fill) {
        return;
    }

    // Step 5: Remove descriptor from pending list
    _ = shiftPendingPullInto(internal);

    // Step 6-8: Handle remainder bytes (enqueue any leftover bytes back to queue)
    const remainder_size = pullIntoDescriptor.bytes_filled % pullIntoDescriptor.element_size;
    if (remainder_size > 0) {
        // Step 6.1-6.2: Clone remainder bytes to queue
        const end = pullIntoDescriptor.byte_offset + pullIntoDescriptor.bytes_filled;
        const start = end - remainder_size;

        // Create a cloned buffer for the remainder (heap-allocated)
        const remainder_buffer_ptr = try internal.allocator.create(ArrayBuffer);
        errdefer internal.allocator.destroy(remainder_buffer_ptr);
        remainder_buffer_ptr.* = try ArrayBuffer.init(internal.allocator, remainder_size);
        errdefer remainder_buffer_ptr.deinit(internal.allocator);

        // Copy remainder bytes
        @memcpy(remainder_buffer_ptr.data[0..remainder_size], pullIntoDescriptor.buffer.data[start..end]);

        // Enqueue the remainder
        try enqueueChunkToQueue(internal, remainder_buffer_ptr, 0, remainder_size);

        // Step 8: Adjust bytes filled
        pullIntoDescriptor.bytes_filled -= remainder_size;
    }

    // Step 9: Process any additional pull-into descriptors using the queue
    var filled_pull_intos = try processPullIntoDescriptorsUsingQueue(internal);
    defer filled_pull_intos.deinit();

    // Step 10: Commit the original pull-into descriptor
    try commitPullIntoDescriptor(internal, pullIntoDescriptor);

    // Step 11: For each filledPullInto, commit it
    for (0..filled_pull_intos.len) |i| {
        if (filled_pull_intos.get(i)) |filled_descriptor| {
            try commitPullIntoDescriptor(internal, filled_descriptor);
        }
    }
}

/// ReadableByteStreamControllerShiftPendingPullInto(controller)
///
/// Spec: § 4.10.11 "Remove and return first pending pull-into descriptor"
fn shiftPendingPullInto(internal: *InternalState) *PullIntoDescriptor {
    return internal.pending_pull_intos.remove(0) catch unreachable;
}

/// Fill the head pull-into descriptor with bytes written
///
/// Spec: § 4.10.11 "FillHeadPullIntoDescriptor"
fn fillHeadPullIntoDescriptor(descriptor: *PullIntoDescriptor, bytesWritten: u64) void {
    descriptor.bytes_filled += bytesWritten;
}

/// ReadableByteStreamControllerEnqueueDetachedPullIntoToQueue(controller, pullIntoDescriptor)
///
/// Spec: § 4.10.11 "Enqueue detached pull-into to byte queue"
fn enqueueDetachedPullIntoToQueue(
    internal: *InternalState,
    pullIntoDescriptor: *PullIntoDescriptor,
) ImplError!void {
    // Step 1: Assert: pullIntoDescriptor's reader type is "none"
    // (Caller ensures this)

    // Step 2: If pullIntoDescriptor's bytes filled > 0, perform ! ReadableByteStreamControllerEnqueueChunkToQueue
    if (pullIntoDescriptor.bytes_filled > 0) {
        try enqueueChunkToQueue(
            internal,
            pullIntoDescriptor.buffer,
            pullIntoDescriptor.byte_offset,
            pullIntoDescriptor.bytes_filled,
        );
    }

    // Step 3: Perform ! ReadableByteStreamControllerShiftPendingPullInto(controller)
    _ = shiftPendingPullInto(internal);
}

/// ReadableByteStreamControllerEnqueueChunkToQueue(controller, buffer, byteOffset, byteLength)
///
/// Spec: § 4.10.11 "Enqueue chunk to byte queue"
fn enqueueChunkToQueue(
    internal: *InternalState,
    buffer: *ArrayBuffer,
    byteOffset: u64,
    byteLength: u64,
) ImplError!void {
    // Create queue entry
    const entry = ByteStreamQueueEntry{
        .buffer = buffer,
        .byteOffset = byteOffset,
        .byteLength = byteLength,
    };

    // Add to queue
    try internal.byte_queue.append(entry);

    // Update total size
    internal.queue_total_size += @as(f64, @floatFromInt(byteLength));
}

/// ReadableByteStreamControllerCommitPullIntoDescriptor(stream, pullIntoDescriptor)
///
/// Spec: § 4.10.11 "Commit pull-into descriptor"
fn commitPullIntoDescriptor(
    internal: *InternalState,
    pullIntoDescriptor: *PullIntoDescriptor,
) ImplError!void {
    // Step 1: Assert: stream.[[state]] is not "errored"
    const stream = internal.stream orelse return error.InvalidState;
    const stream_state = stream.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.InvalidState;

    if (stream_internal.state == .errored) {
        return error.InvalidState;
    }

    // Step 2: Assert: pullIntoDescriptor's reader type is not "none"
    if (pullIntoDescriptor.reader_type == .none) {
        return error.InvalidState;
    }

    // Step 3: Let done be false
    var done = false;

    // Step 4: If stream.[[state]] is "closed"
    if (stream_internal.state == .closed) {
        // Step 4.1: Assert: pullIntoDescriptor's bytes filled is 0
        // Step 4.2: Set done to true
        done = true;
    }

    // Step 5: Let filledView be ! ReadableByteStreamControllerConvertPullIntoDescriptor(pullIntoDescriptor)
    const filled_view: *anyopaque = blk: {
        // If we have V8 context, create a proper V8 TypedArray
        if (internal.isolate != null and internal.v8_context != null) {
            const v8_engine = @import("v8");
            const v8_ffi = v8_engine.ffi;
            const isolate: *v8_ffi.Isolate = @ptrCast(@alignCast(internal.isolate.?));

            // Create V8 ArrayBuffer from descriptor's buffer
            const buffer_size = pullIntoDescriptor.buffer.byte_length;
            const v8_buffer = v8_ffi.v8_ArrayBuffer_New(isolate, buffer_size) orelse {
                break :blk @as(*anyopaque, @ptrCast(pullIntoDescriptor.buffer));
            };

            // Copy data to V8 buffer
            const v8_data = v8_ffi.v8_ArrayBuffer_Data(v8_buffer);
            if (v8_data) |data_ptr| {
                const dest: [*]u8 = @ptrCast(data_ptr);
                @memcpy(dest[0..buffer_size], pullIntoDescriptor.buffer.data[0..buffer_size]);
            }

            // Create typed array view based on constructor type
            const byte_offset = pullIntoDescriptor.byte_offset;
            const element_count = pullIntoDescriptor.bytes_filled / pullIntoDescriptor.element_size;

            const view = switch (pullIntoDescriptor.view_constructor) {
                .uint8_array => v8_ffi.v8_Uint8Array_New(isolate, v8_buffer, byte_offset, element_count),
                .uint8_clamped_array => v8_ffi.v8_Uint8ClampedArray_New(isolate, v8_buffer, byte_offset, element_count),
                .int8_array => v8_ffi.v8_Int8Array_New(isolate, v8_buffer, byte_offset, element_count),
                .uint16_array => v8_ffi.v8_Uint16Array_New(isolate, v8_buffer, byte_offset, element_count),
                .int16_array => v8_ffi.v8_Int16Array_New(isolate, v8_buffer, byte_offset, element_count),
                .uint32_array => v8_ffi.v8_Uint32Array_New(isolate, v8_buffer, byte_offset, element_count),
                .int32_array => v8_ffi.v8_Int32Array_New(isolate, v8_buffer, byte_offset, element_count),
                .float32_array => v8_ffi.v8_Float32Array_New(isolate, v8_buffer, byte_offset, element_count),
                .float64_array => v8_ffi.v8_Float64Array_New(isolate, v8_buffer, byte_offset, element_count),
                .bigint64_array => v8_ffi.v8_BigInt64Array_New(isolate, v8_buffer, byte_offset, element_count),
                .biguint64_array => v8_ffi.v8_BigUint64Array_New(isolate, v8_buffer, byte_offset, element_count),
                .data_view => v8_ffi.v8_DataView_New(isolate, v8_buffer, byte_offset, pullIntoDescriptor.bytes_filled),
            } orelse {
                v8_ffi.v8_ArrayBuffer_Dispose(v8_buffer);
                break :blk @as(*anyopaque, @ptrCast(pullIntoDescriptor.buffer));
            };

            // Clean up our internal buffer since data was copied
            pullIntoDescriptor.buffer.deinit(internal.allocator);
            internal.allocator.destroy(pullIntoDescriptor.buffer);

            break :blk @as(*anyopaque, @ptrCast(view));
        } else {
            // No V8 context - use raw buffer pointer (for testing)
            break :blk @as(*anyopaque, @ptrCast(pullIntoDescriptor.buffer));
        }
    };

    // Step 6: If pullIntoDescriptor's reader type is "default"
    if (pullIntoDescriptor.reader_type == .default) {
        // Step 6.1: Perform ! ReadableStreamFulfillReadRequest(stream, filledView, done)
        const ReadableStreamImpl = @import("ReadableStream.zig");
        try ReadableStreamImpl.fulfillReadRequest(stream, filled_view, done);
    } else {
        // Step 7: Otherwise (reader type is "byob")
        // Step 7.1: Perform ! ReadableStreamFulfillReadIntoRequest(stream, filledView, done)
        const ReadableStreamImpl = @import("ReadableStream.zig");
        try ReadableStreamImpl.fulfillReadIntoRequest(stream, filled_view, done);
    }

    // Clean up descriptor
    internal.allocator.destroy(pullIntoDescriptor);
}

/// ReadableByteStreamControllerHandleQueueDrain(controller)
///
/// Spec: § 4.10.11 "Handle queue drain"
fn handleQueueDrain(internal: *InternalState) void {
    // Step 1: Assert: stream.[[state]] is "readable"
    // (Caller ensures this)

    // Step 2: If queue is empty and close requested, close the stream
    if (internal.queue_total_size == 0.0 and internal.close_requested) {
        clearAlgorithms(internal);

        const stream = internal.stream orelse return;
        const stream_state = stream.getState(interfaces.ReadableStream.State);
        const stream_internal = stream_state.own._internal orelse return;
        const ReadableStreamImpl = @import("ReadableStream.zig");
        ReadableStreamImpl.readableStreamClose(stream_internal);
    } else {
        // Step 3: Otherwise, call pull if needed
        if (internal.controller_instance) |controller| {
            callPullIfNeeded(controller);
        }
    }
}

/// ReadableByteStreamControllerProcessReadRequestsUsingQueue(controller)
///
/// Spec: § 4.10.11 "Process all pending read requests using queue (for default readers)"
pub fn processReadRequestsUsingQueue(instance: *runtime.Instance) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Get stream
    const stream = internal.stream orelse return error.InvalidState;

    // Step 2: Assert: ReadableStreamHasDefaultReader(stream) is true
    const ReadableStreamImpl = @import("ReadableStream.zig");

    // Step 3: Loop while read requests exist and queue has data
    while (ReadableStreamImpl.getNumReadRequests(stream) > 0) {
        // Step 3.1: If queue is empty, return
        if (internal.queue_total_size == 0) {
            return;
        }

        // Step 3.2: Fill read request from queue
        try fillReadRequestFromQueue(internal, stream);
    }

    // Placeholder until ReadableStream API is complete
}

/// ReadableByteStreamControllerFillReadRequestFromQueue(controller)
///
/// Spec: § 4.10.11 "Fill a read request from the queue (for default readers)"
fn fillReadRequestFromQueue(internal: *InternalState, stream: *runtime.Instance) ImplError!void {
    // Step 1: Assert: queue is not empty
    if (internal.byte_queue.items.len == 0) {
        return error.InvalidState;
    }

    // Step 2: Remove first queue entry
    const entry = internal.byte_queue.orderedRemove(0);

    // Step 4: Update queue size
    internal.queue_total_size -= @as(f64, @floatFromInt(entry.byte_length));

    // Step 5: Handle queue drain
    handleQueueDrain(internal);

    // Step 6: Create Uint8Array view from buffer slice
    const chunk: *anyopaque = blk: {
        // If we have V8 context, create a proper V8 Uint8Array
        if (internal.isolate != null and internal.v8_context != null) {
            const v8_ffi = runtime.engines.v8.ffi;
            const isolate: *v8_ffi.Isolate = @ptrCast(@alignCast(internal.isolate.?));

            // Create a V8 ArrayBuffer from our data
            // Note: This creates a new buffer and copies data - for zero-copy we'd need
            // v8::ArrayBuffer::New with external backing store
            const v8_buffer = v8_ffi.v8_ArrayBuffer_New(isolate, entry.byte_length) orelse {
                // Fallback to raw pointer if V8 allocation fails
                break :blk @as(*anyopaque, @ptrCast(entry.buffer));
            };

            // Copy data to V8 buffer
            const v8_data = v8_ffi.v8_ArrayBuffer_Data(v8_buffer);
            if (v8_data) |data_ptr| {
                const src = entry.buffer.data[entry.byteOffset..][0..entry.byte_length];
                const dest: [*]u8 = @ptrCast(data_ptr);
                @memcpy(dest[0..entry.byte_length], src);
            }

            // Create Uint8Array view over the buffer
            const view = v8_ffi.v8_Uint8Array_New(isolate, v8_buffer, 0, entry.byte_length) orelse {
                v8_ffi.v8_ArrayBuffer_Dispose(v8_buffer);
                break :blk @as(*anyopaque, @ptrCast(entry.buffer));
            };

            // Clean up our internal buffer since data was copied
            entry.buffer.deinit(internal.allocator);
            internal.allocator.destroy(entry.buffer);

            break :blk @as(*anyopaque, @ptrCast(view));
        } else {
            // No V8 context - use raw buffer pointer (for testing)
            break :blk @as(*anyopaque, @ptrCast(entry.buffer));
        }
    };

    // Step 7: Fulfill the read request with chunk, done=false
    const ReadableStreamImpl = @import("ReadableStream.zig");
    try ReadableStreamImpl.fulfillReadRequest(stream, chunk, false);
}

/// ReadableByteStreamControllerFillPullIntoDescriptorFromQueue(controller, pullIntoDescriptor)
///
/// Spec: § 4.10.11 "Fill pull-into descriptor from byte queue"
fn fillPullIntoDescriptorFromQueue(
    internal: *InternalState,
    pullIntoDescriptor: *PullIntoDescriptor,
) ImplError!u64 {
    // Step 1: Let maxBytesToCopy be min(queueTotalSize, pullIntoDescriptor.byteLength - pullIntoDescriptor.bytesFilled)
    const queue_bytes = @as(u64, @intFromFloat(internal.queue_total_size));
    const remaining = pullIntoDescriptor.byte_length - pullIntoDescriptor.bytes_filled;
    const max_bytes_to_copy = @min(queue_bytes, remaining);

    // Step 2: Let maxBytesFilled be pullIntoDescriptor.bytesFilled + maxBytesToCopy
    const max_bytes_filled = pullIntoDescriptor.bytes_filled + max_bytes_to_copy;

    // Step 3: Let totalBytesToCopyRemaining be maxBytesToCopy
    var total_bytes_to_copy_remaining = max_bytes_to_copy;

    // Step 4: Let ready be false
    var ready = false;

    // Step 5: Let remainderBytes = maxBytesFilled % pullIntoDescriptor.elementSize
    const remainder_bytes = max_bytes_filled % pullIntoDescriptor.element_size;

    // Step 6: Let maxAlignedBytes = maxBytesFilled - remainderBytes
    const max_aligned_bytes = max_bytes_filled - remainder_bytes;

    // Step 7: If maxAlignedBytes >= pullIntoDescriptor.minimumFill
    if (max_aligned_bytes >= pullIntoDescriptor.minimum_fill) {
        // Step 7.1: totalBytesToCopyRemaining = maxAlignedBytes - pullIntoDescriptor.bytesFilled
        total_bytes_to_copy_remaining = max_aligned_bytes - pullIntoDescriptor.bytes_filled;
        // Step 7.2: ready = true
        ready = true;
    }

    // Step 8: Let queue be controller.[[queue]]
    // Step 9: While totalBytesToCopyRemaining > 0
    var bytes_copied: u64 = 0;
    while (total_bytes_to_copy_remaining > 0 and internal.byte_queue.len > 0) {
        // Step 9.1: Let headOfQueue be queue[0]
        // Get a mutable slice to access the first element
        const queue_slice = internal.byte_queue.toSliceMut();
        if (queue_slice.len == 0) break;
        const head = &queue_slice[0];

        // Step 9.2: Let bytesToCopy = min(totalBytesToCopyRemaining, headOfQueue.byteLength)
        const bytes_to_copy = @min(total_bytes_to_copy_remaining, head.byteLength);

        // Step 9.3: Let destStart = pullIntoDescriptor.byteOffset + pullIntoDescriptor.bytesFilled
        const dest_start = pullIntoDescriptor.byte_offset + pullIntoDescriptor.bytes_filled;

        // Step 9.4: Perform ! CopyDataBlockBytes(pullIntoDescriptor.buffer, destStart, headOfQueue.buffer, headOfQueue.byteOffset, bytesToCopy)
        const src_slice = head.buffer.data[head.byteOffset..][0..bytes_to_copy];
        const dest_slice = pullIntoDescriptor.buffer.data[dest_start..][0..bytes_to_copy];
        @memcpy(dest_slice, src_slice);

        // Step 9.5: If headOfQueue.byteLength is bytesToCopy
        if (head.byteLength == bytes_to_copy) {
            // Step 9.5.1: Remove queue[0]
            const removed = internal.byte_queue.remove(0) catch break;
            removed.buffer.deinit(internal.allocator);
            internal.allocator.destroy(removed.buffer);
        } else {
            // Step 9.6: Otherwise
            // Step 9.6.1: headOfQueue.byteOffset += bytesToCopy
            head.byteOffset += bytes_to_copy;
            // Step 9.6.2: headOfQueue.byteLength -= bytesToCopy
            head.byteLength -= bytes_to_copy;
        }

        // Step 9.7: controller.[[queueTotalSize]] -= bytesToCopy
        internal.queue_total_size -= @as(f64, @floatFromInt(bytes_to_copy));

        // Step 9.8: Perform ! ReadableByteStreamControllerFillHeadPullIntoDescriptor(controller, bytesToCopy, pullIntoDescriptor)
        fillHeadPullIntoDescriptor(pullIntoDescriptor, bytes_to_copy);

        // Step 9.9: totalBytesToCopyRemaining -= bytesToCopy
        total_bytes_to_copy_remaining -= bytes_to_copy;
        bytes_copied += bytes_to_copy;
    }

    // Step 10: If !ready
    if (!ready) {
        // Step 10.1: Assert: controller.[[queueTotalSize]] is 0
        // Step 10.2: Assert: pullIntoDescriptor.bytesFilled > 0
        // Step 10.3: Assert: pullIntoDescriptor.bytesFilled < pullIntoDescriptor.minimumFill
    }

    // Step 11: Return ready
    return if (ready) bytes_copied else 0;
}

/// Internal enqueue implementation (called from call_enqueue)
///
/// Spec: § 4.7.3 "ReadableByteStreamControllerEnqueue"
fn enqueueInternal(instance: *runtime.Instance, chunk: typedefs.ArrayBufferView) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Get stream
    const stream = internal.stream orelse return error.InvalidState;
    const stream_state = stream.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.InvalidState;

    // Step 2: If closeRequested or not readable, return
    if (internal.close_requested or stream_internal.state != .readable) {
        return;
    }

    // Step 3-5: Extract buffer details
    const byteOffset = getViewByteOffset(chunk);
    const byteLength = getViewByteLength(chunk);

    // Step 6: Check if buffer is detached
    if (isViewDetached(chunk)) {
        return error.TypeError;
    }

    // Step 7: Transfer the buffer
    const buffer_ptr = try extractViewBuffer(internal.allocator, chunk);

    // Step 8: If pendingPullIntos not empty, handle specially
    if (internal.pending_pull_intos.len > 0) {
        const first_pending = internal.pending_pull_intos.get(0) orelse unreachable;

        // Check if buffer is detached
        if (first_pending.buffer.detached) {
            return error.TypeError;
        }

        invalidateBYOBRequest(internal);

        // Transfer first pending buffer
        const old_buffer = first_pending.buffer;
        const transferred = try old_buffer.transfer();
        const transferred_ptr = try internal.allocator.create(ArrayBuffer);
        transferred_ptr.* = transferred;
        first_pending.buffer = transferred_ptr;
        internal.allocator.destroy(old_buffer);

        if (first_pending.reader_type == .none) {
            try enqueueDetachedPullIntoToQueue(internal, first_pending);
        }
    }

    // Step 9: If ! ReadableStreamHasDefaultReader(stream) is true
    const ReadableStreamImpl = @import("ReadableStream.zig");
    if (ReadableStreamImpl.hasDefaultReader(stream)) {
        // Step 9.1: If ! ReadableStreamGetNumReadRequests(stream) is 0
        if (ReadableStreamImpl.getNumReadRequests(stream) == 0) {
            // Step 9.1.1: Enqueue chunk to queue
            try enqueueChunkToQueue(internal, buffer_ptr, byteOffset, byteLength);
        } else {
            // Step 9.2: Otherwise, read requests exist
            // Step 9.2.1: Assert: controller.[[queue]] is empty
            // (Queue should be empty if there are pending read requests)

            // Step 9.2.2: Transfer buffer and fulfill first read request
            // Create view from buffer
            const chunk_for_read: *anyopaque = @ptrCast(buffer_ptr);

            // Step 9.2.3: Fulfill read request
            try ReadableStreamImpl.fulfillReadRequest(stream, chunk_for_read, false);
        }
    } else {
        // Step 10: Otherwise (no default reader), enqueue to queue
        try enqueueChunkToQueue(internal, buffer_ptr, byteOffset, byteLength);
    }

    // Step 12: Call pull if needed
    callPullIfNeeded(instance);
}

/// ReadableByteStreamControllerProcessPullIntoDescriptorsUsingQueue(controller)
///
/// Spec: § 4.10.11 "Process pull-into descriptors using queue"
///
/// This processes pending pull-into descriptors by filling them from the byte queue.
/// Returns descriptors that have been completely filled (ready for committing).
fn processPullIntoDescriptorsUsingQueue(
    internal: *InternalState,
) ImplError!infra.List(*PullIntoDescriptor) {
    // Step 1: Assert: controller.[[closeRequested]] is false
    // (Caller ensures this for readable state)

    // Step 2: Let filledPullIntos be a new empty list
    var filled_pull_intos = infra.List(*PullIntoDescriptor).init(internal.allocator);
    errdefer filled_pull_intos.deinit();

    // Step 3: While controller.[[pendingPullIntos]] is not empty
    while (internal.pending_pull_intos.len > 0) {
        // Step 3.1: If controller.[[queueTotalSize]] is 0, then break
        if (internal.queue_total_size == 0) {
            break;
        }

        // Step 3.2: Let pullIntoDescriptor be controller.[[pendingPullIntos]][0]
        const pull_into_descriptor = internal.pending_pull_intos.get(0) orelse break;

        // Step 3.3: If ReadableByteStreamControllerFillPullIntoDescriptorFromQueue returns true (ready)
        const bytes_copied = try fillPullIntoDescriptorFromQueue(internal, pull_into_descriptor);
        const ready = bytes_copied > 0 and pull_into_descriptor.bytes_filled >= pull_into_descriptor.minimum_fill;

        if (ready) {
            // Step 3.3.1: Perform ReadableByteStreamControllerShiftPendingPullInto(controller)
            _ = shiftPendingPullInto(internal);

            // Step 3.3.2: Append pullIntoDescriptor to filledPullIntos
            try filled_pull_intos.append(pull_into_descriptor);
        } else {
            // Descriptor not ready yet - stop processing
            break;
        }
    }

    // Step 4: Return filledPullIntos
    return filled_pull_intos;
}

/// ReadableByteStreamControllerPullSteps(controller, readRequest)
///
/// Spec: § 4.7.4 "Pull steps for default reader"
///
/// This is called when a default reader's read() is invoked.
pub fn pullSteps(
    instance: *runtime.Instance,
    readRequest: *const anyopaque,
) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Let stream be this.[[stream]]
    const stream = internal.stream orelse return error.InvalidState;

    // Step 2: Assert: ! ReadableStreamHasDefaultReader(stream) is true
    // (Caller ensures this)

    // Step 3: If this.[[queueTotalSize]] > 0
    if (internal.queue_total_size > 0) {
        // Step 3.1: Assert: ! ReadableStreamGetNumReadRequests(stream) is 0
        // (Implicit - if queue has data, no pending requests)

        // Step 3.2: Perform ! ReadableByteStreamControllerFillReadRequestFromQueue(this, readRequest)
        try fillReadRequestFromQueue(internal, stream);
        return;
    }

    // Step 4: Let autoAllocateChunkSize be this.[[autoAllocateChunkSize]]
    const auto_allocate_chunk_size = internal.auto_allocate_chunk_size;

    // Step 5: If autoAllocateChunkSize is not undefined
    if (auto_allocate_chunk_size) |chunk_size| {
        // Step 5.1: Let buffer be Construct(%ArrayBuffer%, « autoAllocateChunkSize »)
        const buffer = try ArrayBuffer.init(internal.allocator, chunk_size);
        const buffer_ptr = try internal.allocator.create(ArrayBuffer);
        buffer_ptr.* = buffer;

        // Step 5.3: Let pullIntoDescriptor be a new pull-into descriptor
        const pull_into_descriptor = try internal.allocator.create(PullIntoDescriptor);
        pull_into_descriptor.* = PullIntoDescriptor.init(
            buffer_ptr,
            chunk_size,
            0, // byte offset
            chunk_size, // byte length
            1, // minimum fill (at least 1 byte)
            1, // element size (Uint8Array)
            ViewConstructor.uint8_array,
            .default, // reader type = "default"
        );

        // Step 5.4: Append pullIntoDescriptor to this.[[pendingPullIntos]]
        try internal.pending_pull_intos.append(pull_into_descriptor);
    }

    // Step 6: Perform ! ReadableStreamAddReadRequest(stream, readRequest)
    const ReadableStreamImpl = @import("ReadableStream.zig");
    try ReadableStreamImpl.addReadRequest(stream, readRequest);

    // Step 7: Perform ! ReadableByteStreamControllerCallPullIfNeeded(this)
    callPullIfNeeded(instance);
}

// ============================================================================
// ArrayBufferView Helper Functions (Placeholders for Runtime Integration)
// ============================================================================
//
// These functions need to be implemented at the runtime level to properly
// introspect TypedArray and DataView objects. The actual implementation will
// depend on the JavaScript engine (V8, SpiderMonkey, etc.).
//
// Required operations:
// - Get element size (1 for Uint8Array, 2 for Uint16Array, etc.)
// - Get byte offset into the underlying ArrayBuffer
// - Get byte length of the view
// - Check if the underlying ArrayBuffer is detached
// - Get the underlying ArrayBuffer reference
// - Determine the TypedArray constructor type
//

/// Get the element size in bytes for a TypedArray view
///
/// Returns 1 for Uint8Array/Int8Array, 2 for Uint16Array/Int16Array, etc.
fn getViewElementSize(view: typedefs.ArrayBufferView) u64 {
    return view.getElementSize();
}

/// Get the byte offset of the view into its underlying ArrayBuffer
fn getViewByteOffset(view: typedefs.ArrayBufferView) u64 {
    return view.getByteOffset();
}

/// Get the byte length of the view
fn getViewByteLength(view: typedefs.ArrayBufferView) u64 {
    return view.getByteLength();
}

/// Check if the view's underlying ArrayBuffer is detached
fn isViewDetached(view: typedefs.ArrayBufferView) bool {
    return view.isDetached();
}

/// Get the ViewConstructor type for a TypedArray view
fn getViewConstructor(view: typedefs.ArrayBufferView) ViewConstructor {
    // Get the view type from the union tag
    return switch (view) {
        .int8_array => ViewConstructor.int8_array,
        .uint8_array => ViewConstructor.uint8_array,
        .uint8_clamped_array => ViewConstructor.uint8_clamped_array,
        .int16_array => ViewConstructor.int16_array,
        .uint16_array => ViewConstructor.uint16_array,
        .int32_array => ViewConstructor.int32_array,
        .uint32_array => ViewConstructor.uint32_array,
        .int64_array => ViewConstructor.bigint64_array, // Map int64 to bigint64
        .uint64_array => ViewConstructor.biguint64_array, // Map uint64 to biguint64
        .float32_array => ViewConstructor.float32_array,
        .float64_array => ViewConstructor.float64_array,
        .bigint64_array => ViewConstructor.bigint64_array,
        .biguint64_array => ViewConstructor.biguint64_array,
        .data_view => ViewConstructor.data_view,
    };
}

/// Extract the underlying ArrayBuffer from a view
///
/// This needs to get the actual buffer memory and create an internal ArrayBuffer
fn extractViewBuffer(
    allocator: std.mem.Allocator,
    view: typedefs.ArrayBufferView,
) !*ArrayBuffer {
    _ = allocator;
    // Get the viewed array buffer directly from the view
    // Cast the buffer types which have compatible layouts
    const buffer = view.getViewedArrayBuffer();
    return @ptrCast(buffer);
}
