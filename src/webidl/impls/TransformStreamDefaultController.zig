//! Implementation for TransformStreamDefaultController interface
//!
//! Spec: https://streams.spec.whatwg.org/#ts-default-controller-class
//!
//! Controls a TransformStream's state and transformation.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const TransformStreamDefaultController = interfaces.TransformStreamDefaultController;
const v8_engine = @import("v8");

// Import streams infrastructure (via build system modules)
const streams_common = @import("streams_common");
const JSValue = streams_common.JSValue;
const Promise = streams_common.Promise;
const TransformAlgorithm = streams_common.TransformAlgorithm;
const FlushAlgorithm = streams_common.FlushAlgorithm;
const CancelAlgorithm = streams_common.CancelAlgorithm;

pub const State = TransformStreamDefaultController.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    OutOfMemory,
    InvalidState,
    RangeError, // From ReadableStreamDefaultController.call_close
};

/// Internal state for TransformStreamDefaultController
///
/// Spec: § 6.2.2 "Internal slots"
///
/// ## V8 Handle Lifetime
///
/// JavaScript callbacks (transform, flush, cancel) are stored as V8 Global handles
/// to survive HandleScope destruction. When JavaScript code creates a TransformStream
/// with callback functions, the callbacks are extracted as Local<Value> handles.
/// Without Global handles, these become dangling pointers when the constructor's
/// HandleScope ends.
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// [[stream]]: The TransformStream instance controlled
    stream: ?*runtime.Instance,

    /// [[transformAlgorithm]]: Algorithm to transform chunks
    /// Spec: § 6.2.2 Internal slots
    transformAlgorithm: TransformAlgorithm,

    /// [[flushAlgorithm]]: Algorithm to flush remaining data
    /// Spec: § 6.2.2 Internal slots
    flushAlgorithm: FlushAlgorithm,

    /// [[cancelAlgorithm]]: Algorithm to handle cancellation
    /// Spec: § 6.2.2 Internal slots
    cancelAlgorithm: CancelAlgorithm,

    /// [[finishPromise]]: Promise that resolves on completion of flush or cancel
    /// Spec: § 6.2.2 Internal slots
    finishPromise: ?Promise(void),

    /// V8 isolate for callback invocation
    isolate: ?*v8_engine.ffi.Isolate,

    /// V8 context for callback invocation
    v8_context: ?*anyopaque,

    /// V8 Global handle for flush algorithm callback
    /// When set, this takes precedence over flushAlgorithm for V8 runtime mode.
    flush_algorithm_v8: v8_engine.OptionalGlobalHandle,

    /// V8 Global handle for transform algorithm callback
    transform_algorithm_v8: v8_engine.OptionalGlobalHandle,

    /// V8 Global handle for cancel algorithm callback
    cancel_algorithm_v8: v8_engine.OptionalGlobalHandle,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        // Dispose V8 Global handles to prevent memory leaks
        v8_engine.disposeOptionalGlobalHandle(&self.flush_algorithm_v8);
        v8_engine.disposeOptionalGlobalHandle(&self.transform_algorithm_v8);
        v8_engine.disposeOptionalGlobalHandle(&self.cancel_algorithm_v8);

        // Clean up algorithms
        self.transformAlgorithm.deinit();
        self.flushAlgorithm.deinit();
        self.cancelAlgorithm.deinit();
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
    // InternalState is set up by SetUpTransformStreamDefaultController
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

// ============================================================================
// WebIDL Interface Methods
// ============================================================================

/// Getter for desiredSize
///
/// Spec: § 6.2.3 "The desiredSize getter steps"
pub fn get_desiredSize(instance: *runtime.Instance) anyerror!?f64 {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Spec step 1: Let readableController be this.[[stream]].[[readable]].[[controller]]
    const stream_instance = internal.stream orelse return error.InvalidState;

    // Get TransformStream from instance
    const transform_state = stream_instance.getState(interfaces.TransformStream.State);
    const transform_internal = transform_state.own._internal orelse return error.InvalidState;

    // Get readable stream's controller
    const readable_instance = transform_internal.readableStream orelse return error.InvalidState;
    const readable_state = readable_instance.getState(interfaces.ReadableStream.State);
    const readable_internal = readable_state.own._internal orelse return error.InvalidState;

    // Get the controller from readable stream
    const readable_controller = readable_internal.controller;

    // Spec step 2: Return ! ReadableStreamDefaultControllerGetDesiredSize(readableController)
    // Use interface per Golden Rule #13
    return interfaces.ReadableStreamDefaultController.get_desiredSize(readable_controller) catch 0.0;
}

