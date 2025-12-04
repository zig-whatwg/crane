//! Implementation for TransformStream interface
//!
//! Spec: https://streams.spec.whatwg.org/#ts-class
//!
//! Represents a transformation that consists of a pair of streams.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const TransformStream = interfaces.TransformStream;

// Import streams infrastructure
const streams_common = @import("streams_common");
const JSValue = streams_common.JSValue;
const Promise = streams_common.Promise;

pub const State = TransformStream.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    RangeError,
    OutOfMemory,
    InvalidState,
};

/// Internal state for TransformStream
///
/// Spec: § 6.1.2 "Internal slots"
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// [[backpressure]]: boolean - whether backpressure signal has been sent
    backpressure: bool,

    /// [[backpressureChangePromise]]: Promise that resolves when backpressure changes
    /// Spec: § 6.1.2 Internal slots
    backpressureChangePromise: ?Promise(void),

    /// [[readable]]: ReadableStream representing the readable side
    readableStream: ?*runtime.Instance,

    /// [[writable]]: WritableStream representing the writable side
    writableStream: ?*runtime.Instance,

    /// [[controller]]: TransformStreamDefaultController
    controller: ?*runtime.Instance,

    /// V8 context for callback invocation
    isolate: ?*anyopaque,
    v8_context: ?*anyopaque,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        // Clean up is handled by WritableStream and ReadableStream deinit
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
    // InternalState is set up by constructor
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(internal.allocator);
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
///
/// Spec: § 6.1 "The new TransformStream(transformer, writableStrategy, readableStrategy) constructor steps"
///
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, transformer: webidl.Opt(*const anyopaque), writableStrategy: webidl.Opt(dictionaries.QueuingStrategy), readableStrategy: webidl.Opt(dictionaries.QueuingStrategy)) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &TransformStream.vtable, ctx);
    errdefer deinit(instance);

    // Initialize InternalState
    const state = instance.getState(State);
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = InternalState{
        .allocator = allocator,
        .backpressure = false,
        .backpressureChangePromise = null,
        .readableStream = null,
        .writableStream = null,
        .controller = null,
        .isolate = ctx.engine_ctx,
        .v8_context = null,
    };

    state.own._internal = internal;

    // Spec step 1: If transformer is missing, set it to null (handled by caller)

    // Spec step 2: Let transformerDict be transformer, converted to IDL type Transformer
    // (transformer will be passed to setUpTransformStreamDefaultControllerFromTransformer)

    // Spec step 3-4: If transformerDict["readableType"] or ["writableType"] exists, throw RangeError
    // (Reserved for future use - not implemented yet)

    // Spec step 5: Let readableHighWaterMark be ? ExtractHighWaterMark(readableStrategy, 0)
    const readable_strategy = if (readableStrategy.was_passed) readableStrategy.value else dictionaries.QueuingStrategy{};
    const readable_hwm = extractHighWaterMark(&readable_strategy, 0.0) catch {
        allocator.destroy(internal);
        deinit(instance);
        return error.RangeError;
    };

    // Spec step 6: Let readableSizeAlgorithm be ! ExtractSizeAlgorithm(readableStrategy)
    // (Using default for now)

    // Spec step 7: Let writableHighWaterMark be ? ExtractHighWaterMark(writableStrategy, 1)
    const writable_strategy = if (writableStrategy.was_passed) writableStrategy.value else dictionaries.QueuingStrategy{};
    const writable_hwm = extractHighWaterMark(&writable_strategy, 1.0) catch {
        allocator.destroy(internal);
        deinit(instance);
        return error.RangeError;
    };

    // Spec step 8: Let writableSizeAlgorithm be ! ExtractSizeAlgorithm(writableStrategy)
    // (Using default for now)

    // Spec step 9: Let startPromise be a new promise
    const start_promise = Promise(void).pending();

    // Spec step 10: Perform ! InitializeTransformStream(this, startPromise, writableHighWaterMark, writableSizeAlgorithm, readableHighWaterMark, readableSizeAlgorithm)
    try initializeTransformStream(instance, internal, allocator, ctx, start_promise, writable_hwm, readable_hwm);

    // Spec step 11: Perform ? SetUpTransformStreamDefaultControllerFromTransformer(this, transformer, transformerDict)
    const transformer_ptr = if (transformer.was_passed) transformer.value else null;
    if (transformer_ptr) |ptr| {
        try setUpTransformStreamDefaultControllerFromTransformer(instance, internal, allocator, ctx, ptr);
    }

    // Spec step 12-13: If transformerDict["start"] exists, resolve startPromise with result of invoking it
    // Otherwise, resolve startPromise with undefined
    // For now, we resolve immediately (no start callback)
    // The backpressureChangePromise was set by setBackpressure in initializeTransformStream

    return instance;
}

