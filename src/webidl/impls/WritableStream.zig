//! WritableStream Implementation
//!
//! WHATWG Streams Standard: https://streams.spec.whatwg.org/#ws-class
//!
//! A writable stream represents a destination for data into which you can write.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const WritableStream = interfaces.WritableStream;

// Import streams infrastructure
const streams_common = @import("streams_common");
const event_loop = @import("streams_event_loop");
const AsyncPromise = @import("streams_async_promise").AsyncPromise;
const WriteRequest = @import("streams_write_request").WriteRequest;

pub const State = WritableStream.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    RangeError,
    InvalidState,
    OutOfMemory,
};

/// Stream state enumeration per WHATWG spec
pub const StreamState = enum {
    writable,
    closed,
    erroring,
    errored,
};

/// Writer union type - can be default writer or none
pub const Writer = union(enum) {
    none: void,
    default: *runtime.Instance,
};

/// Abort request record per WHATWG spec § 5.3.3 step 10
pub const AbortRequest = struct {
    /// Promise that will be resolved/rejected when abort completes
    promise: *AsyncPromise(void),
    /// Reason for the abort (optional)
    reason: ?*const anyopaque,
    /// Whether the stream was already erroring when abort was called
    was_already_erroring: bool,
};

/// Internal state for WritableStream
///
/// This mirrors the internal slots defined in the WHATWG Streams spec § 4.2
pub const InternalState = struct {
    /// [[controller]]: WritableStreamDefaultController
    controller: ?*runtime.Instance,

    /// [[writer]]: WritableStreamDefaultWriter or undefined
    writer: Writer,

    /// [[state]]: "writable", "closed", "erroring", or "errored"
    state: StreamState,

    /// [[storedError]]: any - stored error if state is "errored"
    stored_error: ?*anyopaque,

    /// [[writeRequests]]: List of pending write requests
    write_requests: std.ArrayList(*WriteRequest),

    /// [[inFlightWriteRequest]]: Currently executing write request
    in_flight_write_request: ?*WriteRequest,

    /// [[closeRequest]]: Promise for pending close request
    close_request: ?*AsyncPromise(void),

    /// [[inFlightCloseRequest]]: Promise for currently executing close
    in_flight_close_request: ?*AsyncPromise(void),

    /// [[pendingAbortRequest]]: Record of pending abort request
    /// Per WHATWG spec § 5.1 this is either undefined or an AbortRequest record
    pending_abort_request: ?*AbortRequest,

    /// [[backpressure]]: boolean indicating if backpressure is applied
    backpressure: bool,

    /// Event loop for async operations
    event_loop: event_loop.EventLoop,

    /// Resource management
    allocator: std.mem.Allocator,
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // InternalState is initialized in constructor
    return instance;
}

