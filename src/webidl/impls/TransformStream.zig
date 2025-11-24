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
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, transformer: *const anyopaque, writableStrategy: dictionaries.QueuingStrategy, readableStrategy: dictionaries.QueuingStrategy) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &TransformStream.vtable, ctx);
    errdefer deinit(instance);

    _ = transformer;
    _ = writableStrategy;
    _ = readableStrategy;

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
        .isolate = ctx.engine_ctx, // Set directly from context
        .v8_context = null, // Will be set when stream is configured
    };

    state.own._internal = internal;

    // TODO: Implement full constructor logic:
    // 1. Parse transformer dictionary
    // 2. Create ReadableStream and WritableStream
    // 3. Create TransformStreamDefaultController
    // 4. Wire up transform algorithms
    // 5. Invoke start callback if provided

    return instance;
}

/// Getter for readable
pub fn get_readable(instance: *runtime.Instance) ImplError!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return internal.readableStream orelse error.InvalidState;
}

/// Getter for writable
pub fn get_writable(instance: *runtime.Instance) ImplError!*runtime.Instance {
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
        const ReadableStreamImpl = @import("ReadableStream.zig");
        ReadableStreamImpl.errorInternal(readable, e);
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
        WritableStreamImpl.errorInternal(writable, e);
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
pub fn defaultSinkWriteAlgorithm(instance: *runtime.Instance, chunk: JSValue) Promise(void) {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return Promise(void).rejected(webidl.errors.Exception.typeError(std.heap.page_allocator, "Invalid stream state") catch unreachable);

    // Spec step 2: Let controller be stream.[[controller]]
    const controller = internal.controller orelse return Promise(void).rejected(webidl.errors.Exception.typeError(std.heap.page_allocator, "Controller not initialized") catch unreachable);

    // Spec step 3: If stream.[[backpressure]] is true
    if (internal.backpressure) {
        // Spec step 3.1: Let backpressureChangePromise be stream.[[backpressureChangePromise]]
        // Spec step 3.2: Assert: backpressureChangePromise is not undefined
        // Spec step 3.3: Return the result of reacting to backpressureChangePromise with...
        // For now, simplified: wait for backpressure to release
        // TODO: Implement proper Promise chaining when backpressure changes
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
pub fn defaultSinkCloseAlgorithm(instance: *runtime.Instance) Promise(void) {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return Promise(void).rejected(webidl.errors.Exception.typeError(std.heap.page_allocator, "Invalid stream state") catch unreachable);

    // Spec step 1: Let readable be stream.[[readable]]
    const readable = internal.readableStream orelse return Promise(void).rejected(webidl.errors.Exception.typeError(std.heap.page_allocator, "Readable stream not initialized") catch unreachable);

    // Spec step 2: Let controller be stream.[[controller]]
    const controller = internal.controller orelse return Promise(void).rejected(webidl.errors.Exception.typeError(std.heap.page_allocator, "Controller not initialized") catch unreachable);

    // Spec step 3: Let flushPromise be the result of performing controller.[[flushAlgorithm]]
    // For now, simplified implementation
    // TODO: Invoke flush algorithm from controller

    // Spec step 4: Perform ! TransformStreamDefaultControllerClearAlgorithms(controller)
    const ControllerImpl = @import("TransformStreamDefaultController.zig");
    ControllerImpl.clearAlgorithms(controller);

    // Spec step 5: Return the result of reacting to flushPromise...
    // For now, just close the readable side
    const ReadableStreamImpl = @import("ReadableStream.zig");
    ReadableStreamImpl.closeInternal(readable);

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