/// ExtractHighWaterMark helper
///
/// Spec: § 9.2.2 "ExtractHighWaterMark(strategy, defaultHWM)"
fn extractHighWaterMark(strategy: *const dictionaries.QueuingStrategy, default_hwm: f64) !f64 {
    if (strategy.highWaterMark) |hwm| {
        if (std.math.isNan(hwm) or hwm < 0) {
            return error.RangeError;
        }
        return hwm;
    }
    return default_hwm;
}

/// InitializeTransformStream
///
/// Spec: § 6.3.3 "InitializeTransformStream(stream, startPromise, writableHighWaterMark, writableSizeAlgorithm, readableHighWaterMark, readableSizeAlgorithm)"
fn initializeTransformStream(
    instance: *runtime.Instance,
    internal: *InternalState,
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    start_promise: Promise(void),
    writable_hwm: f64,
    readable_hwm: f64,
) !void {
    _ = start_promise; // Will be used for start algorithm

    // Spec step 1: Let startAlgorithm be an algorithm that returns startPromise
    // (Simplified: we'll use a resolved promise)

    // Spec step 2-4: Create write, abort, close algorithms that delegate to TransformStream
    // These are created inline when setting up the WritableStream

    // Spec step 5: Set stream.[[writable]] to ! CreateWritableStream(...)
    internal.writableStream = try createWritableStreamForTransform(instance, allocator, ctx, writable_hwm);
    _ = start_promise; // Start promise will be resolved after controller setup

    // Spec step 6-7: Create pull, cancel algorithms that delegate to TransformStream

    // Spec step 8: Set stream.[[readable]] to ! CreateReadableStream(...)
    internal.readableStream = try createReadableStreamForTransform(instance, allocator, ctx, readable_hwm);

    // Spec step 9: Set stream.[[backpressure]] and stream.[[backpressureChangePromise]] to undefined
    internal.backpressure = false; // Will be set properly by setBackpressure
    internal.backpressureChangePromise = null;

    // Spec step 10: Perform ! TransformStreamSetBackpressure(stream, true)
    // Note: setBackpressure asserts that backpressure != new value, so we need special handling for initialization
    // Set directly without assertion for initialization
    internal.backpressureChangePromise = Promise(void).pending();
    internal.backpressure = true;

    // Spec step 11: Set stream.[[controller]] to undefined
    // (Will be set by SetUpTransformStreamDefaultController)
    internal.controller = null;
}