/// Deinitialize InternalState
fn deinitInternal(internal: *InternalState, allocator: std.mem.Allocator) void {
    // Clean up write requests
    for (internal.write_requests.items) |request| {
        request.deinit();
    }
    internal.write_requests.deinit(allocator);

    // Clean up in-flight write request
    if (internal.in_flight_write_request) |request| {
        request.deinit();
    }

    // Clean up close requests
    if (internal.close_request) |promise| {
        promise.deinit();
    }
    if (internal.in_flight_close_request) |promise| {
        promise.deinit();
    }

    // Clean up pending abort request
    if (internal.pending_abort_request) |abort_request| {
        abort_request.promise.deinit();
        allocator.destroy(abort_request);
    }

    allocator.destroy(internal);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        deinitInternal(internal, internal.allocator);
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
///
/// Spec: https://streams.spec.whatwg.org/#ws-constructor
/// new WritableStream(underlyingSink, strategy)
///
/// Steps:
/// 1. If underlyingSink is missing, set it to null
/// 2. Let underlyingSinkDict be underlyingSink, converted to IDL type UnderlyingSink
/// 3. If underlyingSinkDict["type"] exists, throw RangeError
/// 4. Perform ! InitializeWritableStream(this)
/// 5. Let sizeAlgorithm be ! ExtractSizeAlgorithm(strategy)
/// 6. Let highWaterMark be ? ExtractHighWaterMark(strategy, 1)
/// 7. Perform ? SetUpWritableStreamDefaultControllerFromUnderlyingSink(...)
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, underlyingSink: webidl.Opt(*const anyopaque), strategy: webidl.Opt(dictionaries.QueuingStrategy)) !*runtime.Instance {
    // Get event loop from context
    const loop = try ctx.getEventLoop();

    // Step 1: If underlyingSink is missing, use default
    const underlying_sink_ptr = if (underlyingSink.was_passed) underlyingSink.value else null;

    // Step 2: Convert to UnderlyingSink dictionary (if provided)
    const default_sink = dictionaries.UnderlyingSink{};
    const underlying_sink_dict: *const dictionaries.UnderlyingSink = if (underlying_sink_ptr) |ptr| @ptrCast(@alignCast(ptr)) else &default_sink;

    // Step 3: If type exists, throw RangeError (reserved for future use)
    if (underlying_sink_dict.type != null) {
        return error.RangeError;
    }

    // Step 4: Perform InitializeWritableStream
    const instance = try init(allocator, State, &WritableStream.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Create internal state
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    // InitializeWritableStream: Set initial state
    internal.* = InternalState{
        .controller = null, // Will be set by SetUp
        .writer = .none,
        .state = .writable,
        .stored_error = null,
        .write_requests = .{
            .items = &.{},
            .capacity = 0,
        },
        .in_flight_write_request = null,
        .close_request = null,
        .in_flight_close_request = null,
        .pending_abort_request = null,
        .backpressure = false,
        .event_loop = loop,
        .allocator = allocator,
    };

    state.own._internal = internal;

    // Step 5: Extract size algorithm
    const strategy_value = if (strategy.was_passed) strategy.value else dictionaries.QueuingStrategy{};
    const size_algorithm = extractSizeAlgorithm(&strategy_value);

    // Step 6: Extract high water mark (default 1 for writable)
    const high_water_mark = try extractHighWaterMark(&strategy_value, 1.0);

    // Step 7: SetUpWritableStreamDefaultControllerFromUnderlyingSink
    try setUpWritableStreamDefaultControllerFromUnderlyingSink(
        instance,
        internal,
        underlying_sink_ptr orelse @as(*const anyopaque, @ptrCast(&default_sink)),
        underlying_sink_dict,
        high_water_mark,
        size_algorithm,
    );

    return instance;
}

/// Getter for locked
///
/// Spec: https://streams.spec.whatwg.org/#ws-locked
/// readonly attribute boolean locked
///
/// Returns true if the stream is locked to a writer.
pub fn get_locked(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // IsWritableStreamLocked: return stream.[[writer]] !== undefined
    return internal.writer != .none;
}

/// Operation: getWriter
///
/// Spec: https://streams.spec.whatwg.org/#ws-get-writer
/// WritableStreamDefaultWriter getWriter()
///
/// Returns: A new WritableStreamDefaultWriter locked to this stream
pub fn call_getWriter(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const allocator = internal.allocator;
    const ctx = instance.ctx;

    // AcquireWritableStreamDefaultWriter
    const writer = try interfaces.WritableStreamDefaultWriter.call_constructor(
        allocator,
        ctx,
        instance,
    );

    return writer;
}

/// Operation: abort
///
/// Spec: https://streams.spec.whatwg.org/#ws-abort
/// Promise<undefined> abort(optional any reason)
///
/// Steps:
/// 1. If ! IsWritableStreamLocked(this) is true, return rejected promise
/// 2. Return ! WritableStreamAbort(this, reason)
pub fn call_abort(instance: *runtime.Instance, reason: webidl.Opt(*const anyopaque)) anyerror!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Check if locked
    if (internal.writer != .none) {
        const promise = try AsyncPromise(void).init(
            internal.allocator,
            internal.event_loop,
        );
        const exception = try webidl.errors.Exception.typeError(internal.allocator, "Cannot abort a locked stream");
        promise.*.reject(exception);
        return @ptrCast(promise);
    }

    // Step 2: Return WritableStreamAbort(this, reason)
    // If reason is not passed, use a default undefined-like value
    const default_reason: u8 = 0;
    const reason_ptr: *const anyopaque = if (reason.was_passed) reason.value else @ptrCast(&default_reason);
    return writableStreamAbort(instance, internal, reason_ptr);
}

