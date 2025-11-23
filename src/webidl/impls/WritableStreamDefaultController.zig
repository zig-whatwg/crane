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