/// Create a WritableStream for the TransformStream's writable side
///
/// Spec: § 6.3.3 step 5 - CreateWritableStream with transform sink algorithms
fn createWritableStreamForTransform(
    transform_stream: *runtime.Instance,
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    writable_hwm: f64,
) !*runtime.Instance {
    // Create WritableStream instance
    const writable = try interfaces.WritableStream.init(allocator, ctx);
    errdefer runtime.Instance.deinit(writable);

    const writable_state = writable.getState(interfaces.WritableStream.State);

    // Get event loop from context
    const loop = try ctx.getEventLoop();

    // Import WritableStream internal types
    const WritableStreamImpl = @import("WritableStream.zig");

    // Create internal state for WritableStream
    const writable_internal = try allocator.create(WritableStreamImpl.InternalState);
    errdefer allocator.destroy(writable_internal);

    writable_internal.* = WritableStreamImpl.InternalState{
        .controller = null, // Will be set by controller setup
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

    writable_state.own._internal = writable_internal;

    // Create WritableStreamDefaultController for this stream
    const controller = try interfaces.WritableStreamDefaultController.init(allocator, ctx);
    errdefer runtime.Instance.deinit(controller);

    const WritableControllerImpl = @import("WritableStreamDefaultController.zig");
    const controller_state = controller.getState(interfaces.WritableStreamDefaultController.State);

    // Create controller internal state
    const controller_internal = try allocator.create(WritableControllerImpl.InternalState);
    errdefer allocator.destroy(controller_internal);

    controller_internal.* = WritableControllerImpl.InternalState{
        .stream = writable,
        .write_algorithm = @ptrCast(transform_stream), // Store TransformStream for delegation
        .close_algorithm = @ptrCast(transform_stream),
        .abort_algorithm = @ptrCast(transform_stream),
        .start_algorithm = null, // TransformStream starts immediately, no deferred start
        .strategy_hwm = writable_hwm,
        .strategy_size_algorithm = null,
        .isolate = ctx.engine_ctx,
        .v8_context = null,
        .started = true, // TransformStream starts immediately
        .queue = .{
            .items = &.{},
            .capacity = 0,
        },
        .queue_total_size = 0.0,
        .abort_controller = null,
        .allocator = allocator,
    };

    controller_state.own._internal = controller_internal;
    writable_internal.controller = controller;

    return writable;
}

/// Create a ReadableStream for the TransformStream's readable side
///
/// Spec: § 6.3.3 step 8 - CreateReadableStream with transform source algorithms
fn createReadableStreamForTransform(
    transform_stream: *runtime.Instance,
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    readable_hwm: f64,
) !*runtime.Instance {
    // Create ReadableStream instance
    const readable = try interfaces.ReadableStream.init(allocator, ctx);
    errdefer runtime.Instance.deinit(readable);

    const readable_state = readable.getState(interfaces.ReadableStream.State);

    // Get event loop from context
    const loop = try ctx.getEventLoop();

    // Import ReadableStream internal types
    const ReadableStreamImpl = @import("ReadableStream.zig");

    // Create ReadableStreamDefaultController for this stream
    const controller = try interfaces.ReadableStreamDefaultController.init(allocator, ctx);
    errdefer runtime.Instance.deinit(controller);

    // Create internal state for ReadableStream
    const readable_internal = try allocator.create(ReadableStreamImpl.InternalState);
    errdefer allocator.destroy(readable_internal);

    readable_internal.* = ReadableStreamImpl.InternalState{
        .controller = controller,
        .reader = .none,
        .state = .readable,
        .stored_error = null,
        .detached = false,
        .disturbed = false,
        .event_loop = loop,
        .allocator = allocator,
    };

    readable_state.own._internal = readable_internal;

    // Set up controller with pull/cancel algorithms that delegate to TransformStream
    const ReadableControllerImpl = @import("ReadableStreamDefaultController.zig");
    const controller_state = controller.getState(interfaces.ReadableStreamDefaultController.State);

    // Create controller internal state
    const controller_internal = try allocator.create(ReadableControllerImpl.InternalState);
    errdefer allocator.destroy(controller_internal);

    const queue_mod = @import("streams_queue");
    controller_internal.* = ReadableControllerImpl.InternalState{
        .stream = readable,
        .queue = queue_mod.QueueWithSizes.init(allocator),
        .queue_total_size = 0.0,
        .started = true, // TransformStream starts immediately
        .close_requested = false,
        .pull_again = false,
        .pulling = false,
        .strategy_size_algorithm = null,
        .strategy_hwm = readable_hwm,
        .start_algorithm = null, // TransformStream handles start internally
        .pull_algorithm = null, // Will use transform's pull
        .cancel_algorithm = null, // Will use transform's cancel
        .allocator = allocator,
    };

    controller_state.own._internal = controller_internal;

    // Store transform stream reference for pull/cancel delegation
    // This is done through the controller's cancel algorithm context
    _ = transform_stream; // The algorithms will capture this

    return readable;
}

/// SetUpTransformStreamDefaultControllerFromTransformer
///
/// Spec: § 6.3.4 "SetUpTransformStreamDefaultControllerFromTransformer(stream, transformer, transformerDict)"
fn setUpTransformStreamDefaultControllerFromTransformer(
    instance: *runtime.Instance,
    internal: *InternalState,
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    transformer: *const anyopaque,
) !void {
    _ = transformer; // Will be used to extract transform/flush/cancel algorithms

    // Create TransformStreamDefaultController instance
    const controller = try interfaces.TransformStreamDefaultController.init(allocator, ctx);
    errdefer runtime.Instance.deinit(controller);

    const ControllerImpl = @import("TransformStreamDefaultController.zig");
    const controller_state = controller.getState(interfaces.TransformStreamDefaultController.State);

    // Create controller internal state
    const controller_internal = try allocator.create(ControllerImpl.InternalState);
    errdefer allocator.destroy(controller_internal);

    controller_internal.* = ControllerImpl.InternalState{
        .allocator = allocator,
        .stream = instance,
        .transformAlgorithm = streams_common.defaultTransformAlgorithm(),
        .flushAlgorithm = streams_common.defaultFlushAlgorithm(),
        .cancelAlgorithm = streams_common.defaultCancelAlgorithm(),
        .finishPromise = null,
        .isolate = ctx.engine_ctx,
        .v8_context = null,
    };

    controller_state.own._internal = controller_internal;

    // Spec step 4: Set stream.[[controller]] to controller
    internal.controller = controller;
}

/// Getter for readable
pub fn get_readable(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.readableStream orelse error.InvalidState;
}

/// Getter for writable
pub fn get_writable(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.writableStream orelse error.InvalidState;
}

// ============================================================================
// Internal Helper Methods
// ============================================================================

/// TransformStreamError(stream, e)
///
/// Spec: § 6.3.1 "Error both sides of the transform stream"
pub fn errorStream(instance: *runtime.Instance, e: JSValue) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;

    // Spec step 1: Perform ! ReadableStreamDefaultControllerError(stream.[[readable]].[[controller]], e)
    if (internal.readableStream) |readable| {
        const readable_state = readable.getState(@import("interfaces").ReadableStream.State);
        if (readable_state.own._internal) |readable_internal| {
            const ReadableStreamImpl = @import("ReadableStream.zig");
            // Convert JSValue to anyopaque for ReadableStream API
            const error_ptr: *const anyopaque = @ptrCast(&e);
            ReadableStreamImpl.readableStreamError(readable_internal, error_ptr);
        }
    }

    // Spec step 2: Perform ! TransformStreamErrorWritableAndUnblockWrite(stream, e)
    errorWritableAndUnblockWrite(instance, e);
}