/// WritableStreamStartErroring - Begin error process
///
/// Spec: § 5.3.6 "Start erroring a writable stream"
/// Arguments:
///   instance: WritableStream instance
///   reason: Error reason
pub fn writableStreamStartErroring(instance: *runtime.Instance, reason: *const anyopaque) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;

    // 1. Assert: stream.[[storedError]] is undefined
    // 2. Assert: stream.[[state]] is "writable"
    if (internal.state != .writable or internal.stored_error != null) {
        return; // Graceful handling instead of assert
    }

    // 3. Let controller be stream.[[controller]]
    const controller = internal.controller orelse return;

    // 4. Assert: controller is not undefined
    // (Already checked above)

    // 5. Set stream.[[state]] to "erroring"
    internal.state = .erroring;

    // 6. Set stream.[[storedError]] to reason
    internal.stored_error = @constCast(reason);

    // 7. Let writer be stream.[[writer]]
    // 8. If writer is not undefined, perform WritableStreamDefaultWriterEnsureReadyPromiseRejected
    if (internal.writer != .none) {
        const writer = switch (internal.writer) {
            .default => |w| w,
            .none => unreachable,
        };

        const writer_state = writer.getState(interfaces.WritableStreamDefaultWriter.State);
        if (writer_state.own._internal) |writer_internal| {
            if (writer_internal.ready_promise) |ready| {
                // Create exception from reason
                const exception = webidl.errors.Exception.typeError(internal.allocator, "Stream errored") catch return;
                ready.reject(exception);
            }
        }
    }

    // 9. If ! WritableStreamHasOperationMarkedInFlight(stream) is false and
    //    controller.[[started]] is true, perform ! WritableStreamFinishErroring(stream)
    if (!writableStreamHasOperationMarkedInFlight(internal)) {
        const controller_state = controller.getState(interfaces.WritableStreamDefaultController.State);
        const WritableStreamDefaultControllerImpl = @import("WritableStreamDefaultController.zig");
        if (controller_state.own._internal) |controller_internal_ptr| {
            const controller_internal: *WritableStreamDefaultControllerImpl.InternalState = @ptrCast(@alignCast(controller_internal_ptr));
            if (controller_internal.started) {
                writableStreamFinishErroring(instance, internal);
            }
        }
    }
}

