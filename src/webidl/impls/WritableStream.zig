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
const v8_engine = @import("v8");
const v8 = v8_engine;

// Type-safe V8 value system
const StoredError = v8_engine.stored_error.StoredError;

// Import streams infrastructure
const streams_common = @import("streams_common");
const event_loop = @import("streams_event_loop");
const AsyncPromise = @import("streams_async_promise").AsyncPromise;
const WriteRequest = @import("streams_write_request").WriteRequest;

// Promise utilities for bridging Zig AsyncPromise to V8 Promise
const promise_utils = v8_engine.promise;

pub const State = WritableStream.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    RangeError,
    InvalidState,
    OutOfMemory,
    // V8 promise bridge errors
    NoIsolate,
    NoContext,
    PromiseCreationFailed,
    PromiseResolveFailed,
    PromiseRejectFailed,
    StringError,
    NullContext,
    GlobalHandleCreationFailed,
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
    /// Uses type-safe StoredError instead of raw anyopaque
    stored_error: StoredError = .none,

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

    // Dispose stored error (frees V8 Global handle if present)
    internal.stored_error.dispose();

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
pub fn call_constructor(ctx: runtime.Context, underlyingSink: webidl.Opt(runtime.JSValue), strategy: webidl.Opt(dictionaries.QueuingStrategy)) !*runtime.Instance {
    // Get event loop from context
    const loop = try ctx.getEventLoop();

    // Step 1: If underlyingSink is missing, use default
    const underlying_sink_ptr: ?*const anyopaque = if (underlyingSink.was_passed)
        underlyingSink.value.toAnyopaque()
    else
        null;

    // Step 2: Convert to UnderlyingSink dictionary (if provided)
    const default_sink = dictionaries.UnderlyingSink{};
    const underlying_sink_dict: *const dictionaries.UnderlyingSink = if (underlying_sink_ptr) |ptr| blk: {
        // Untag the pointer before casting - it may be tagged by V8 conversions
        const pointer_tag = @import("v8").pointer_tag;
        const untagged = pointer_tag.untagPointer(ptr);

        // If it's a runtime instance, this is not a valid UnderlyingSink dictionary
        if (untagged.tag == .runtime_instance) {
            return error.TypeError;
        }

        break :blk @ptrCast(@alignCast(untagged.ptr));
    } else &default_sink;

    // Step 3: If type exists, throw RangeError (reserved for future use)
    if (underlying_sink_dict.type != null) {
        return error.RangeError;
    }

    // Step 4: Perform InitializeWritableStream
    const instance = try init(ctx.allocator, State, &WritableStream.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Create internal state
    const internal = try ctx.allocator.create(InternalState);
    errdefer ctx.allocator.destroy(internal);

    // InitializeWritableStream: Set initial state
    internal.* = InternalState{
        .controller = null, // Will be set by SetUp
        .writer = .none,
        .state = .writable,
        .stored_error = .none, // Type-safe StoredError
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
        .allocator = ctx.allocator,
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
    const ctx = instance.ctx;
    _ = internal;

    // AcquireWritableStreamDefaultWriter
    const writer = try interfaces.WritableStreamDefaultWriter.call_constructor(
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
pub fn call_abort(instance: *runtime.Instance, reason: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Check if locked
    if (internal.writer != .none) {
        // Get V8 isolate and context for creating a proper V8 Promise
        const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
        const context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoContext;

        const exception = try webidl.errors.Exception.typeError(internal.allocator, "Cannot abort a locked stream");
        const v8_promise = try promise_utils.createRejectedV8Promise(isolate, context, exception);
        return runtime.JSValue.fromPromise(@ptrCast(v8_promise));
    }

    // Step 2: Return WritableStreamAbort(this, reason)
    // If reason is not passed, use a default undefined-like value
    const default_reason: u8 = 0;
    const reason_ptr: *const anyopaque = if (reason.was_passed)
        reason.value.toAnyopaque() orelse @ptrCast(&default_reason)
    else
        @ptrCast(&default_reason);
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
    if (internal.state != .writable or internal.stored_error.hasError()) {
        return; // Graceful handling instead of assert
    }

    // 3. Let controller be stream.[[controller]]
    const controller = internal.controller orelse return;

    // 4. Assert: controller is not undefined
    // (Already checked above)

    // 5. Set stream.[[state]] to "erroring"
    internal.state = .erroring;

    // 6. Set stream.[[storedError]] to reason
    internal.stored_error.storeRawPtr(@constCast(reason));

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
    if (internal.controller) |controller| {
        const WritableStreamDefaultControllerImpl = @import("WritableStreamDefaultController.zig");

        // Get the abort reason as a type-safe JSValue
        // Convert the anyopaque abort reason to streams_common.JSValue
        const reason: streams_common.JSValue = if (abort_request.reason) |reason_ptr|
            streams_common.JSValue.fromEnginePtr(internal.allocator, @constCast(reason_ptr)) catch
                streams_common.JSValue{ .undefined = {} }
        else
            // Use stored exception as default reason
            streams_common.JSValue.fromEnginePtr(internal.allocator, @constCast(@as(*const anyopaque, @ptrCast(&stored_exception)))) catch
                streams_common.JSValue{ .undefined = {} };

        // Call abortSteps which properly invokes the V8 abort callback
        const abort_promise = WritableStreamDefaultControllerImpl.abortSteps(controller, reason) catch {
            // On error, reject the abort request promise
            abort_request.promise.*.reject(stored_exception);
            writableStreamRejectCloseAndClosedPromiseIfNeeded(instance, internal);
            internal.allocator.destroy(abort_request);
            return;
        };

        // Check if the promise is already settled
        if (abort_promise.isFulfilled()) {
            // 12. Upon fulfillment of abort promise
            // 12.1. Resolve abortRequest's promise with undefined
            abort_request.promise.*.fulfill({});
            writableStreamRejectCloseAndClosedPromiseIfNeeded(instance, internal);
            internal.allocator.destroy(abort_request);
            return;
        }

        if (abort_promise.isRejected()) {
            // 13. Upon rejection with reason r
            // 13.1. Reject abortRequest's promise with r
            const abort_exception = abort_promise.state.rejected;
            abort_request.promise.*.reject(abort_exception);
            writableStreamRejectCloseAndClosedPromiseIfNeeded(instance, internal);
            internal.allocator.destroy(abort_request);
            return;
        }

        // Promise is pending - allocate context first
        const async_ctx = internal.allocator.create(FinishErroringAbortContext) catch {
            // Fallback: fulfill immediately on allocation failure
            abort_request.promise.*.fulfill({});
            writableStreamRejectCloseAndClosedPromiseIfNeeded(instance, internal);
            internal.allocator.destroy(abort_request);
            return;
        };
        async_ctx.* = .{
            .instance = instance,
            .internal = internal,
            .abort_request = abort_request,
            .allocator = internal.allocator,
        };

        // Attach handlers for async settlement
        abort_promise.onSettleCtx(
            struct {
                fn onFulfilled(ctx_ptr: ?*anyopaque, _: void) anyerror!void {
                    const ctx: *FinishErroringAbortContext = @ptrCast(@alignCast(ctx_ptr orelse return error.InvalidState));
                    defer ctx.allocator.destroy(ctx);

                    // 12.1. Resolve abortRequest's promise with undefined
                    ctx.abort_request.promise.*.fulfill({});

                    // 12.2. Perform ! WritableStreamRejectCloseAndClosedPromiseIfNeeded(stream)
                    writableStreamRejectCloseAndClosedPromiseIfNeeded(ctx.instance, ctx.internal);

                    ctx.allocator.destroy(ctx.abort_request);
                }
            }.onFulfilled,
            struct {
                fn onRejected(ctx_ptr: ?*anyopaque, exception: webidl.errors.Exception) anyerror!void {
                    const ctx: *FinishErroringAbortContext = @ptrCast(@alignCast(ctx_ptr orelse return error.InvalidState));
                    defer ctx.allocator.destroy(ctx);

                    // 13.1. Reject abortRequest's promise with r
                    ctx.abort_request.promise.*.reject(exception);

                    // 13.2. Perform ! WritableStreamRejectCloseAndClosedPromiseIfNeeded(stream)
                    writableStreamRejectCloseAndClosedPromiseIfNeeded(ctx.instance, ctx.internal);

                    ctx.allocator.destroy(ctx.abort_request);
                }
            }.onRejected,
            @ptrCast(async_ctx),
        ) catch {
            // Fallback: fulfill immediately
            internal.allocator.destroy(async_ctx);
            abort_request.promise.*.fulfill({});
            writableStreamRejectCloseAndClosedPromiseIfNeeded(instance, internal);
            internal.allocator.destroy(abort_request);
            return;
        };

        // Return here - handlers will complete the operation
        return;
    } else {
        // No controller - just fulfill
        abort_request.promise.*.fulfill({});
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
pub fn call_close(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Check if locked
    if (internal.writer != .none) {
        // Get V8 isolate and context for creating a proper V8 Promise
        const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
        const context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoContext;

        const exception = try webidl.errors.Exception.typeError(internal.allocator, "Cannot close a locked stream");
        const v8_promise = try promise_utils.createRejectedV8Promise(isolate, context, exception);
        return runtime.JSValue.fromPromise(@ptrCast(v8_promise));
    }

    // Step 2: Check if close already queued or in flight
    if (writableStreamCloseQueuedOrInFlight(internal)) {
        // Get V8 isolate and context for creating a proper V8 Promise
        const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
        const context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoContext;

        const exception = try webidl.errors.Exception.typeError(internal.allocator, "Stream is already closing");
        const v8_promise = try promise_utils.createRejectedV8Promise(isolate, context, exception);
        return runtime.JSValue.fromPromise(@ptrCast(v8_promise));
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

/// Extract a GlobalHandle from a tagged callback pointer.
///
/// The V8 conversions layer tags callback pointers with `.global_handle` to indicate
/// they are V8 Global handles (not Local handles that expire with HandleScope).
///
/// This function untags the pointer and wraps it in a GlobalHandle struct for proper
/// lifetime management and disposal.
///
/// Parameters:
///   callback_ptr: A tagged pointer to a V8 Global handle (cast as ?*const anyopaque)
///
/// Returns:
///   A GlobalHandle wrapping the V8 Global, or null if callback_ptr is null
fn extractGlobalHandle(callback_ptr: ?*const anyopaque) v8_engine.OptionalGlobalHandle {
    if (callback_ptr) |ptr| {
        // Untag the pointer to get the raw V8 Global pointer and the tag
        const untagged = v8_engine.pointer_tag.untagPointer(ptr);

        // Verify the tag is global_handle (or handle untagged for backwards compatibility)
        if (untagged.tag == .global_handle or untagged.tag == .untagged) {
            // Wrap the raw pointer in a GlobalHandle struct for proper disposal
            return v8_engine.GlobalHandle{ .ptr = @ptrCast(@alignCast(untagged.ptr)) };
        } else {
            // Unexpected tag - this shouldn't happen for callbacks
            // Return null to avoid crashes, but log in debug mode
            if (@import("std").debug.runtime_safety) {
                @import("std").log.err("extractGlobalHandle: unexpected tag {} for callback pointer", .{untagged.tag});
            }
            return null;
        }
    }
    return null;
}

/// SetUpWritableStreamDefaultController
///
/// Spec: https://streams.spec.whatwg.org/#set-up-writable-stream-default-controller
///
/// ## V8 Handle Lifetime
///
/// The callback parameters (start, write, close, abort, size) are tagged pointers to V8 Global
/// handles. The V8 conversions layer creates Global handles and tags the pointers during
/// dictionary extraction to ensure callbacks survive HandleScope destruction.
///
/// This function untags the pointers and wraps them in GlobalHandle structs.
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

    // Get V8 isolate (for potential future use, but Global handles already created)
    const isolate: ?*v8_engine.ffi.Isolate = stream_instance.ctx.getEngineContextAs(v8_engine.ffi.Isolate);

    // Get controller state
    const controller_state = controller_instance.getState(interfaces.WritableStreamDefaultController.State);

    // Create controller internal state
    const WritableStreamDefaultControllerImpl = @import("WritableStreamDefaultController.zig");
    const controller_internal = try allocator.create(WritableStreamDefaultControllerImpl.InternalState);
    errdefer allocator.destroy(controller_internal);

    // Create AbortController for the controller
    // Note: AbortController impl is currently a stub, but we create instance for structure
    const abort_controller = interfaces.AbortController.call_constructor(stream_instance.ctx) catch null;

    // Extract GlobalHandles from tagged callback pointers.
    // The V8 conversions layer tags callbacks with .global_handle during dictionary extraction.
    // We just need to untag them and wrap in GlobalHandle structs.
    const start_global = extractGlobalHandle(startAlgorithm);
    const write_global = extractGlobalHandle(writeAlgorithm);
    const close_global = extractGlobalHandle(closeAlgorithm);
    const abort_global = extractGlobalHandle(abortAlgorithm);
    const size_global = extractGlobalHandle(sizeAlgorithm);

    // Initialize controller internal state with Global handles
    controller_internal.* = .{
        .stream = stream_instance,
        .write_algorithm = write_global,
        .close_algorithm = close_global,
        .abort_algorithm = abort_global,
        .start_algorithm = start_global,
        .strategy_hwm = highWaterMark,
        .strategy_size_algorithm = size_global,
        .isolate = isolate,
        .v8_context = stream_instance.ctx.engine_ctx,
        .started = false,
        .queue = .{},
        .queue_total_size = 0.0,
        .abort_controller = abort_controller,
        .allocator = allocator,
    };

    controller_state.own._internal = controller_internal;

    // Set stream.[[controller]] to controller
    stream_internal.controller = controller_instance;

    // Note: The start algorithm is NOT invoked here.
    // Per WHATWG Streams spec, the start callback is invoked asynchronously after construction.
    // V8 will call invokePendingStartCallback() which handles Promise results properly.
    // If there's no start algorithm, mark as started immediately.
    if (start_global == null) {
        controller_internal.started = true;
    }
    // If there IS a start algorithm, it remains started=false until invokePendingStartCallback
    // is called and the Promise (if any) fulfills.
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
) !runtime.JSValue {
    // Step 1: If stream.[[state]] is "closed" or "errored", return resolved promise
    if (internal.state == .closed or internal.state == .errored) {
        // Get V8 isolate and context for creating a proper V8 Promise
        const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
        const context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoContext;

        const v8_promise = try promise_utils.createResolvedV8Promise(void, isolate, context, {});
        return runtime.JSValue.fromPromise(@ptrCast(v8_promise));
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
                interfaces.AbortController.call_abort(abort_controller, webidl.Opt(runtime.JSValue).passed(runtime.JSValue.fromAnyopaque(reason))) catch {};
            }
        }
    }

    // Step 3-4: Re-check state (may have changed during abort signal - runs user code)
    if (internal.state == .closed or internal.state == .errored) {
        // Get V8 isolate and context for creating a proper V8 Promise
        const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
        const context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoContext;

        const v8_promise = try promise_utils.createResolvedV8Promise(void, isolate, context, {});
        return runtime.JSValue.fromPromise(@ptrCast(v8_promise));
    }

    // Step 5: If stream.[[pendingAbortRequest]] is not undefined, return its promise
    // Bridge the existing AsyncPromise to a V8 Promise
    if (internal.pending_abort_request) |existing_abort| {
        const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
        const context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoContext;

        const v8_promise = try promise_utils.asyncPromiseToV8(void, std.heap.c_allocator, isolate, context, existing_abort.promise);
        return runtime.JSValue.fromPromise(@ptrCast(v8_promise));
    }

    // Step 6: Assert: state is "writable" or "erroring"
    // (Gracefully handle instead of asserting)
    if (internal.state != .writable and internal.state != .erroring) {
        // Get V8 isolate and context for creating a proper V8 Promise
        const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
        const context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoContext;

        const v8_promise = try promise_utils.createResolvedV8Promise(void, isolate, context, {});
        return runtime.JSValue.fromPromise(@ptrCast(v8_promise));
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

    // Step 12: Return promise (bridge Zig AsyncPromise to V8 Promise)
    const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
    const context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoContext;

    const v8_promise = try promise_utils.asyncPromiseToV8(void, std.heap.c_allocator, isolate, context, promise);
    return runtime.JSValue.fromPromise(@ptrCast(v8_promise));
}

/// WritableStreamClose(stream)
///
/// Spec: https://streams.spec.whatwg.org/#writable-stream-close
///
/// Simplified implementation - returns immediately resolved promise
fn writableStreamClose(
    instance: *runtime.Instance,
    internal: *InternalState,
) !runtime.JSValue {
    _ = instance;

    // Get V8 isolate and context for creating a proper V8 Promise
    const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
    const context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoContext;

    // Simplified: Check state
    if (internal.state != .writable) {
        const exception = try webidl.errors.Exception.typeError(internal.allocator, "Stream is not writable");
        const v8_promise = try promise_utils.createRejectedV8Promise(isolate, context, exception);
        return runtime.JSValue.fromPromise(@ptrCast(v8_promise));
    } else {
        // Future: Implement full close algorithm with controller
        // For now, just fulfill
        const v8_promise = try promise_utils.createResolvedV8Promise(void, isolate, context, {});
        return runtime.JSValue.fromPromise(@ptrCast(v8_promise));
    }
}

// ============================================================================
// Start Algorithm Invocation (for V8 Promise handling)
// ============================================================================

/// Invoke the pending start callback for a WritableStream's controller.
///
/// This is called by V8 after the stream is constructed to invoke the user's
/// start() callback. If the callback returns a Promise, we chain handlers
/// to wait for it to settle before marking the controller as started.
///
/// Spec: https://streams.spec.whatwg.org/#set-up-writable-stream-default-controller
/// Steps 8-10 (start algorithm invocation and promise handling)
///
/// ## V8 Handle Lifetime
///
/// The start_algorithm is stored as a GlobalHandle to survive HandleScope destruction.
/// We get a Local from the Global for the duration of this call, then dispose the Global.
///
/// Arguments:
/// - instance: The WritableStream instance
/// - controller_v8: The V8 Object wrapper for the controller
/// - v8_isolate: The V8 Isolate
/// - v8_context: The V8 Context
///
/// Returns: void (errors are handled by erroring the stream)
pub fn invokePendingStartCallback(
    instance: *runtime.Instance,
    controller_v8: *anyopaque,
    v8_isolate: *anyopaque,
    v8_context: *anyopaque,
) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    const controller_instance = internal.controller orelse return;

    const WritableStreamDefaultControllerImpl = @import("WritableStreamDefaultController.zig");
    const controller_state = controller_instance.getState(interfaces.WritableStreamDefaultController.State);
    const controller_internal: *WritableStreamDefaultControllerImpl.InternalState = @ptrCast(@alignCast(controller_state.own._internal orelse return));

    // Check if there's a pending start algorithm and controller hasn't started
    const start_global = controller_internal.start_algorithm orelse {
        // No start algorithm - mark as started immediately (if not already)
        if (!controller_internal.started) {
            onWritableStartFulfilledImmediate(controller_internal);
        }
        return;
    };

    if (controller_internal.started) {
        // Already started - nothing to do
        return;
    }

    // Cast the opaque pointer to V8 types
    const isolate: *v8.Isolate = @ptrCast(@alignCast(v8_isolate));
    const context: *v8.Context = @ptrCast(@alignCast(v8_context));
    const controller_obj: *v8.Object = @ptrCast(@alignCast(controller_v8));

    // Get a Local<Value> from the Global handle for this invocation.
    // The Global handle persists across HandleScope boundaries, so this is safe.
    const v8_value: *v8.Value = start_global.get(isolate) orelse {
        // Global handle is empty or invalid - dispose and mark as started
        v8_engine.disposeOptionalGlobalHandle(&controller_internal.start_algorithm);
        onWritableStartFulfilledImmediate(controller_internal);
        return;
    };

    // Verify the value is a function before calling
    if (!v8.ffi.v8_Value_IsFunction(v8_value)) {
        // Not a function - dispose and mark as started
        v8_engine.disposeOptionalGlobalHandle(&controller_internal.start_algorithm);
        onWritableStartFulfilledImmediate(controller_internal);
        return;
    }

    const func: *v8.Function = @ptrCast(v8_value);

    // Call the V8 function with the controller as argument
    // Use 'undefined' as 'this' since start() is not called as a method
    const undefined_recv = v8.ffi.v8_Undefined(isolate) orelse {
        // Couldn't get undefined - dispose and mark as started
        v8_engine.disposeOptionalGlobalHandle(&controller_internal.start_algorithm);
        onWritableStartFulfilledImmediate(controller_internal);
        return;
    };
    var args = [_]*v8.Value{@ptrCast(controller_obj)};
    const result = v8.ffi.v8_Function_Call(func, context, undefined_recv, 1, &args);

    // Dispose the Global handle now that we've invoked it (start is only called once)
    v8_engine.disposeOptionalGlobalHandle(&controller_internal.start_algorithm);

    // Check if call succeeded
    if (result == null) {
        // Call threw an exception - error the stream
        const js_error = streams_common.JSValue{ .string = "Start callback threw an exception" };
        writableStreamStartErroring(instance, @ptrCast(&js_error));
        return;
    }

    // Per WHATWG Streams spec § 4.5.3 SetUpWritableStreamDefaultController:
    // Let startPromise be a promise resolved with startResult.
    // Upon fulfillment of startPromise: set started = true
    // Upon rejection of startPromise with reason r: error the stream

    // Unwrap the result (already checked for null above)
    const result_value: *v8.Value = result.?;

    // Check if result is a Promise
    const is_promise = v8.ffi.v8_Value_IsPromise(result_value);
    if (is_promise) {
        // Result is a Promise - chain handlers to wait for it to settle
        const promise: *v8.ffi.Promise = @ptrCast(result_value);

        // Create context for the callbacks (store pointers needed for completion)
        const callback_ctx = controller_internal.allocator.create(WritableStartCallbackContext) catch {
            // Allocation failed - fall back to immediate fulfillment
            onWritableStartFulfilledImmediate(controller_internal);
            return;
        };
        callback_ctx.* = .{
            .controller_internal = controller_internal,
            .stream_instance = instance,
            .allocator = controller_internal.allocator,
        };

        // Create fulfill handler
        const fulfill_handler = v8.ffi.v8_CreateZigFulfillHandler(
            context,
            onWritableStartPromiseFulfilled,
            callback_ctx,
        ) orelse {
            // Failed to create handler - fall back to immediate fulfillment
            controller_internal.allocator.destroy(callback_ctx);
            onWritableStartFulfilledImmediate(controller_internal);
            return;
        };

        // Create reject handler
        const reject_handler = v8.ffi.v8_CreateZigRejectHandler(
            context,
            onWritableStartPromiseRejected,
            callback_ctx,
        ) orelse {
            // Failed to create handler - clean up and fall back
            v8.ffi.v8_DisposeZigCallbackHandler(fulfill_handler);
            controller_internal.allocator.destroy(callback_ctx);
            onWritableStartFulfilledImmediate(controller_internal);
            return;
        };

        // Chain handlers onto the promise
        const chained = v8.ffi.v8_Promise_Then(promise, context, fulfill_handler, reject_handler);
        if (chained == null) {
            // Failed to chain - clean up and fall back
            v8.ffi.v8_DisposeZigCallbackHandler(reject_handler);
            v8.ffi.v8_DisposeZigCallbackHandler(fulfill_handler);
            controller_internal.allocator.destroy(callback_ctx);
            onWritableStartFulfilledImmediate(controller_internal);
            return;
        }
        // Promise handlers are now chained - they will be called when the promise settles
        // The callback context will be freed in the callback handlers
    } else {
        // Result is not a Promise - mark as started immediately
        onWritableStartFulfilledImmediate(controller_internal);
    }
}

/// Context for async abort handling in writableStreamFinishErroring
/// Allocated when abort promise is pending, freed when promise settles
const FinishErroringAbortContext = struct {
    instance: *runtime.Instance,
    internal: *InternalState,
    abort_request: *AbortRequest,
    allocator: std.mem.Allocator,
};

/// Context for V8 promise callbacks from invokePendingStartCallback
/// This is allocated and passed to the V8 promise handlers, then freed in the callbacks
const WritableStartCallbackContext = struct {
    controller_internal: *@import("WritableStreamDefaultController.zig").InternalState,
    stream_instance: *runtime.Instance,
    allocator: std.mem.Allocator,
};

/// V8 Promise fulfillment callback for start() promise
/// Called when an async start(controller) function's promise fulfills
/// Spec: § 4.5.3 SetUpWritableStreamDefaultController - Upon fulfillment of startPromise
fn onWritableStartPromiseFulfilled(ctx: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {
    const callback_ctx: *WritableStartCallbackContext = @ptrCast(@alignCast(ctx orelse return));
    defer callback_ctx.allocator.destroy(callback_ctx);

    // Mark the controller as started
    onWritableStartFulfilledImmediate(callback_ctx.controller_internal);
}

/// V8 Promise rejection callback for start() promise
/// Called when an async start(controller) function's promise rejects
/// Spec: § 4.5.3 SetUpWritableStreamDefaultController - Upon rejection of startPromise with reason r
fn onWritableStartPromiseRejected(ctx: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {
    const callback_ctx: *WritableStartCallbackContext = @ptrCast(@alignCast(ctx orelse return));
    defer callback_ctx.allocator.destroy(callback_ctx);

    // Error the stream with the rejection reason
    const js_error = streams_common.JSValue{ .string = "Start callback promise rejected" };
    writableStreamStartErroring(callback_ctx.stream_instance, @ptrCast(&js_error));
}

/// Immediate start fulfillment (no async)
/// Spec: § 4.5.3 SetUpWritableStreamDefaultController - Upon fulfillment of startPromise
fn onWritableStartFulfilledImmediate(controller_internal: *@import("WritableStreamDefaultController.zig").InternalState) void {
    // Set controller.[[started]] to true
    controller_internal.started = true;

    // Per spec: Assert that stream.[[state]] is "writable" or "erroring"
    // Then: Perform WritableStreamDefaultControllerAdvanceQueueIfNeeded(controller)
    // This processes any writes that were queued while waiting for start to complete.

    // For now, we just mark as started. The queue advancement will happen
    // when write operations check the started flag.
}