/// TransformStreamErrorWritableAndUnblockWrite(stream, e)
///
/// Spec: § 6.3.1 "Error writable side and unblock write"
pub fn errorWritableAndUnblockWrite(instance: *runtime.Instance, e: JSValue) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;

    // Spec step 1: Perform ! TransformStreamDefaultControllerClearAlgorithms(stream.[[controller]])
    if (internal.controller) |controller| {
        const ControllerImpl = @import("TransformStreamDefaultController.zig");
        ControllerImpl.clearAlgorithms(controller);
    }

    // Spec step 2: Perform ! WritableStreamDefaultControllerErrorIfNeeded(stream.[[writable]].[[controller]], e)
    if (internal.writableStream) |writable| {
        const WritableStreamImpl = @import("WritableStream.zig");
        // Convert JSValue to anyopaque for WritableStream API
        const error_ptr: *const anyopaque = @ptrCast(&e);
        WritableStreamImpl.writableStreamStartErroring(writable, error_ptr);
    }

    // Spec step 3: Perform ! TransformStreamUnblockWrite(stream)
    unblockWrite(instance);
}

/// TransformStreamSetBackpressure(stream, backpressure)
///
/// Spec: § 6.3.1 "Set backpressure signal"
pub fn setBackpressure(instance: *runtime.Instance, backpressure: bool) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;

    // Spec step 1: Assert: stream.[[backpressure]] is not backpressure
    std.debug.assert(internal.backpressure != backpressure);

    // Spec step 2: If stream.[[backpressureChangePromise]] is not undefined,
    //              resolve stream.[[backpressureChangePromise]] with undefined
    if (internal.backpressureChangePromise) |*promise| {
        if (promise.isPending()) {
            promise.fulfill({});
        }
    }

    // Spec step 3: Set stream.[[backpressureChangePromise]] to a new promise
    internal.backpressureChangePromise = Promise(void).pending();

    // Spec step 4: Set stream.[[backpressure]] to backpressure
    internal.backpressure = backpressure;
}