/// WritableStreamFinishErroring - Complete error process
///
/// Spec: § 5.3.5 "Finish erroring a writable stream"
/// Arguments:
///   instance: WritableStream instance
///   internal: Internal state
pub fn writableStreamFinishErroring(instance: *runtime.Instance, internal: *InternalState) void {
    // 1. Assert: stream.[[state]] is "erroring"
    if (internal.state != .erroring) {
        return; // Graceful handling
    }

    // 2. Assert: ! WritableStreamHasOperationMarkedInFlight(stream) is false
    if (writableStreamHasOperationMarkedInFlight(internal)) {
        return; // Graceful handling
    }

    // 3. Set stream.[[state]] to "errored"
    internal.state = .errored;

    // 4. Perform ! stream.[[controller]].[[ErrorSteps]]()
    if (internal.controller) |controller| {
        const WritableStreamDefaultControllerImpl = @import("WritableStreamDefaultController.zig");
        WritableStreamDefaultControllerImpl.errorSteps(controller);
    }

    // 5. Let storedError be stream.[[storedError]]
    // Create exception from stored error for rejection
    const stored_exception = webidl.errors.Exception.typeError(internal.allocator, "Stream errored") catch return;

    // 6. Repeat for each writeRequest in stream.[[writeRequests]]
    for (internal.write_requests.items) |write_request| {
        // 6.1. Reject writeRequest's promise with storedError
        write_request.reject(stored_exception);
    }

    // 6.2. Set stream.[[writeRequests]] to empty list
    internal.write_requests.clearRetainingCapacity();

    // 7. If stream.[[pendingAbortRequest]] is undefined
    if (internal.pending_abort_request == null) {
        // 7.1. Perform ! WritableStreamRejectCloseAndClosedPromiseIfNeeded(stream)
        writableStreamRejectCloseAndClosedPromiseIfNeeded(instance, internal);
        return;
    }

    // 8. Let abortRequest be stream.[[pendingAbortRequest]]
    const abort_request = internal.pending_abort_request.?;

    // 9. Set stream.[[pendingAbortRequest]] to undefined
    internal.pending_abort_request = null;

    // 10. If abortRequest's wasAlreadyErroring is true
    if (abort_request.was_already_erroring) {
        // 10.1. Reject abortRequest's promise with storedError
        abort_request.promise.*.reject(stored_exception);

        // 10.2. Perform ! WritableStreamRejectCloseAndClosedPromiseIfNeeded(stream)
        writableStreamRejectCloseAndClosedPromiseIfNeeded(instance, internal);

        // Clean up abort request
        internal.allocator.destroy(abort_request);
        return;
    }

    // 11. Let promise be ! stream.[[controller]].[[AbortSteps]](abortRequest's reason)
    // For now, we'll handle this synchronously. Full async handling would require
    // promise chaining infrastructure (see whatwg-co23 blocker).
    var abort_succeeded = true;

    if (internal.controller) |controller| {
        const WritableStreamDefaultControllerImpl = @import("WritableStreamDefaultController.zig");
        const controller_state = controller.getState(interfaces.WritableStreamDefaultController.State);
        if (controller_state.own._internal) |controller_internal_ptr| {
            const controller_internal: *WritableStreamDefaultControllerImpl.InternalState = @ptrCast(@alignCast(controller_internal_ptr));

            // Call abort algorithm if provided
            if (controller_internal.abort_algorithm) |abort_fn| {
                // Create abort reason - use provided reason or undefined
                const abort_callback: callbacks.UnderlyingSinkAbortCallback = @ptrCast(@alignCast(abort_fn));
                // Use reason if provided, wrapped in Opt
                const reason_opt = if (abort_request.reason) |r| webidl.Opt(*const anyopaque).passed(r) else webidl.Opt(*const anyopaque).notPassed();
                // Call the abort callback - it returns a promise result
                // The callback should return a valid pointer (representing a promise)
                _ = abort_callback(reason_opt);
                // Callback invoked successfully
                abort_succeeded = true;
            }
        }
    }

    // 12. Upon fulfillment of abort promise
    if (abort_succeeded) {
        // 12.1. Resolve abortRequest's promise with undefined
        abort_request.promise.*.fulfill({});
    } else {
        // 13. Upon rejection with reason r
        // 13.1. Reject abortRequest's promise with r
        const abort_exception = webidl.errors.Exception.typeError(internal.allocator, "Abort algorithm failed") catch stored_exception;
        abort_request.promise.*.reject(abort_exception);
    }

    // 12.2/13.2. Perform ! WritableStreamRejectCloseAndClosedPromiseIfNeeded(stream)
    writableStreamRejectCloseAndClosedPromiseIfNeeded(instance, internal);

    // Clean up abort request
    internal.allocator.destroy(abort_request);
}

/// WritableStreamHasOperationMarkedInFlight - Check for in-flight operations
///
/// Spec: § 5.3.7
fn writableStreamHasOperationMarkedInFlight(internal: *const InternalState) bool {
    return internal.in_flight_write_request != null or internal.in_flight_close_request != null;
}

/// WritableStreamRejectCloseAndClosedPromiseIfNeeded - Reject close promises
///
/// Spec: § 5.3.8
fn writableStreamRejectCloseAndClosedPromiseIfNeeded(instance: *runtime.Instance, internal: *InternalState) void {
    _ = instance;

    const exception = webidl.errors.Exception.typeError(internal.allocator, "Stream errored") catch return;

    // If controller.[[closeRequest]] is not undefined, reject it
    if (internal.close_request) |close_req| {
        close_req.reject(exception);
        internal.close_request = null;
    }

    // Reject writer's closed promise if writer exists
    if (internal.writer != .none) {
        const writer = switch (internal.writer) {
            .default => |w| w,
            .none => return,
        };

        const writer_state = writer.getState(interfaces.WritableStreamDefaultWriter.State);
        if (writer_state.own._internal) |writer_internal| {
            if (writer_internal.closed_promise) |closed| {
                closed.reject(exception);
            }
        }
    }
}