/// Operation: error
///
/// Spec: § 6.2.3 "The error(e) method steps"
pub fn call_error(instance: *runtime.Instance, reason: webidl.Opt(runtime.JSValue)) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Convert reason to JSValue
    // Note: reason is *anyopaque which could be a V8 Value or other error object.
    // For now, we create a simple error message. Full V8 integration would
    // use v8 conversions to extract the actual error value.
    _ = reason;
    const error_value = JSValue.createError("Transform error");

    // Spec step 1: Perform ? TransformStreamDefaultControllerError(this, e)
    errorInternal(internal, error_value);
}

/// Operation: terminate
///
/// Spec: § 6.2.3 "The terminate() method steps"
pub fn call_terminate(instance: *runtime.Instance) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Spec step 1: Perform ? TransformStreamDefaultControllerTerminate(this)
    try terminateInternal(internal);
}

/// Operation: enqueue
///
/// Spec: § 6.2.3 "The enqueue(chunk) method steps"
pub fn call_enqueue(instance: *runtime.Instance, chunk: webidl.Opt(runtime.JSValue)) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Convert chunk to JSValue
    // Note: chunk is *anyopaque which could be a V8 Value or other object.
    // For now, we wrap it as undefined. Full V8 integration would extract
    // the actual value using v8 conversions.
    _ = chunk;
    const chunk_value = JSValue.undefined_value();

    // Spec step 1: Perform ? TransformStreamDefaultControllerEnqueue(this, chunk)
    try enqueueInternal(internal, chunk_value);
}

// ============================================================================
// Internal Algorithms
// ============================================================================

/// TransformStreamDefaultControllerEnqueue(controller, chunk)
///
/// Spec: § 6.3.2 "Enqueue chunk to readable side"
fn enqueueInternal(internal: *InternalState, chunk: JSValue) !void {
    // Spec step 1: Let stream be controller.[[stream]]
    const stream_instance = internal.stream orelse return error.TypeError;

    const transform_state = stream_instance.getState(interfaces.TransformStream.State);
    const transform_internal = transform_state.own._internal orelse return error.TypeError;

    // Spec step 2: Let readableController be stream.[[readable]].[[controller]]
    const readable_instance = transform_internal.readableStream orelse return error.TypeError;
    const readable_state = readable_instance.getState(interfaces.ReadableStream.State);
    const readable_internal = readable_state.own._internal orelse return error.TypeError;

    // Get the controller
    const controller_instance = readable_internal.controller;
    const controller_state = controller_instance.getState(interfaces.ReadableStreamDefaultController.State);
    const controller_internal = controller_state.own._internal orelse return error.TypeError;

    const ReadableStreamDefaultControllerImpl = @import("ReadableStreamDefaultController.zig");

    // Spec step 3: If ! ReadableStreamDefaultControllerCanCloseOrEnqueue(readableController) is false, throw TypeError
    if (!ReadableStreamDefaultControllerImpl.canCloseOrEnqueue(controller_internal)) {
        return error.TypeError;
    }

    // Spec step 4: Let enqueueResult be ReadableStreamDefaultControllerEnqueue(readableController, chunk)
    // Convert JSValue to anyopaque for ReadableStreamDefaultController API
    // Use interface per Golden Rule #13
    const chunk_ptr: *const anyopaque = @ptrCast(&chunk);
    interfaces.ReadableStreamDefaultController.call_enqueue(controller_instance, webidl.Opt(*const anyopaque).passed(chunk_ptr)) catch |err| {
        // Spec step 5: If enqueueResult is an abrupt completion
        // Spec step 5.1: Perform ! TransformStreamErrorWritableAndUnblockWrite(stream, enqueueResult.[[Value]])
        const error_value = JSValue{ .string = "Enqueue failed" };
        const TransformStreamImpl = @import("TransformStream.zig");
        TransformStreamImpl.errorWritableAndUnblockWrite(stream_instance, error_value);
        // Spec step 5.2: Throw stream.[[readable]].[[storedError]]
        return err;
    };

    // Spec step 6: Let backpressure be ! ReadableStreamDefaultControllerHasBackpressure(readableController)
    const backpressure = ReadableStreamDefaultControllerImpl.hasBackpressure(controller_instance);

    // Spec step 7: If backpressure is not stream.[[backpressure]]
    if (backpressure != transform_internal.backpressure) {
        // Spec step 7.1: Assert: backpressure is true
        std.debug.assert(backpressure);
        // Spec step 7.2: Perform ! TransformStreamSetBackpressure(stream, true)
        const TransformStreamImpl = @import("TransformStream.zig");
        TransformStreamImpl.setBackpressure(stream_instance, true);
    }
}