/// TransformStreamUnblockWrite(stream)
///
/// Spec: § 6.3.1 "Unblock write if backpressure is true"
pub fn unblockWrite(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;

    // Spec step 1: If stream.[[backpressure]] is true, perform ! TransformStreamSetBackpressure(stream, false)
    if (internal.backpressure) {
        setBackpressure(instance, false);
    }
}

// ============================================================================
// Default Sink Algorithms (Writable Side)
// ============================================================================

/// TransformStreamDefaultSinkWriteAlgorithm(stream, chunk)
///
/// Spec: § 6.3.4 "Default sink write algorithm"
///
/// Spec Algorithm:
/// 1. Assert: stream.[[writable]].[[state]] is "writable".
/// 2. Let controller be stream.[[controller]].
/// 3. If stream.[[backpressure]] is true,
///    3.1 Let backpressureChangePromise be stream.[[backpressureChangePromise]].
///    3.2 Assert: backpressureChangePromise is not undefined.
///    3.3 Return the result of reacting to backpressureChangePromise with the following
///        fulfillment steps:
///        - Return ! TransformStreamDefaultControllerPerformTransform(controller, chunk).
/// 4. Return ! TransformStreamDefaultControllerPerformTransform(controller, chunk).
pub fn defaultSinkWriteAlgorithm(instance: *runtime.Instance, chunk: JSValue) Promise(void) {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return Promise(void).rejected(webidl.errors.Exception.typeError(std.heap.page_allocator, "Invalid stream state") catch unreachable);

    // Spec step 2: Let controller be stream.[[controller]]
    const controller = internal.controller orelse return Promise(void).rejected(webidl.errors.Exception.typeError(std.heap.page_allocator, "Controller not initialized") catch unreachable);

    // Spec step 3: If stream.[[backpressure]] is true
    if (internal.backpressure) {
        // Spec step 3.1: Let backpressureChangePromise be stream.[[backpressureChangePromise]]
        if (internal.backpressureChangePromise) |*backpressure_promise| {
            // Spec step 3.2: Assert: backpressureChangePromise is not undefined (checked above)

            // Spec step 3.3: Return the result of reacting to backpressureChangePromise
            // with fulfillment steps that perform the transform.
            //
            // Implementation note: Since we're using synchronous Promise semantics,
            // we need to handle this differently. If backpressure is applied and the
            // promise is pending, we should return a pending promise that will eventually
            // resolve when backpressure is released.
            //
            // For the simplified implementation:
            // - If the promise is already fulfilled (backpressure was released), proceed with transform
            // - If the promise is pending, return a pending promise (write will be queued)
            if (backpressure_promise.isPending()) {
                // Return a pending promise - the write will be retried when backpressure releases
                // In a full async implementation, this would chain to the transform
                return Promise(void).pending();
            }
            // Backpressure was released, fall through to perform transform
        }
    }

    // Spec step 4: Return ! TransformStreamDefaultControllerPerformTransform(controller, chunk)
    const ControllerImpl = @import("TransformStreamDefaultController.zig");
    return ControllerImpl.performTransform(controller, chunk);
}

/// TransformStreamDefaultSinkAbortAlgorithm(stream, reason)
///
/// Spec: § 6.3.4 "Default sink abort algorithm"
pub fn defaultSinkAbortAlgorithm(instance: *runtime.Instance, reason: JSValue) Promise(void) {
    // Spec step 1: Perform ! TransformStreamError(stream, reason)
    errorStream(instance, reason);

    // Spec step 2: Return a promise resolved with undefined
    return Promise(void).fulfilled({});
}