/// Operation: close
///
/// Spec: https://streams.spec.whatwg.org/#ws-close
/// Promise<undefined> close()
///
/// Steps:
/// 1. If ! IsWritableStreamLocked(this) is true, return rejected promise
/// 2. If ! WritableStreamCloseQueuedOrInFlight(this) is true, return rejected promise
/// 3. Return ! WritableStreamClose(this)
pub fn call_close(instance: *runtime.Instance) anyerror!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Check if locked
    if (internal.writer != .none) {
        const promise = try AsyncPromise(void).init(
            internal.allocator,
            internal.event_loop,
        );
        const exception = try webidl.errors.Exception.typeError(internal.allocator, "Cannot close a locked stream");
        promise.*.reject(exception);
        return @ptrCast(promise);
    }

    // Step 2: Check if close already queued or in flight
    if (writableStreamCloseQueuedOrInFlight(internal)) {
        const promise = try AsyncPromise(void).init(
            internal.allocator,
            internal.event_loop,
        );
        const exception = try webidl.errors.Exception.typeError(internal.allocator, "Stream is already closing");
        promise.*.reject(exception);
        return @ptrCast(promise);
    }

    // Step 3: WritableStreamClose
    return writableStreamClose(instance, internal);
}

// ============================================================================
// Strategy Algorithms (using internal infrastructure)
// ============================================================================

/// ExtractHighWaterMark - validates and extracts HWM from strategy
fn extractHighWaterMark(strategy: *const dictionaries.QueuingStrategy, default_hwm: f64) !f64 {
    const hwm = strategy.highWaterMark orelse return default_hwm;
    // Validate per WHATWG spec (same as internal queuing_ops)
    if (std.math.isNan(hwm) or hwm < 0.0) {
        return error.RangeError;
    }
    return hwm;
}

/// ExtractSizeAlgorithm - extracts size function from strategy
fn extractSizeAlgorithm(strategy: *const dictionaries.QueuingStrategy) ?*const anyopaque {
    return strategy.size;
}

// ============================================================================
// Internal Algorithms
// ============================================================================

/// SetUpWritableStreamDefaultControllerFromUnderlyingSink
///
/// Spec: https://streams.spec.whatwg.org/#set-up-writable-stream-default-controller-from-underlying-sink
fn setUpWritableStreamDefaultControllerFromUnderlyingSink(
    stream_instance: *runtime.Instance,
    stream_internal: *InternalState,
    underlyingSink: *const anyopaque,
    underlyingSinkDict: *const dictionaries.UnderlyingSink,
    highWaterMark: f64,
    sizeAlgorithm: ?*const anyopaque,
) !void {
    const allocator = stream_internal.allocator;
    const ctx = stream_instance.ctx;

    // Create new controller
    const controller_instance = try interfaces.WritableStreamDefaultController.init(
        allocator,
        ctx,
    );
    errdefer interfaces.WritableStreamDefaultController.deinit(controller_instance);

    // Extract algorithms from underlying sink
    var start_algorithm: ?*const anyopaque = null;
    var write_algorithm: ?*const anyopaque = null;
    var close_algorithm: ?*const anyopaque = null;
    var abort_algorithm: ?*const anyopaque = null;

    if (underlyingSinkDict.start) |_| {
        start_algorithm = underlyingSinkDict.start;
    }

    if (underlyingSinkDict.write) |_| {
        write_algorithm = underlyingSinkDict.write;
    }

    if (underlyingSinkDict.close) |_| {
        close_algorithm = underlyingSinkDict.close;
    }

    if (underlyingSinkDict.abort) |_| {
        abort_algorithm = underlyingSinkDict.abort;
    }

    // SetUpWritableStreamDefaultController
    try setUpWritableStreamDefaultController(
        stream_instance,
        stream_internal,
        controller_instance,
        start_algorithm,
        write_algorithm,
        close_algorithm,
        abort_algorithm,
        highWaterMark,
        sizeAlgorithm,
    );

    _ = underlyingSink; // Will be used when we invoke callbacks
}

