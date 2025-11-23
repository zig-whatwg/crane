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

    /// [[writeRequests]]: List of pending write promises
    write_requests: std.ArrayList(*AsyncPromise(void)),

    /// [[inFlightWriteRequest]]: Promise for the currently executing write
    in_flight_write_request: ?*AsyncPromise(void),

    /// [[closeRequest]]: Promise for pending close request
    close_request: ?*AsyncPromise(void),

    /// [[inFlightCloseRequest]]: Promise for currently executing close
    in_flight_close_request: ?*AsyncPromise(void),

    /// [[pendingAbortRequest]]: Record of pending abort request
    pending_abort_request: ?*anyopaque,

    /// [[backpressure]]: boolean indicating if backpressure is applied
    backpressure: bool,

    /// Event loop for async operations
    event_loop: event_loop.EventLoop,

    /// Resource management
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        // Clean up write requests
        for (self.write_requests.items) |promise| {
            promise.deinit();
        }
        self.write_requests.deinit(allocator);

        // Clean up in-flight requests if present
        if (self.in_flight_write_request) |promise| {
            promise.deinit();
        }
        if (self.close_request) |promise| {
            promise.deinit();
        }
        if (self.in_flight_close_request) |promise| {
            promise.deinit();
        }

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
    // InternalState is initialized in constructor
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
pub fn call_constructor(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    underlyingSink: *const anyopaque,
    strategy: dictionaries.QueuingStrategy,
) !*runtime.Instance {
    // Get event loop from context
    const loop = try ctx.getEventLoop();

    // Step 1: If underlyingSink is missing, it would be null (handled by caller)

    // Step 2: Convert to UnderlyingSink dictionary
    const underlying_sink_dict: *const dictionaries.UnderlyingSink = @ptrCast(@alignCast(underlyingSink));

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
    const size_algorithm = extractSizeAlgorithm(&strategy);
    _ = size_algorithm; // Will be passed to controller

    // Step 6: Extract high water mark (default 1 for writable)
    const high_water_mark = try extractHighWaterMark(&strategy, 1.0);

    // Step 7: SetUpWritableStreamDefaultControllerFromUnderlyingSink
    try setUpWritableStreamDefaultControllerFromUnderlyingSink(
        instance,
        internal,
        underlyingSink,
        underlying_sink_dict,
        high_water_mark,
    );

    return instance;
}

/// Getter for locked
///
/// Spec: https://streams.spec.whatwg.org/#ws-locked
/// readonly attribute boolean locked
///
/// Returns true if the stream is locked to a writer.
pub fn get_locked(instance: *runtime.Instance) ImplError!bool {
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
pub fn call_getWriter(instance: *runtime.Instance) ImplError!*runtime.Instance {
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
pub fn call_abort(instance: *runtime.Instance, reason: *const anyopaque) ImplError!*const anyopaque {
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

    // Step 2: WritableStreamAbort
    return writableStreamAbort(instance, internal, reason);
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
pub fn call_close(instance: *runtime.Instance) ImplError!*const anyopaque {
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
// Strategy Algorithms (shared with ReadableStream)
// ============================================================================

/// ExtractHighWaterMark(strategy, defaultHWM)
fn extractHighWaterMark(strategy: *const dictionaries.QueuingStrategy, default_hwm: f64) !f64 {
    const hwm = strategy.highWaterMark orelse return default_hwm;
    if (std.math.isNan(hwm) or hwm < 0.0) {
        return error.RangeError;
    }
    return hwm;
}

/// ExtractSizeAlgorithm(strategy)
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
) !void {
    const allocator = stream_internal.allocator;

    // Get controller state
    const controller_state = controller_instance.getState(interfaces.WritableStreamDefaultController.State);

    // Create controller internal state
    const WritableStreamDefaultControllerImpl = @import("WritableStreamDefaultController.zig");
    const controller_internal = try allocator.create(WritableStreamDefaultControllerImpl.InternalState);
    errdefer allocator.destroy(controller_internal);

    // Initialize controller internal state
    controller_internal.* = .{
        .stream = stream_instance,
        .write_algorithm = writeAlgorithm,
        .close_algorithm = closeAlgorithm,
        .abort_algorithm = abortAlgorithm,
        .strategy_hwm = highWaterMark,
        .strategy_size_algorithm = null, // Future: Pass size algorithm
        .started = false,
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
fn writableStreamCloseQueuedOrInFlight(internal: *const InternalState) bool {
    return internal.close_request != null or internal.in_flight_close_request != null;
}

/// WritableStreamAbort(stream, reason)
///
/// Spec: https://streams.spec.whatwg.org/#writable-stream-abort
///
/// Simplified implementation - returns immediately resolved/rejected promise
fn writableStreamAbort(
    instance: *runtime.Instance,
    internal: *InternalState,
    reason: *const anyopaque,
) !*const anyopaque {
    _ = instance;
    _ = reason;

    const promise = try AsyncPromise(void).init(
        internal.allocator,
        internal.event_loop,
    );

    // Simplified: Check state and resolve/reject accordingly
    if (internal.state == .closed or internal.state == .errored) {
        promise.*.fulfill({});
    } else {
        // Future: Implement full abort algorithm
        // For now, just fulfill
        promise.*.fulfill({});
    }

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