/// TransformStreamDefaultSinkCloseAlgorithm(stream)
///
/// Spec: § 6.3.4 "Default sink close algorithm"
///
/// Spec Algorithm:
/// 1. Let readable be stream.[[readable]].
/// 2. Let controller be stream.[[controller]].
/// 3. Let flushPromise be the result of performing controller.[[flushAlgorithm]].
/// 4. Perform ! TransformStreamDefaultControllerClearAlgorithms(controller).
/// 5. Return the result of reacting to flushPromise:
///    - If flushPromise was fulfilled:
///      1. If readable.[[state]] is "errored", throw readable.[[storedError]].
///      2. Perform ! ReadableStreamDefaultControllerClose(readable.[[controller]]).
///    - If flushPromise was rejected with reason r:
///      1. Perform ! TransformStreamError(stream, r).
///      2. Throw readable.[[storedError]].
pub fn defaultSinkCloseAlgorithm(instance: *runtime.Instance) Promise(void) {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return Promise(void).rejected(webidl.errors.Exception.typeError(std.heap.page_allocator, "Invalid stream state") catch unreachable);

    // Spec step 1: Let readable be stream.[[readable]]
    const readable = internal.readableStream orelse return Promise(void).rejected(webidl.errors.Exception.typeError(std.heap.page_allocator, "Readable stream not initialized") catch unreachable);

    // Spec step 2: Let controller be stream.[[controller]]
    const controller = internal.controller orelse return Promise(void).rejected(webidl.errors.Exception.typeError(std.heap.page_allocator, "Controller not initialized") catch unreachable);

    // Spec step 3: Let flushPromise be the result of performing controller.[[flushAlgorithm]]
    const ControllerImpl = @import("TransformStreamDefaultController.zig");
    const controller_state = controller.getState(interfaces.TransformStreamDefaultController.State);

    var flush_promise = Promise(void).fulfilled({});
    if (controller_state.own._internal) |controller_internal| {
        // Invoke the flush algorithm
        flush_promise = controller_internal.flushAlgorithm.call();
    }

    // Spec step 4: Perform ! TransformStreamDefaultControllerClearAlgorithms(controller)
    ControllerImpl.clearAlgorithms(controller);

    // Spec step 5: Return the result of reacting to flushPromise
    if (flush_promise.isRejected()) {
        // Spec step 5 rejection: TransformStreamError(stream, r) and throw
        const error_value = JSValue{ .string = "Flush algorithm failed" };
        errorStream(instance, error_value);

        // Return the rejection
        if (flush_promise.error_value) |err| {
            return Promise(void).rejected(err);
        }
        return Promise(void).rejected(webidl.errors.Exception.typeError(std.heap.page_allocator, "Flush failed") catch unreachable);
    }

    // Spec step 5 fulfillment: Check readable state and close
    const ReadableStreamImpl = @import("ReadableStream.zig");
    const readable_state = readable.getState(interfaces.ReadableStream.State);

    if (readable_state.own._internal) |readable_internal| {
        // Spec step 5.1: If readable.[[state]] is "errored", throw readable.[[storedError]]
        if (readable_internal.state == .errored) {
            return Promise(void).rejected(webidl.errors.Exception.typeError(std.heap.page_allocator, "Readable stream is errored") catch unreachable);
        }

        // Spec step 5.2: Perform ! ReadableStreamDefaultControllerClose(readable.[[controller]])
        ReadableStreamImpl.closeInternal(readable);
    }

    return Promise(void).fulfilled({});
}

// ============================================================================
// Default Source Algorithms (Readable Side)
// ============================================================================

/// TransformStreamDefaultSourcePullAlgorithm(stream)
///
/// Spec: § 6.3.5 "Default source pull algorithm"
pub fn defaultSourcePullAlgorithm(instance: *runtime.Instance) Promise(void) {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return Promise(void).rejected(webidl.errors.Exception.typeError(std.heap.page_allocator, "Invalid stream state") catch unreachable);

    // Spec step 1: Assert: stream.[[backpressure]] is true
    std.debug.assert(internal.backpressure);

    // Spec step 2: Assert: stream.[[backpressureChangePromise]] is not undefined
    // Spec step 3: Perform ! TransformStreamSetBackpressure(stream, false)
    setBackpressure(instance, false);

    // Spec step 4: Return stream.[[backpressureChangePromise]]
    if (internal.backpressureChangePromise) |promise| {
        return promise;
    }

    return Promise(void).fulfilled({});
}

/// TransformStreamDefaultSourceCancelAlgorithm(stream, reason)
///
/// Spec: § 6.3.5 "Default source cancel algorithm"
pub fn defaultSourceCancelAlgorithm(instance: *runtime.Instance, reason: JSValue) Promise(void) {
    // Spec step 1: Perform ! TransformStreamError(stream, reason)
    errorStream(instance, reason);

    // Spec step 2: Return a promise resolved with undefined
    return Promise(void).fulfilled({});
}