/// SetUpWritableStreamDefaultController
///
/// Spec: https://streams.spec.whatwg.org/#set-up-writable-stream-default-controller
fn setUpWritableStreamDefaultController(
    stream_instance: *runtime.Instance,
    stream_internal: *InternalState,
    controller_instance: *runtime.Instance,
    startAlgorithm: ?*const anyopaque,
    writeAlgorithm: ?*const anyopaque,
    closeAlgorithm: ?*const anyopaque,
    abortAlgorithm: ?*const anyopaque,
    highWaterMark: f64,
    sizeAlgorithm: ?*const anyopaque,
) !void {
    const allocator = stream_internal.allocator;

    // Get controller state
    const controller_state = controller_instance.getState(interfaces.WritableStreamDefaultController.State);

    // Create controller internal state
    const WritableStreamDefaultControllerImpl = @import("WritableStreamDefaultController.zig");
    const controller_internal = try allocator.create(WritableStreamDefaultControllerImpl.InternalState);
    errdefer allocator.destroy(controller_internal);

    // Create AbortController for the controller
    // Note: AbortController impl is currently a stub, but we create instance for structure
    const abort_controller = interfaces.AbortController.call_constructor(allocator, stream_instance.ctx) catch null;

    // Initialize controller internal state
    controller_internal.* = .{
        .stream = stream_instance,
        .write_algorithm = writeAlgorithm,
        .close_algorithm = closeAlgorithm,
        .abort_algorithm = abortAlgorithm,
        .strategy_hwm = highWaterMark,
        .strategy_size_algorithm = sizeAlgorithm,
        .isolate = stream_instance.ctx.engine_ctx, // V8 isolate from runtime context
        .v8_context = stream_instance.ctx.engine_ctx, // V8 context from runtime context
        .started = false,
        .queue = .{},
        .queue_total_size = 0.0,
        .abort_controller = abort_controller, // AbortController instance (stub implementation)
        .allocator = allocator,
    };

    controller_state.own._internal = controller_internal;

    // Set stream.[[controller]] to controller
    stream_internal.controller = controller_instance;

    // Invoke start algorithm if present
    if (startAlgorithm) |start_fn| {
        const start_callback: callbacks.UnderlyingSinkStartCallback = @ptrCast(@alignCast(start_fn));
        const start_result = start_callback(@ptrCast(controller_instance));
        _ = start_result; // Future: Handle promise
        controller_internal.started = true;
    } else {
        controller_internal.started = true;
    }

    // Set initial desired size
    // Future: Compute based on queue size and high water mark
}

/// WritableStreamCloseQueuedOrInFlight(stream)
///
/// Spec: https://streams.spec.whatwg.org/#writable-stream-close-queued-or-in-flight
///
/// Steps:
/// 1. If stream.[[closeRequest]] is undefined and stream.[[inFlightCloseRequest]] is undefined, return false
/// 2. Return true
pub fn writableStreamCloseQueuedOrInFlight(internal: *const InternalState) bool {
    return internal.close_request != null or internal.in_flight_close_request != null;
}