/// TransformStreamDefaultControllerError(controller, e)
///
/// Spec: § 6.3.2 "Error both sides of transform stream"
fn errorInternal(internal: *InternalState, error_value: JSValue) void {
    // Spec step 1: Perform ! TransformStreamError(controller.[[stream]], e)
    const stream_instance = internal.stream orelse return;
    const TransformStreamImpl = @import("TransformStream.zig");
    TransformStreamImpl.errorStream(stream_instance, error_value);
}

/// TransformStreamDefaultControllerTerminate(controller)
///
/// Spec: § 6.3.2 "Terminate the transform stream"
fn terminateInternal(internal: *InternalState) !void {
    // Spec step 1: Let stream be controller.[[stream]]
    const stream_instance = internal.stream orelse return error.TypeError;

    const transform_state = stream_instance.getState(interfaces.TransformStream.State);
    const transform_internal = transform_state.own._internal orelse return error.TypeError;

    // Spec step 2: Let readableController be stream.[[readable]].[[controller]]
    const readable_instance = transform_internal.readableStream orelse return error.TypeError;
    const readable_state = readable_instance.getState(interfaces.ReadableStream.State);
    const readable_internal = readable_state.own._internal orelse return error.TypeError;

    // Get the controller
    const controller_instance = readable_internal.controller;

    // Spec step 3: Perform ! ReadableStreamDefaultControllerClose(readableController)
    // Use interface per Golden Rule #13
    try interfaces.ReadableStreamDefaultController.call_close(controller_instance);

    // Spec step 4: Let error be a TypeError exception indicating that the stream has been terminated
    const error_value = JSValue{ .string = "Stream has been terminated" };

    // Spec step 5: Perform ! TransformStreamErrorWritableAndUnblockWrite(stream, error)
    const TransformStreamImpl = @import("TransformStream.zig");
    TransformStreamImpl.errorWritableAndUnblockWrite(stream_instance, error_value);
}

/// Clear algorithms to allow garbage collection
///
/// Spec: § 6.3.2 TransformStreamDefaultControllerClearAlgorithms
pub fn clearAlgorithms(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;

    internal.transformAlgorithm.deinit();
    internal.flushAlgorithm.deinit();
    internal.cancelAlgorithm.deinit();

    // Replace with no-op algorithms
    internal.transformAlgorithm = defaultTransformAlgorithm();
    internal.flushAlgorithm = defaultFlushAlgorithm();
    internal.cancelAlgorithm = defaultCancelAlgorithm();
}

/// TransformStreamDefaultControllerPerformTransform(controller, chunk)
///
/// Spec: § 6.3.2 "Perform transform with error handling"
pub fn performTransform(instance: *runtime.Instance, chunk: JSValue) Promise(void) {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return Promise(void).rejected(webidl.errors.Exception.typeError(std.heap.page_allocator, "Invalid controller state") catch unreachable);

    // Spec step 1: Let transformPromise be the result of performing controller.[[transformAlgorithm]], passing chunk
    const transform_promise = internal.transformAlgorithm.call(chunk);

    // Spec step 2: Return the result of reacting to transformPromise with rejection steps
    // For now, we return the promise directly (simplified)
    // Full implementation would add rejection handler that calls TransformStreamError

    // If the transform promise is rejected, error the stream
    if (transform_promise.isRejected()) {
        const stream_instance = internal.stream orelse return transform_promise;
        const error_value = JSValue{ .string = "Transform failed" };
        const TransformStreamImpl = @import("TransformStream.zig");
        TransformStreamImpl.errorStream(stream_instance, error_value);
    }

    return transform_promise;
}

// ============================================================================
// Default Algorithms
// ============================================================================

/// Default transform algorithm (identity transform)
fn defaultTransformAlgorithm() TransformAlgorithm {
    const vtable = struct {
        fn call(_: *anyopaque, _: JSValue) Promise(void) {
            return Promise(void).fulfilled({});
        }
        fn deinitFn(_: *anyopaque) void {}
    };

    // Use a static dummy pointer since we don't need context
    const static = struct {
        var dummy: u8 = 0;
    };

    return TransformAlgorithm{
        .ptr = &static.dummy,
        .vtable = &.{
            .call = vtable.call,
            .deinit = vtable.deinitFn,
        },
    };
}

/// Default flush algorithm (no-op)
fn defaultFlushAlgorithm() FlushAlgorithm {
    const vtable = struct {
        fn call(_: *anyopaque) Promise(void) {
            return Promise(void).fulfilled({});
        }
        fn deinitFn(_: *anyopaque) void {}
    };

    const static = struct {
        var dummy: u8 = 0;
    };

    return FlushAlgorithm{
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