/// WritableStreamAbort(stream, reason)
///
/// Spec: https://streams.spec.whatwg.org/#writable-stream-abort
/// Spec: § 5.3.3 "Abort the stream with given reason"
///
/// Steps:
/// 1. If stream.[[state]] is "closed" or "errored", return resolved promise
/// 2. Signal abort on stream.[[controller]].[[abortController]] with reason
/// 3. Re-check state (may have changed during abort signal)
/// 4. If stream.[[state]] is "closed" or "errored", return resolved promise
/// 5. If stream.[[pendingAbortRequest]] is not undefined, return its promise
/// 6. Assert: state is "writable" or "erroring"
/// 7. Let wasAlreadyErroring = false
/// 8. If state is "erroring", set wasAlreadyErroring = true and reason = undefined
/// 9. Let promise be a new promise
/// 10. Set stream.[[pendingAbortRequest]] to { promise, reason, wasAlreadyErroring }
/// 11. If wasAlreadyErroring is false, perform WritableStreamStartErroring(stream, reason)
/// 12. Return promise
fn writableStreamAbort(
    instance: *runtime.Instance,
    internal: *InternalState,
    reason: *const anyopaque,
) !*const anyopaque {
    // Step 1: If stream.[[state]] is "closed" or "errored", return resolved promise
    if (internal.state == .closed or internal.state == .errored) {
        const promise = try AsyncPromise(void).init(
            internal.allocator,
            internal.event_loop,
        );
        promise.*.fulfill({});
        return @ptrCast(promise);
    }

    // Step 2: Signal abort on stream.[[controller]].[[abortController]] with reason
    // Note: This invokes the abort controller's abort algorithm which may run user code
    if (internal.controller) |controller| {
        const WritableStreamDefaultControllerImpl = @import("WritableStreamDefaultController.zig");
        const controller_state = controller.getState(interfaces.WritableStreamDefaultController.State);
        if (controller_state.own._internal) |controller_internal_ptr| {
            const controller_internal: *WritableStreamDefaultControllerImpl.InternalState = @ptrCast(@alignCast(controller_internal_ptr));
            if (controller_internal.abort_controller) |abort_controller| {
                // Signal abort on the AbortController
                interfaces.AbortController.call_abort(abort_controller, webidl.Opt(*const anyopaque).passed(reason)) catch {};
            }
        }
    }

    // Step 3-4: Re-check state (may have changed during abort signal - runs user code)
    if (internal.state == .closed or internal.state == .errored) {
        const promise = try AsyncPromise(void).init(
            internal.allocator,
            internal.event_loop,
        );
        promise.*.fulfill({});
        return @ptrCast(promise);
    }

    // Step 5: If stream.[[pendingAbortRequest]] is not undefined, return its promise
    if (internal.pending_abort_request) |existing_abort| {
        return @ptrCast(existing_abort.promise);
    }

    // Step 6: Assert: state is "writable" or "erroring"
    // (Gracefully handle instead of asserting)
    if (internal.state != .writable and internal.state != .erroring) {
        const promise = try AsyncPromise(void).init(
            internal.allocator,
            internal.event_loop,
        );
        promise.*.fulfill({});
        return @ptrCast(promise);
    }

    // Step 7: Let wasAlreadyErroring = false
    var was_already_erroring = false;

    // Step 8: If state is "erroring", set wasAlreadyErroring = true and reason = undefined
    var abort_reason: ?*const anyopaque = reason;
    if (internal.state == .erroring) {
        was_already_erroring = true;
        abort_reason = null;
    }

    // Step 9: Let promise be a new promise
    const promise = try AsyncPromise(void).init(
        internal.allocator,
        internal.event_loop,
    );

    // Step 10: Set stream.[[pendingAbortRequest]] to { promise, reason, wasAlreadyErroring }
    const abort_request = try internal.allocator.create(AbortRequest);
    abort_request.* = .{
        .promise = promise,
        .reason = abort_reason,
        .was_already_erroring = was_already_erroring,
    };
    internal.pending_abort_request = abort_request;

    // Step 11: If wasAlreadyErroring is false, perform WritableStreamStartErroring(stream, reason)
    if (!was_already_erroring) {
        writableStreamStartErroring(instance, abort_reason orelse reason);
    }

    // Step 12: Return promise
    return @ptrCast(promise);
}

/// WritableStreamClose(stream)
///
/// Spec: https://streams.spec.whatwg.org/#writable-stream-close
///
/// Simplified implementation - returns immediately resolved promise
fn writableStreamClose(
    instance: *runtime.Instance,
    internal: *InternalState,
) !*const anyopaque {
    _ = instance;

    const promise = try AsyncPromise(void).init(
        internal.allocator,
        internal.event_loop,
    );

    // Simplified: Check state
    if (internal.state != .writable) {
        const exception = try webidl.errors.Exception.typeError(internal.allocator, "Stream is not writable");
        promise.*.reject(exception);
    } else {
        // Future: Implement full close algorithm with controller
        // For now, just fulfill
        promise.*.fulfill({});
    }

    return @ptrCast(promise);
}
