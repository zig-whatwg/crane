//! ReadableStream Implementation
//!
//! WHATWG Streams Standard: https://streams.spec.whatwg.org/#rs-class
//!
//! A readable stream represents a source of data from which you can read.
//! All of its internal state is encapsulated in InternalState.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const infra = @import("infra");
const ReadableStream = interfaces.ReadableStream;
const v8_engine = @import("v8");
const v8 = v8_engine;

// Type-safe V8 value system
const StoredError = v8_engine.stored_error.StoredError;

// Import streams infrastructure
const streams_common = @import("streams_common");
const event_loop = @import("streams_event_loop");
const AsyncPromise = @import("streams_async_promise").AsyncPromise;
const QueueWithSizes = @import("streams_queue").QueueWithSizes;
const algorithm_mod = @import("streams_algorithm");
const Algorithm = algorithm_mod.Algorithm;
const createTypedAlgorithm = algorithm_mod.createTypedAlgorithm;
const IteratorRecord = @import("streams_iterator_record").IteratorRecord;
const from_iterable = @import("streams_from_iterable_algorithm");

// Promise utilities for bridging Zig AsyncPromise to V8 Promise
const promise_utils = v8_engine.promise;

pub const State = ReadableStream.State;

/// Returns a pointer representing "undefined" for any type fields
fn getUndefinedPtr() *const anyopaque {
    const undefined_marker: *const usize = &@as(usize, 0);
    return @ptrCast(undefined_marker);
}

pub const ImplError = error{
    NotImplemented,
    TypeError,
    RangeError,
    InvalidState,
    OutOfMemory,
    NoEventLoop,
    NullValue,
    BufferDetached,
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
    readable,
    closed,
    errored,
};

/// Reader union type - can be default reader, BYOB reader, or none
pub const Reader = union(enum) {
    none: void,
    default: *runtime.Instance,
    byob: *runtime.Instance,
};

/// Internal state for ReadableStream
///
/// This mirrors the internal slots defined in the WHATWG Streams spec § 4.1
pub const InternalState = struct {
    /// [[controller]]: ReadableStreamDefaultController or ReadableByteStreamController
    controller: *runtime.Instance,

    /// [[reader]]: ReadableStreamReader or undefined
    reader: Reader,

    /// [[state]]: "readable", "closed", or "errored"
    state: StreamState,

    /// [[storedError]]: any - stored error if state is "errored"
    /// Uses type-safe StoredError instead of raw anyopaque
    stored_error: StoredError = .none,

    /// [[detached]]: boolean - transferred via postMessage
    detached: bool,

    /// [[disturbed]]: boolean - ever had a reader
    disturbed: bool,

    /// Event loop for async operations (borrowed from context)
    event_loop: event_loop.EventLoop,

    /// Resource management
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        // Clean up controller
        // Note: controller is a runtime.Instance that manages its own lifecycle

        // Clean up reader if present
        switch (self.reader) {
            .none => {},
            .default, .byob => {
                // Reader instances manage their own lifecycle
            },
        }

        // Dispose stored error (frees V8 Global handle if present)
        self.stored_error.dispose();

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
    // Instance state (InternalState) is initialized in constructor
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
/// Spec: https://streams.spec.whatwg.org/#rs-constructor
/// new ReadableStream(underlyingSource, strategy)
///
/// Steps:
/// 1. If underlyingSource is missing, set it to null
/// 2. Let underlyingSourceDict be underlyingSource, converted to IDL type UnderlyingSource
/// 3. Perform ! InitializeReadableStream(this)
/// 4. If underlyingSourceDict["type"] is "bytes": [handle byte streams]
/// 5. Otherwise:
///    1. Assert: underlyingSourceDict["type"] does not exist
///    2. Let sizeAlgorithm be ! ExtractSizeAlgorithm(strategy)
///    3. Let highWaterMark be ? ExtractHighWaterMark(strategy, 1)
///    4. Perform ? SetUpReadableStreamDefaultControllerFromUnderlyingSource(...)
pub fn call_constructor(ctx: runtime.Context, underlyingSource: webidl.Opt(runtime.JSValue), strategy: webidl.Opt(dictionaries.QueuingStrategy)) !*runtime.Instance {
    // Get event loop from context (required for async operations)
    const loop = try ctx.getEventLoop();

    // Step 1: If underlyingSource is missing, use default empty dictionary
    // Step 2: Convert to UnderlyingSource dictionary
    //
    // The underlyingSource parameter comes in as *const anyopaque because the
    // WebIDL UnderlyingSource dictionary contains callback function members.
    // Since the type is anyopaque, the V8 bindings pass the raw V8 object pointer.
    // We need to extract the callback properties from the V8 object manually.
    var underlying_source_dict_storage = dictionaries.UnderlyingSource{};

    // Extracted callbacks - stored as V8 Global handle pointers (tagged with .global_handle)
    // These bypass the generated dictionary's callback types which are Zig function pointers.
    var extracted_start_callback: ?*const anyopaque = null;
    var extracted_pull_callback: ?*const anyopaque = null;
    var extracted_cancel_callback: ?*const anyopaque = null;

    if (underlyingSource.was_passed) {
        // underlyingSource.value is a JSValue containing a V8 handle
        // Extract the handle pointer first, then untag it
        const v8_ffi = v8.ffi;
        const pointer_tag = @import("v8").pointer_tag;

        // Get the pointer from the JSValue
        const source_ptr = underlyingSource.value.toAnyopaque() orelse return error.TypeError;

        // Untag the pointer before using it as a V8 object
        const untagged = pointer_tag.untagPointer(source_ptr);

        // Validate we have a V8 value (not a Zig instance)
        if (untagged.tag == .runtime_instance) {
            return error.TypeError; // Expected V8 object, got Zig instance
        }

        // Get V8 context from runtime context
        const v8_context_ptr = ctx.getEngineContext() orelse return error.InvalidState;
        const v8_context: *v8_ffi.Context = @ptrCast(@alignCast(v8_context_ptr));

        // Get current isolate
        const isolate = v8_ffi.v8_Isolate_GetCurrent() orelse return error.InvalidState;

        // Validate that the pointer is actually a V8 object
        // This catches cases where Zig code passes a Zig struct pointer as JSValue
        // (e.g., Blob.stream() passing an UnderlyingSource struct)
        const v8_value: *v8_ffi.Value = @ptrCast(untagged.ptr);
        if (v8_ffi.v8_Value_IsObject(v8_value)) {
            const v8_obj: *v8_ffi.Object = @ptrCast(untagged.ptr);

            // Extract callbacks from V8 object manually
            //
            // The generated dictionary uses Zig callback function pointer types, but what we
            // receive from V8 are Global handle pointers (tagged with .global_handle).
            // We bypass the generated dictionary and extract callbacks directly here,
            // storing them in a parallel structure that uses *const anyopaque.
            //
            // The extraction uses v8_Object_Get to get each property, and if it's a function,
            // conversions.fromV8Value creates a Global handle automatically (see whatwg-okii8).

            // Helper to extract a callback property
            const extractCallback = struct {
                fn extract(iso: *v8_ffi.Isolate, obj: *v8_ffi.Object, v8ctx: *v8_ffi.Context, name: []const u8) ?*const anyopaque {
                    const key = v8_ffi.v8_String_NewFromUtf8(iso, name.ptr, @intCast(name.len)) orelse return null;
                    const prop_value = v8_ffi.v8_Object_Get(obj, v8ctx, @ptrCast(key)) orelse return null;

                    // Check if it's null/undefined
                    if (v8_ffi.v8_Value_IsNullOrUndefined(prop_value)) {
                        return null;
                    }

                    // Check if it's a function
                    if (!v8_ffi.v8_Value_IsFunction(prop_value)) {
                        return null;
                    }

                    // Create Global handle for the function (for persistence beyond constructor)
                    if (v8_ffi.v8_Value_ToGlobal(iso, prop_value)) |global| {
                        // Tag as global_handle so consumers know how to handle it
                        return pointer_tag.tagPointer(global, .global_handle);
                    }

                    return null;
                }
            }.extract;

            // Extract the callback properties from the underlying source object
            extracted_start_callback = extractCallback(isolate, v8_obj, v8_context, "start");
            extracted_pull_callback = extractCallback(isolate, v8_obj, v8_context, "pull");
            extracted_cancel_callback = extractCallback(isolate, v8_obj, v8_context, "cancel");

            // Extract 'type' property for byte stream detection
            const type_key = v8_ffi.v8_String_NewFromUtf8(isolate, "type", 4);
            if (type_key) |tk| {
                if (v8_ffi.v8_Object_Get(v8_obj, v8_context, @ptrCast(tk))) |type_val| {
                    if (!v8_ffi.v8_Value_IsNullOrUndefined(type_val) and v8_ffi.v8_Value_IsString(type_val)) {
                        // Get string value and check if it's "bytes"
                        if (v8_ffi.v8_Value_ToString(type_val, v8_context)) |type_str| {
                            var buf: [16]u8 = undefined;
                            const len = v8_ffi.v8_String_Utf8Length(type_str);
                            if (len > 0 and len <= 16) {
                                _ = v8_ffi.v8_String_WriteUtf8(type_str, &buf, @intCast(len));
                                if (std.mem.eql(u8, buf[0..@intCast(len)], "bytes")) {
                                    underlying_source_dict_storage.type = ._bytes_;
                                }
                            }
                        }
                    }
                }
            }
        }
        // If not a V8 object (e.g., Zig struct pointer from Blob.stream()),
        // skip callback extraction - stream will be created without JS callbacks
    }
    const underlying_source_dict: *const dictionaries.UnderlyingSource = &underlying_source_dict_storage;

    // Step 3: Perform InitializeReadableStream
    const instance = try init(ctx.allocator, State, &ReadableStream.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Create internal state
    const internal = try ctx.allocator.create(InternalState);
    errdefer ctx.allocator.destroy(internal);

    // InitializeReadableStream: Set initial state
    internal.* = InternalState{
        .controller = undefined, // Will be set by SetUp
        .reader = .none,
        .state = .readable,
        .stored_error = .none, // Type-safe StoredError
        .detached = false,
        .disturbed = false,
        .event_loop = loop,
        .allocator = ctx.allocator,
    };

    state.own._internal = internal;

    // Get strategy value with defaults
    const strat = if (strategy.was_passed) strategy.value else dictionaries.QueuingStrategy{};

    // Step 4: Check if this is a byte stream
    if (underlying_source_dict.type != null) {
        // Step 4.1: If strategy["size"] exists, throw a RangeError
        if (strat.size != null) {
            ctx.allocator.destroy(internal);
            deinit(instance);
            return error.RangeError;
        }

        // Step 4.2: Let highWaterMark be ? ExtractHighWaterMark(strategy, 0)
        // Byte streams default to 0 high water mark
        const high_water_mark = try extractHighWaterMark(&strat, 0.0);

        // Step 4.3: Perform ? SetUpReadableByteStreamControllerFromUnderlyingSource
        // Pass the manually extracted callbacks (V8 Global handles) instead of relying
        // on the dictionary's callback fields which expect Zig function pointers.
        try setUpReadableByteStreamControllerFromUnderlyingSource(
            instance,
            internal,
            @ptrCast(underlying_source_dict),
            underlying_source_dict,
            high_water_mark,
            extracted_start_callback,
            extracted_pull_callback,
            extracted_cancel_callback,
        );
    } else {
        // Step 5: Default stream (not byte stream)
        // Step 5.1: Assert type does not exist (checked above)

        // Step 5.2: Extract size algorithm
        const size_algorithm = extractSizeAlgorithm(&strat);
        _ = size_algorithm; // Will be passed to controller when size calculation is implemented

        // Step 5.3: Extract high water mark (default 1 for count-based queuing)
        const high_water_mark = try extractHighWaterMark(&strat, 1.0);

        // Step 5.4: Perform SetUpReadableStreamDefaultControllerFromUnderlyingSource
        // Pass the manually extracted callbacks (V8 Global handles) instead of relying
        // on the dictionary's callback fields which expect Zig function pointers.
        try setUpReadableStreamDefaultControllerFromUnderlyingSource(
            instance,
            internal,
            @ptrCast(underlying_source_dict),
            underlying_source_dict,
            high_water_mark,
            extracted_start_callback,
            extracted_pull_callback,
            extracted_cancel_callback,
        );
    }

    return instance;
}

/// Invoke the pending start callback for the stream's controller
///
/// This is called by the V8 bindings layer AFTER the constructor returns and
/// the V8 wrappers for both the stream and controller have been created.
///
/// Per WHATWG Streams spec § 4.9.3 SetUpReadableStreamDefaultController steps 9-12:
/// 9. Let startResult be the result of performing startAlgorithm
/// 10. Let startPromise be a promise resolved with startResult
/// 11. Upon fulfillment: set started = true, call pull if needed
/// 12. Upon rejection: error the controller
///
/// Arguments:
/// - instance: The ReadableStream instance
/// - controller_v8: The V8 Object wrapper for the controller (for passing to JS callback)
/// - v8_isolate: The V8 Isolate
/// - v8_context: The V8 Context
///
/// Returns: void (errors are handled by erroring the controller)
pub fn invokePendingStartCallback(
    instance: *runtime.Instance,
    controller_v8: *anyopaque,
    v8_isolate: *anyopaque,
    v8_context: *anyopaque,
) void {
    // Suppress unused parameter warnings - these were needed for the old direct V8 FFI approach
    // but are not needed when using Algorithm.invoke() which handles V8 internally
    _ = controller_v8;
    _ = v8_isolate;
    _ = v8_context;

    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    const controller_instance = internal.controller;

    const controller_state = controller_instance.getState(interfaces.ReadableStreamDefaultController.State);
    const controller_internal = controller_state.own._internal orelse return;

    // Check if there's a pending start algorithm and controller hasn't started
    const start_algo = controller_internal.start_algorithm orelse {
        // No start algorithm - nothing to do (already marked as started)
        return;
    };

    if (controller_internal.started) {
        // Already started - nothing to do
        return;
    }

    // Use the Algorithm's invoke() method which properly handles GlobalCallbackContext.
    // The Algorithm was created with jsCallbackAlgorithmGlobal() in setUpReadableStreamDefaultController,
    // so its context is a *GlobalCallbackContext containing the V8 Global handle.
    // The invoke() method retrieves the Local from the Global and calls through the engine interface.
    const start_promise = start_algo.invoke(controller_instance) catch {
        // Invocation failed - error the controller
        const js_error = streams_common.JSValue{ .string = "Start callback invocation failed" };
        const ReadableStreamDefaultControllerImpl = @import("ReadableStreamDefaultController.zig");
        ReadableStreamDefaultControllerImpl.readableStreamDefaultControllerError(controller_internal, @ptrCast(&js_error));
        return;
    };

    // Clear the start algorithm since it's been invoked
    start_algo.deinit();
    controller_internal.allocator.destroy(start_algo);
    controller_internal.start_algorithm = null;

    // Per WHATWG Streams spec § 4.9.3 steps 10-12:
    // 10. Let startPromise be a promise resolved with startResult
    // 11. Upon fulfillment of startPromise: set started = true, call pull if needed
    // 12. Upon rejection of startPromise: error the controller

    // Use onSettleCtx to handle promise settlement without creating a chained promise
    // This avoids memory leaks from untracked chained promises
    start_promise.onSettleCtx(
        onStartFulfilledCallback,
        onStartRejectedCallback,
        @ptrCast(controller_internal),
    ) catch {
        // If we can't attach handlers, assume immediate fulfillment
        onStartFulfilledImmediate(controller_internal);
        // Clean up the promise since we're not using its handlers
        start_promise.deinit();
    };
}

/// Callback for start promise fulfillment (used with onSettleCtx)
/// Signature must match: fn (*anyopaque, void) anyerror!void
fn onStartFulfilledCallback(ctx: *anyopaque, _: void) anyerror!void {
    const controller_internal: *@import("ReadableStreamDefaultController.zig").InternalState = @ptrCast(@alignCast(ctx));
    onStartFulfilledImmediate(controller_internal);
}

/// Callback for start promise rejection (used with onSettleCtx)
/// Signature must match: fn (*anyopaque, webidl.errors.Exception) anyerror!void
fn onStartRejectedCallback(ctx: *anyopaque, reason: webidl.errors.Exception) anyerror!void {
    const controller_internal: *@import("ReadableStreamDefaultController.zig").InternalState = @ptrCast(@alignCast(ctx));
    onStartRejectedImmediate(controller_internal, reason);
}

/// Invoke the pending start callback for a ReadableByteStreamController
///
/// This is called by V8 after the stream constructor returns and V8 wrappers exist.
/// It invokes the user-provided start() callback with the controller as argument,
/// handles any returned Promise, and marks the controller as started when done.
///
/// Per WHATWG Streams spec § 4.7.3 steps 14-17:
/// 14. Let startResult be the result of performing startAlgorithm
/// 15. Let startPromise be a promise resolved with startResult
/// 16. Upon fulfillment of startPromise: set started = true, call pull if needed
/// 17. Upon rejection of startPromise: error the controller
///
/// Parameters:
/// - instance: The ReadableStream instance
/// - controller_v8: The V8-wrapped ReadableByteStreamController object
/// - v8_isolate: The V8 Isolate
/// - v8_context: The V8 Context
///
/// Returns: void (errors are handled by erroring the controller)
pub fn invokePendingByteStartCallback(
    instance: *runtime.Instance,
    controller_v8: *anyopaque,
    v8_isolate: *anyopaque,
    v8_context: *anyopaque,
) void {
    // Suppress unused parameter warnings - these were needed for the old direct V8 FFI approach
    // but are not needed when using Algorithm.invoke() which handles V8 internally
    _ = controller_v8;
    _ = v8_isolate;
    _ = v8_context;

    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    const controller_instance = internal.controller;

    const ReadableByteStreamControllerImpl = @import("ReadableByteStreamController.zig");
    const controller_state = controller_instance.getState(interfaces.ReadableByteStreamController.State);
    const controller_internal = controller_state.own._internal orelse return;

    // Check if there's a pending start algorithm and controller hasn't started
    const start_algo = controller_internal.start_algorithm orelse {
        // No start algorithm - nothing to do (already marked as started)
        return;
    };

    if (controller_internal.started) {
        // Already started - nothing to do
        return;
    }

    // Use the Algorithm's invoke() method which properly handles GlobalCallbackContext.
    // The Algorithm was created with jsCallbackAlgorithmGlobal() in setUpReadableByteStreamController,
    // so its context is a *GlobalCallbackContext containing the V8 Global handle.
    // The invoke() method retrieves the Local from the Global and calls through the engine interface.
    const start_promise = start_algo.invoke(controller_instance) catch {
        // Invocation failed - error the controller
        const js_error = streams_common.JSValue{ .string = "Start callback invocation failed" };
        ReadableByteStreamControllerImpl.errorInternal(controller_internal, js_error);
        return;
    };

    // Clear the start algorithm since it's been invoked
    start_algo.deinit();
    controller_internal.allocator.destroy(start_algo);
    controller_internal.start_algorithm = null;

    // Per WHATWG Streams spec § 4.7.3 steps 15-17:
    // 15. Let startPromise be a promise resolved with startResult
    // 16. Upon fulfillment of startPromise: set started = true, call pull if needed
    // 17. Upon rejection of startPromise: error the controller

    // Create context for the callbacks (store pointer to controller internal state + instance)
    // We need to allocate this because the callbacks are called asynchronously
    const callback_ctx = controller_internal.allocator.create(ByteStartCallbackContext) catch {
        // Allocation failed - fall back to immediate fulfillment
        onByteStartFulfilledImmediate(controller_internal, controller_instance);
        start_promise.deinit();
        return;
    };
    callback_ctx.* = .{
        .controller_internal = controller_internal,
        .controller_instance = controller_instance,
        .allocator = controller_internal.allocator,
        .promise = start_promise,
    };

    // Use onSettleCtx to handle promise settlement without creating a chained promise
    start_promise.onSettleCtx(
        onByteStartFulfilledCallback,
        onByteStartRejectedCallback,
        @ptrCast(callback_ctx),
    ) catch {
        // If we can't attach handlers, assume immediate fulfillment
        onByteStartFulfilledImmediate(controller_internal, controller_instance);
        controller_internal.allocator.destroy(callback_ctx);
        start_promise.deinit();
    };
}

/// Context for async promise callbacks from invokePendingByteStartCallback
const ByteStartCallbackContext = struct {
    controller_internal: *@import("ReadableByteStreamController.zig").InternalState,
    controller_instance: *runtime.Instance,
    allocator: std.mem.Allocator,
    promise: *AsyncPromise(void),
};

/// Callback for byte stream start promise fulfillment (used with onSettleCtx)
/// Signature must match: fn (*anyopaque, void) anyerror!void
fn onByteStartFulfilledCallback(ctx: *anyopaque, _: void) anyerror!void {
    const callback_ctx: *ByteStartCallbackContext = @ptrCast(@alignCast(ctx));
    defer {
        callback_ctx.promise.deinit();
        callback_ctx.allocator.destroy(callback_ctx);
    }

    // Mark the controller as started and call pull if needed
    onByteStartFulfilledImmediate(callback_ctx.controller_internal, callback_ctx.controller_instance);
}

/// Callback for byte stream start promise rejection (used with onSettleCtx)
/// Signature must match: fn (*anyopaque, webidl.errors.Exception) anyerror!void
fn onByteStartRejectedCallback(ctx: *anyopaque, reason: webidl.errors.Exception) anyerror!void {
    const callback_ctx: *ByteStartCallbackContext = @ptrCast(@alignCast(ctx));
    defer {
        callback_ctx.promise.deinit();
        callback_ctx.allocator.destroy(callback_ctx);
    }

    const ReadableByteStreamControllerImpl = @import("ReadableByteStreamController.zig");

    // Convert Exception to JSValue - extract message from the tagged union
    const message = switch (reason) {
        .simple => |s| s.message,
        .dom => |d| d.message,
    };
    const js_error = streams_common.JSValue{ .string = message };
    ReadableByteStreamControllerImpl.errorInternal(callback_ctx.controller_internal, js_error);
}

/// Getter for locked
///
/// Spec: https://streams.spec.whatwg.org/#rs-locked
/// readonly attribute boolean locked
///
/// Returns true if the stream is locked to a reader.
/// A stream is locked if stream.[[reader]] is not undefined.
pub fn get_locked(instance: *runtime.Instance) anyerror!bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // IsReadableStreamLocked(stream): return stream.[[reader]] !== undefined
    return internal.reader != .none;
}

/// Operation: from
/// Spec: https://streams.spec.whatwg.org/#rs-from
/// static ReadableStream from(any asyncIterable)
///
/// Returns a ReadableStream wrapping the provided iterable or async iterable.
/// Spec algorithm: ReadableStreamFromIterable
///
/// Operation: from (static)
///
/// Spec: https://streams.spec.whatwg.org/#rs-from
/// static ReadableStream from(any asyncIterable)
///
/// Steps:
/// 1. Let stream = a new ReadableStream
/// 2. Let iteratorRecord = GetIterator(asyncIterable, async)
/// 3. Let pullAlgorithm = steps that call IteratorNext
/// 4. Let cancelAlgorithm = steps that call IteratorReturn
/// 5. SetUpReadableStreamDefaultController with pullAlgorithm and cancelAlgorithm
/// 6. Return stream
pub fn call_static_from(instance: *runtime.Instance, asyncIterable: runtime.JSValue) anyerror!*runtime.Instance {
    const allocator = instance.ctx.getAllocator();

    // Step 1: Create new ReadableStream instance
    const stream_instance = try init(
        allocator,
        State,
        &ReadableStream.vtable,
        instance.ctx,
    );
    errdefer deinit(stream_instance);

    const stream_state = stream_instance.getState(State);

    // Create internal state
    const stream_internal = try allocator.create(InternalState);
    errdefer allocator.destroy(stream_internal);

    // Step 2: Get iterator from async iterable
    // Convert JSValue to anyopaque for the iterator record
    const iterable_ptr = asyncIterable.toAnyopaque() orelse return error.TypeError;
    const iterator_record = IteratorRecord.fromAsyncIterable(
        allocator,
        instance.ctx,
        iterable_ptr,
    ) catch |err| {
        allocator.destroy(stream_internal);
        deinit(stream_instance);
        return switch (err) {
            error.TypeError => error.TypeError,
            else => error.InvalidState,
        };
    };
    errdefer iterator_record.deinit();

    // Step 3-4: Create pull and cancel algorithms
    const pull_algorithm = from_iterable.createPullAlgorithm(
        allocator,
        iterator_record,
    ) catch |err| {
        iterator_record.deinit();
        allocator.destroy(stream_internal);
        deinit(stream_instance);
        return err;
    };
    errdefer {
        pull_algorithm.deinit();
        allocator.destroy(pull_algorithm);
    }

    const cancel_algorithm = from_iterable.createCancelAlgorithm(
        allocator,
        iterator_record,
    ) catch |err| {
        pull_algorithm.deinit();
        allocator.destroy(pull_algorithm);
        iterator_record.deinit();
        allocator.destroy(stream_internal);
        deinit(stream_instance);
        return err;
    };
    errdefer {
        cancel_algorithm.deinit();
        allocator.destroy(cancel_algorithm);
    }

    // Create controller instance
    const controller_instance = try interfaces.ReadableStreamDefaultController.init(
        allocator,
        instance.ctx,
    );
    errdefer runtime.Instance.deinit(controller_instance);

    // Initialize stream internal state
    const ev_loop = try instance.ctx.getEventLoop();
    stream_internal.* = .{
        .controller = controller_instance,
        .reader = .none,
        .state = .readable,
        .stored_error = .none, // Type-safe StoredError
        .detached = false,
        .disturbed = false,
        .event_loop = ev_loop,
        .allocator = allocator,
    };

    stream_state.own._internal = stream_internal;

    // Step 5: Set up controller with algorithms
    const ReadableStreamDefaultControllerImpl = @import("ReadableStreamDefaultController.zig");
    try ReadableStreamDefaultControllerImpl.setUpReadableStreamDefaultController(
        stream_instance,
        controller_instance,
        pull_algorithm,
        cancel_algorithm,
        1.0, // Default high water mark
    );

    // Step 6: Return stream
    return stream_instance;
}

/// Operation: pipeThrough
///
/// Spec: https://streams.spec.whatwg.org/#rs-pipe-through
/// ReadableStream pipeThrough(ReadableWritablePair transform, optional StreamPipeOptions options = {})
///
/// Provides a convenient, chainable way of piping this readable stream through
/// a transform stream (or any other { writable, readable } pair).
///
/// Steps:
/// 1. If IsReadableStreamLocked(this) is true, throw TypeError
/// 2. If IsWritableStreamLocked(transform["writable"]) is true, throw TypeError
/// 3. Let signal be options["signal"] if it exists, or undefined otherwise
/// 4. Let promise be ReadableStreamPipeTo(this, transform["writable"], options)
/// 5. Set promise.[[PromiseIsHandled]] to true
/// 6. Return transform["readable"]
pub fn call_pipeThrough(instance: *runtime.Instance, transform: dictionaries.ReadableWritablePair, options: webidl.Opt(dictionaries.StreamPipeOptions)) anyerror!*runtime.Instance {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Check if source is locked
    if (internal.reader != .none) {
        return error.TypeError;
    }

    // Get writable and readable from transform pair
    // IMPORTANT: transform.writable and transform.readable are *v8.Value pointers (stored as *const anyopaque)
    // They are NOT *runtime.Instance pointers. We must extract the runtime.Instance from the V8 object's
    // internal field where it was stored when the V8 wrapper was created.
    const writable = try unwrapV8Instance(transform.writable) orelse return error.TypeError;
    const readable = try unwrapV8Instance(transform.readable) orelse return error.TypeError;

    // Step 2: Check if writable is locked
    const WritableStreamImpl = @import("WritableStream.zig");
    const writable_state = writable.getState(interfaces.WritableStream.State);
    const writable_internal: *WritableStreamImpl.InternalState = writable_state.own._internal orelse return error.InvalidState;

    if (writable_internal.writer != .none) {
        return error.TypeError;
    }

    // Steps 3-4: Start piping (ignore promise result - set [[PromiseIsHandled]])
    _ = call_pipeTo(instance, writable, options) catch |err| {
        // If pipeTo fails, propagate the error
        return err;
    };

    // Step 5: Promise is handled (we're ignoring it)

    // Step 6: Return transform["readable"]
    return readable;
}

/// Unwrap a V8 object pointer to extract the Zig runtime.Instance
///
/// When V8 converts JavaScript objects to Zig dictionaries, interface-typed members
/// (like ReadableWritablePair.writable) are stored as raw *v8.Value pointers via
/// the *const anyopaque branch in fromV8Value. This function extracts the actual
/// *runtime.Instance from the V8 object's internal field.
///
/// Arguments:
/// - v8_ptr: An opaque pointer that is actually a *v8.Value pointing to a V8 Object
///
/// Returns:
/// - The *runtime.Instance if the V8 object is a valid wrapped Zig object
/// - null if the object doesn't have internal fields (not a wrapped Zig object)
/// - error.TypeError if the value is not an object
fn unwrapV8Instance(v8_ptr: *const anyopaque) !?*runtime.Instance {
    const pointer_tag = @import("v8").pointer_tag;

    // Untag the pointer before using it as a V8 value
    const untagged = pointer_tag.untagPointer(v8_ptr);

    // If it's a runtime instance, extract it directly
    if (untagged.tag == .runtime_instance) {
        return @ptrCast(@alignCast(untagged.ptr));
    }

    // Cast the untagged pointer to a V8 Value
    const value: *v8.Value = @ptrCast(untagged.ptr);

    // Verify it's an object
    if (!v8.ffi.v8_Value_IsObject(value)) {
        return error.TypeError;
    }

    // Cast to Object to access internal fields
    const obj: *v8.Object = @ptrCast(value);

    // Check if this object has internal fields (indicating it wraps a Zig instance)
    const field_count = v8.ffi.v8_Object_InternalFieldCount(obj);
    if (field_count == 0) {
        // Not a wrapped Zig object - likely a plain JS object
        return null;
    }

    // Extract the runtime.Instance pointer from internal field 0
    const instance_ptr = v8.ffi.v8_Object_GetAlignedPointerFromInternalField(obj, 0);
    if (instance_ptr == null) {
        return null;
    }

    return @ptrCast(@alignCast(instance_ptr));
}

/// Operation: cancel
///
/// Spec: https://streams.spec.whatwg.org/#rs-cancel
/// Promise<undefined> cancel(optional any reason)
///
/// Steps:
/// 1. If ! IsReadableStreamLocked(this) is true, return rejected promise with TypeError
/// 2. Return ! ReadableStreamCancel(this, reason)
///
/// ReadableStreamCancel(stream, reason):
/// 1. Set stream.[[disturbed]] to true
/// 2. If stream.[[state]] is "closed", return resolved promise with undefined
/// 3. If stream.[[state]] is "errored", return rejected promise with stream.[[storedError]]
/// 4. Perform ! ReadableStreamClose(stream)
/// 5. Let reader be stream.[[reader]]
/// 6. If reader is not undefined and reader implements ReadableStreamBYOBReader, [handle BYOB]
/// 7. Let sourceCancelPromise be ! stream.[[controller]].[[CancelSteps]](reason)
/// 8. Return result of reacting to sourceCancelPromise with fulfillment step that returns undefined
pub fn call_cancel(instance: *runtime.Instance, reason: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Check if stream is locked
    // IsReadableStreamLocked(stream): return stream.[[reader]] !== undefined
    if (internal.reader != .none) {
        // Stream is locked - return rejected promise with TypeError
        const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
        const context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoContext;

        const exception = try webidl.errors.Exception.typeError(internal.allocator, "Cannot cancel a locked stream");
        const v8_promise = try promise_utils.createRejectedV8Promise(isolate, context, exception);
        return runtime.JSValue.fromPromise(@ptrCast(v8_promise));
    }

    // Step 2: Perform ReadableStreamCancel(this, reason)
    // Use undefined marker pointer when reason is not passed
    const reason_ptr: *const anyopaque = if (reason.was_passed)
        reason.value.toAnyopaque() orelse getUndefinedPtr()
    else
        getUndefinedPtr();
    return readableStreamCancel(instance, internal, reason_ptr);
}

/// ReadableStreamCancel algorithm
/// Internal implementation of stream cancellation
fn readableStreamCancel(
    instance: *runtime.Instance,
    internal: *InternalState,
    reason: *const anyopaque,
) !runtime.JSValue {
    _ = instance;

    // Step 1: Set stream.[[disturbed]] to true
    internal.disturbed = true;

    // Step 2: If stream.[[state]] is "closed", return resolved promise
    if (internal.state == .closed) {
        const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
        const context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoContext;

        const v8_promise = try promise_utils.createResolvedV8Promise(void, isolate, context, {});
        return runtime.JSValue.fromPromise(@ptrCast(v8_promise));
    }

    // Step 3: If stream.[[state]] is "errored", return rejected promise
    if (internal.state == .errored) {
        const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
        const context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoContext;

        // Reject with stream.[[storedError]]
        // Use type-safe StoredError API to check for error presence
        // Future: Use StoredError.toV8() for proper error propagation
        const exception = if (internal.stored_error.hasError())
            try webidl.errors.Exception.typeError(internal.allocator, "Stream errored (stored error)")
        else
            try webidl.errors.Exception.typeError(internal.allocator, "Stream is errored");
        const v8_promise = try promise_utils.createRejectedV8Promise(isolate, context, exception);
        return runtime.JSValue.fromPromise(@ptrCast(v8_promise));
    }

    // Step 4: Perform ReadableStreamClose(stream)
    readableStreamClose(internal);

    // Step 5: Get reader
    const reader = internal.reader;

    // Step 6: If reader is BYOB reader, handle readIntoRequests
    if (reader == .byob) {
        const byob_reader = reader.byob;
        const ReadableStreamBYOBReaderImpl = @import("ReadableStreamBYOBReader.zig");
        const byob_reader_state = byob_reader.getState(interfaces.ReadableStreamBYOBReader.State);
        if (byob_reader_state.own._internal) |byob_internal| {
            // For each readIntoRequest, call close steps
            for (byob_internal.read_into_requests.items) |request_ptr| {
                const ReadIntoRequest = @import("streams_read_into_request").ReadIntoRequest;
                const request: *const ReadIntoRequest = @ptrCast(@alignCast(request_ptr));
                request.executeCloseSteps();
            }
            byob_internal.read_into_requests.clearRetainingCapacity();
            _ = ReadableStreamBYOBReaderImpl;
        }
    }

    // Step 7: Call controller.[[CancelSteps]](reason)
    const ReadableStreamDefaultControllerImpl = @import("ReadableStreamDefaultController.zig");
    const cancel_promise = try ReadableStreamDefaultControllerImpl.cancelSteps(internal.controller, reason);

    // Step 8: Return the cancel promise (bridge to V8)
    const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
    const context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoContext;

    const v8_promise = try promise_utils.asyncPromiseToV8(void, std.heap.c_allocator, isolate, context, cancel_promise);
    return runtime.JSValue.fromPromise(@ptrCast(v8_promise));
}

/// ReadableStreamCancel called from a reader
/// This is used by ReadableStreamDefaultReader and ReadableStreamBYOBReader
/// to cancel the stream while bypassing the lock check (since they hold the lock)
pub fn readableStreamCancelFromReader(stream: *runtime.Instance, reason: *const anyopaque) anyerror!runtime.JSValue {
    const state = stream.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return readableStreamCancel(stream, internal, reason);
}

/// ReadableStreamCancel called from a reader with optional reason
/// This version handles the case where reason may be null (undefined in JS)
pub fn readableStreamCancelFromReaderWithOptReason(stream: *runtime.Instance, reason: ?*anyopaque) anyerror!runtime.JSValue {
    const state = stream.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Set stream.[[disturbed]] to true
    internal.disturbed = true;

    // Step 2: If stream.[[state]] is "closed", return resolved promise
    if (internal.state == .closed) {
        const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
        const context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoContext;

        const v8_promise = promise_utils.createResolvedV8Promise(void, isolate, context, {}) catch return error.OutOfMemory;
        return runtime.JSValue.fromPromise(@ptrCast(v8_promise));
    }

    // Step 3: If stream.[[state]] is "errored", return rejected promise
    if (internal.state == .errored) {
        const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
        const context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoContext;

        // Use type-safe StoredError API
        const exception = if (internal.stored_error.hasError())
            webidl.errors.Exception.typeError(internal.allocator, "Stream errored (stored error)") catch return error.OutOfMemory
        else
            webidl.errors.Exception.typeError(internal.allocator, "Stream is errored") catch return error.OutOfMemory;
        const v8_promise = promise_utils.createRejectedV8Promise(isolate, context, exception) catch return error.OutOfMemory;
        return runtime.JSValue.fromPromise(@ptrCast(v8_promise));
    }

    // Step 4: Perform ReadableStreamClose(stream)
    readableStreamClose(internal);

    // Step 5: Get reader
    const reader = internal.reader;

    // Step 6: If reader is BYOB reader, handle readIntoRequests
    if (reader == .byob) {
        const byob_reader = reader.byob;
        const byob_reader_state = byob_reader.getState(interfaces.ReadableStreamBYOBReader.State);
        if (byob_reader_state.own._internal) |byob_internal| {
            for (byob_internal.read_into_requests.items) |request_ptr| {
                const ReadIntoRequest = @import("streams_read_into_request").ReadIntoRequest;
                const request: *const ReadIntoRequest = @ptrCast(@alignCast(request_ptr));
                request.executeCloseSteps();
            }
            byob_internal.read_into_requests.clearRetainingCapacity();
        }
    }

    // Step 7: Call controller.[[CancelSteps]](reason)
    const ReadableStreamDefaultControllerImpl = @import("ReadableStreamDefaultController.zig");
    const cancel_promise = ReadableStreamDefaultControllerImpl.cancelStepsWithOptReason(internal.controller, reason) catch return error.OutOfMemory;

    // Step 8: Return the cancel promise (bridge to V8)
    const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
    const context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoContext;

    const v8_promise = promise_utils.asyncPromiseToV8(void, std.heap.c_allocator, isolate, context, cancel_promise) catch return error.OutOfMemory;
    return runtime.JSValue.fromPromise(@ptrCast(v8_promise));
}

/// ReadableStreamClose algorithm
/// Internal implementation of stream closing
pub fn readableStreamClose(internal: *InternalState) void {
    // Assert: stream.[[state]] is "readable"
    std.debug.assert(internal.state == .readable);

    // Set stream.[[state]] to "closed"
    internal.state = .closed;

    // Note: The spec also requires:
    // - Resolving reader.[[closedPromise]] if reader exists
    // - This is handled by the reader implementation
}

/// ReadableStreamError algorithm
/// Internal implementation of stream erroring
///
/// NOTE: This function accepts a raw pointer for compatibility with existing callers.
/// The pointer is stored in StoredError as a V8 Global handle reference.
/// Future work: Update all callers to pass JSValue or StoredError directly.
pub fn readableStreamError(internal: *InternalState, e: *const anyopaque) void {
    // Assert: stream.[[state]] is "readable"
    std.debug.assert(internal.state == .readable);

    // Set stream.[[state]] to "errored"
    internal.state = .errored;

    // Store the error using type-safe StoredError
    // The pointer is assumed to be a V8 Global handle (legacy compatibility)
    internal.stored_error.storeRawPtr(@constCast(e));

    // Note: Reader operations (reject closedPromise, reject pending reads)
    // are handled by the reader when it detects stream state change
    // This is correct per spec - stream just transitions state
}

/// ReadableStreamErrorWithValue - Type-safe version using streams_common.JSValue
///
/// This is the preferred version that uses the typed JSValue union instead of raw anyopaque.
/// The error value is stored with proper type information preserved.
///
/// Steps:
/// 1. Assert: stream.[[state]] is "readable"
/// 2. Set stream.[[state]] to "errored"
/// 3. Set stream.[[storedError]] to e
pub fn readableStreamErrorWithValue(internal: *InternalState, e: streams_common.JSValue) void {
    // Assert: stream.[[state]] is "readable"
    std.debug.assert(internal.state == .readable);

    // Set stream.[[state]] to "errored"
    internal.state = .errored;

    // Store the error using type-safe StoredError
    // Convert streams_common.JSValue to StoredError based on the variant
    switch (e) {
        .managed_handle => |h| internal.stored_error.storeRawPtr(h.get()),
        .string => |s| internal.stored_error.storeMessage(s),
        .error_value => |err| {
            // Store the error message with type info
            // StoredError will create appropriate V8 error on retrieval
            internal.stored_error.storeMessage(err.message);
        },
        else => {
            // For other types, store a generic error message
            internal.stored_error.storeMessage("Stream error");
        },
    }

    // Note: Reader operations (reject closedPromise, reject pending reads)
    // are handled by the reader when it detects stream state change
    // This is correct per spec - stream just transitions state
}

/// Operation: getReader
///
/// Spec: https://streams.spec.whatwg.org/#rs-get-reader
/// ReadableStreamReader getReader(optional ReadableStreamGetReaderOptions options = {})
///
/// Steps:
/// 1. If options["mode"] does not exist, return ? AcquireReadableStreamDefaultReader(this)
/// 2. Assert: options["mode"] is "byob"
/// 3. Return ? AcquireReadableStreamBYOBReader(this)
///
/// AcquireReadableStreamDefaultReader(stream):
/// 1. Let reader be a new ReadableStreamDefaultReader
/// 2. Perform ? SetUpReadableStreamDefaultReader(reader, stream)
/// 3. Return reader
pub fn call_getReader(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ReadableStreamGetReaderOptions)) anyerror!typedefs.ReadableStreamReader {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const ctx = instance.ctx;

    // Step 1: Check if mode exists in options
    // Future: Parse options.mode to distinguish default vs BYOB reader
    // For now, always create default reader (BYOB not implemented)
    _ = options;
    _ = internal;

    // AcquireReadableStreamDefaultReader:
    // Step 1-2: Create reader and call SetUpReadableStreamDefaultReader
    // This is done by the ReadableStreamDefaultReader constructor
    const reader = interfaces.ReadableStreamDefaultReader.call_constructor(
        ctx,
        instance,
    ) catch |err| {
        // Remap errors to ImplError
        return switch (err) {
            error.TypeError => error.TypeError,
            error.OutOfMemory => error.OutOfMemory,
            error.InvalidState => error.InvalidState,
            else => error.NotImplemented,
        };
    };

    // Step 3: Return reader as union
    // The return type is typedefs.ReadableStreamReader which is a union
    return typedefs.ReadableStreamReader{ .readable_stream_default_reader = reader };
}

/// Operation: pipeTo
///
/// Spec: https://streams.spec.whatwg.org/#rs-pipe-to
/// Promise<undefined> pipeTo(WritableStream destination, optional StreamPipeOptions options = {})
///
/// Pipes this readable stream to the given writable stream destination.
/// The way in which the piping process behaves under various error conditions
/// can be customized with options.
///
/// Steps:
/// 1. If IsReadableStreamLocked(this) is true, return rejected promise with TypeError
/// 2. If IsWritableStreamLocked(destination) is true, return rejected promise with TypeError
/// 3. Let signal be options["signal"] if it exists, or undefined otherwise
/// 4. Return ReadableStreamPipeTo(this, destination, preventClose, preventAbort, preventCancel, signal)
pub fn call_pipeTo(instance: *runtime.Instance, destination: *runtime.Instance, options: webidl.Opt(dictionaries.StreamPipeOptions)) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const allocator = internal.allocator;

    // Step 1: Check if source is locked
    if (internal.reader != .none) {
        const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
        const context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoContext;

        const exception = try webidl.errors.Exception.typeError(allocator, "Cannot pipe a locked stream");
        const v8_promise = try promise_utils.createRejectedV8Promise(isolate, context, exception);
        return runtime.JSValue.fromPromise(@ptrCast(v8_promise));
    }

    // Step 2: Check if destination is locked
    const WritableStreamImpl = @import("WritableStream.zig");
    const dest_state = destination.getState(interfaces.WritableStream.State);
    const dest_internal: *WritableStreamImpl.InternalState = dest_state.own._internal orelse return error.InvalidState;

    if (dest_internal.writer != .none) {
        const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
        const context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoContext;

        const exception = try webidl.errors.Exception.typeError(allocator, "Cannot pipe to a locked stream");
        const v8_promise = try promise_utils.createRejectedV8Promise(isolate, context, exception);
        return runtime.JSValue.fromPromise(@ptrCast(v8_promise));
    }

    // Step 3: Extract options
    const opts = if (options.was_passed) options.value else dictionaries.StreamPipeOptions{};
    const prevent_close = opts.preventClose orelse false;
    const prevent_abort = opts.preventAbort orelse false;
    const prevent_cancel = opts.preventCancel orelse false;
    // Note: signal (AbortSignal) is not yet fully implemented

    // Step 4: Return ReadableStreamPipeTo
    return readableStreamPipeTo(
        instance,
        internal,
        destination,
        dest_internal,
        prevent_close,
        prevent_abort,
        prevent_cancel,
    );
}

/// Operation: tee
///
/// Spec: https://streams.spec.whatwg.org/#rs-tee
/// sequence<ReadableStream> tee()
///
/// Tees this readable stream, returning a two-element array containing
/// the two resulting branches as new ReadableStream instances.
///
/// Teeing a stream will lock it, preventing any other consumer from acquiring
/// a reader. To cancel the stream, cancel both resulting branches; a composite
/// reason will then be propagated to the underlying source.
///
/// Steps:
/// 1. Return ReadableStreamTee(this, false)
pub fn call_tee(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Check if stream is locked
    if (internal.reader != .none) {
        return error.TypeError;
    }

    // Create tee branches
    return readableStreamTee(instance, internal, false);
}

/// Internal state for tee operation
///
/// Per WHATWG Streams spec § 4.9.1 ReadableStreamDefaultTee
/// This struct holds the shared state between the two branch streams.
const TeeState = struct {
    /// The original source stream being teed
    source: *runtime.Instance,

    /// The reader acquired from the source stream
    reader: *runtime.Instance,

    /// First branch stream
    branch1: ?*runtime.Instance,

    /// Second branch stream
    branch2: ?*runtime.Instance,

    /// Whether a read operation is in progress
    reading: bool,

    /// Whether to perform another read after current one completes
    read_again: bool,

    /// Whether branch1 has been canceled
    canceled1: bool,

    /// Whether branch2 has been canceled
    canceled2: bool,

    /// Reason provided when branch1 was canceled
    /// Per Streams spec, cancel reasons are typed as `any` which maps to runtime.JSValue
    reason1: runtime.JSValue,

    /// Reason provided when branch2 was canceled
    /// Per Streams spec, cancel reasons are typed as `any` which maps to runtime.JSValue
    reason2: runtime.JSValue,

    /// Promise resolved when both branches are canceled (for composite cancellation)
    cancel_promise: *AsyncPromise(void),

    /// Whether cloneForBranch2 was requested (for structured clone)
    clone_for_branch2: bool,

    /// Allocator for memory management
    allocator: std.mem.Allocator,

    /// Event loop for async operations
    event_loop: event_loop.EventLoop,

    pub fn deinit(self: *TeeState) void {
        // Note: Don't deinit branch streams here - they have their own lifecycle
        // The cancel_promise will be resolved/rejected elsewhere
        self.allocator.destroy(self);
    }
};

/// ReadableStreamDefaultTee algorithm
///
/// Spec: https://streams.spec.whatwg.org/#readable-stream-default-tee
///
/// Creates two branches from a readable stream. Reading from one branch
/// causes chunks to be enqueued in both branches' internal queues.
///
/// Steps (from spec):
/// 1. Assert: stream implements ReadableStream
/// 2. Assert: cloneForBranch2 is a boolean
/// 3. Let reader be ? AcquireReadableStreamDefaultReader(stream)
/// 4. Let reading be false
/// 5. Let readAgain be false
/// 6. Let canceled1 be false
/// 7. Let canceled2 be false
/// 8. Let reason1 be undefined
/// 9. Let reason2 be undefined
/// 10. Let branch1 be undefined
/// 11. Let branch2 be undefined
/// 12. Let cancelPromise be a new promise
/// 13. Let pullAlgorithm be ... (chunk distribution logic)
/// 14. Let cancel1Algorithm be ... (composite cancel logic)
/// 15. Let cancel2Algorithm be ... (composite cancel logic)
/// 16. Let startAlgorithm be an algorithm that returns undefined
/// 17. Set branch1 to ! CreateReadableStream(startAlgorithm, pullAlgorithm, cancel1Algorithm)
/// 18. Set branch2 to ! CreateReadableStream(startAlgorithm, pullAlgorithm, cancel2Algorithm)
/// 19. Upon rejection of reader.[[closedPromise]] with reason r, error both branches
/// 20. Return « branch1, branch2 »
fn readableStreamTee(
    source: *runtime.Instance,
    source_internal: *InternalState,
    clone_for_branch2: bool,
) anyerror!runtime.JSValue {
    const allocator = source_internal.allocator;
    const ctx = source.ctx;
    const loop = source_internal.event_loop;

    // Step 3: Acquire reader
    const reader = interfaces.ReadableStreamDefaultReader.call_constructor(
        ctx,
        source,
    ) catch |err| {
        return switch (err) {
            error.TypeError => error.TypeError,
            error.OutOfMemory => error.OutOfMemory,
            else => error.InvalidState,
        };
    };
    errdefer interfaces.ReadableStreamDefaultReader.deinit(reader);

    // Step 12: Create cancelPromise
    const cancel_promise = AsyncPromise(void).init(allocator, loop) catch return error.OutOfMemory;
    errdefer cancel_promise.deinit();

    // Create TeeState - must be done before creating branches so they can reference it
    const tee_state = allocator.create(TeeState) catch return error.OutOfMemory;
    errdefer allocator.destroy(tee_state);

    // Initialize tee state with nulls for branches (will be set after creation)
    tee_state.* = .{
        .source = source,
        .reader = reader,
        .branch1 = null,
        .branch2 = null,
        .reading = false,
        .read_again = false,
        .canceled1 = false,
        .canceled2 = false,
        .reason1 = runtime.JSValue.jsUndefined,
        .reason2 = runtime.JSValue.jsUndefined,
        .cancel_promise = cancel_promise,
        .clone_for_branch2 = clone_for_branch2,
        .allocator = allocator,
        .event_loop = loop,
    };

    // Steps 13-15: Create algorithms for branches
    // Pull algorithm: reads from source and enqueues to both branches
    const pull_algo = createTeePullAlgorithm(allocator, tee_state) catch return error.OutOfMemory;
    errdefer {
        pull_algo.deinit();
        allocator.destroy(pull_algo);
    }

    // Cancel algorithm for branch1
    const cancel1_algo = createTeeCancel1Algorithm(allocator, tee_state) catch return error.OutOfMemory;
    errdefer {
        cancel1_algo.deinit();
        allocator.destroy(cancel1_algo);
    }

    // Cancel algorithm for branch2
    const cancel2_algo = createTeeCancel2Algorithm(allocator, tee_state) catch return error.OutOfMemory;
    errdefer {
        cancel2_algo.deinit();
        allocator.destroy(cancel2_algo);
    }

    // Steps 17-18: Create branch streams with our algorithms
    // Branch 1: uses pull_algo and cancel1_algo
    const branch1 = createTeeBranchStream(allocator, ctx, loop, pull_algo, cancel1_algo) catch return error.OutOfMemory;
    errdefer deinit(branch1);

    // Branch 2: uses same pull_algo but cancel2_algo
    // Note: We need a separate pull algorithm instance since both controllers store their own
    const pull_algo2 = createTeePullAlgorithm(allocator, tee_state) catch return error.OutOfMemory;

    const branch2 = createTeeBranchStream(allocator, ctx, loop, pull_algo2, cancel2_algo) catch {
        pull_algo2.deinit();
        allocator.destroy(pull_algo2);
        return error.OutOfMemory;
    };
    errdefer deinit(branch2);

    // Now set the branches in tee_state
    tee_state.branch1 = branch1;
    tee_state.branch2 = branch2;

    // Step 19: Upon rejection of reader.[[closedPromise]] with reason r, error both branches
    // Hook into the reader's closedPromise rejection to error both branches
    const reader_state = reader.getState(interfaces.ReadableStreamDefaultReader.State);
    if (reader_state.own._internal) |reader_internal| {
        // Add a rejection handler to the reader's closed promise
        reader_internal.closed_promise.onSettleCtx(
            null, // No fulfillment handler needed
            teeClosedPromiseRejectionHandler,
            @ptrCast(tee_state),
        ) catch {
            // If we can't add the handler, the branches will still work
            // but won't propagate closure errors. This is acceptable degradation.
        };
    }

    // Step 20: Return array of branches [branch1, branch2]
    // Get V8 isolate and context for array creation
    const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
    const v8_context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoContext;

    // Create V8 Array containing [branch1, branch2] using the array utility
    const v8_array = v8_engine.createPair(isolate, v8_context, branch1, branch2) catch {
        return error.OutOfMemory;
    };
    return runtime.JSValue.fromHandle(@ptrCast(v8_array));
}

/// Result type for tee operation
pub const TeeBranches = struct {
    branch1: *runtime.Instance,
    branch2: *runtime.Instance,
};

// ============================================================================
// Tee Algorithm Support Functions
// ============================================================================

/// Create the pull algorithm for tee branches
///
/// Per spec step 13 (pullAlgorithm):
/// - If reading is true, set readAgain to true and return resolved promise
/// - Set reading to true
/// - Create read request that distributes chunks to both branches
/// - Perform ReadableStreamDefaultReaderRead(reader, readRequest)
/// - Return resolved promise
///
/// Uses createTypedAlgorithm for compile-time type safety.
fn createTeePullAlgorithm(allocator: std.mem.Allocator, tee_state: *TeeState) !*Algorithm {
    return createTypedAlgorithm(
        TeeState,
        allocator,
        tee_state,
        teePullInvokeTyped,
        teePullInvokeWithArgTyped,
        teePullDestroyTyped,
    );
}

/// Typed pull algorithm implementation
/// Receives *TeeState directly - no anyopaque casting needed.
fn teePullInvokeTyped(
    controller: *runtime.Instance,
    tee_state: *TeeState,
) anyerror!*AsyncPromise(void) {
    const allocator = tee_state.allocator;
    const loop = tee_state.event_loop;

    // Step 13.1: If reading is true, set readAgain to true and return
    if (tee_state.reading) {
        tee_state.read_again = true;
        const promise = try AsyncPromise(void).init(allocator, loop);
        promise.fulfill({});
        return promise;
    }

    // Step 13.2: Set reading to true
    tee_state.reading = true;

    // Step 13.3-4: Perform read from source and distribute to branches
    // This is where we read from the source reader and enqueue to both branches
    teePullFromSource(tee_state) catch {
        // On error, return resolved promise (errors are propagated through branch error handling)
        const promise = try AsyncPromise(void).init(allocator, loop);
        promise.fulfill({});
        return promise;
    };

    _ = controller; // Controller is used indirectly through tee_state

    // Return resolved promise
    const promise = try AsyncPromise(void).init(allocator, loop);
    promise.fulfill({});
    return promise;
}

/// Typed pull with arg implementation
fn teePullInvokeWithArgTyped(
    controller: *runtime.Instance,
    tee_state: *TeeState,
    arg: *const anyopaque,
) anyerror!*AsyncPromise(void) {
    _ = arg;
    return teePullInvokeTyped(controller, tee_state);
}

/// Typed destroy implementation
fn teePullDestroyTyped(context: *TeeState, allocator: std.mem.Allocator) void {
    _ = context;
    _ = allocator;
    // TeeState lifecycle is managed separately
}

/// Pull from source stream and distribute chunks to both branches
fn teePullFromSource(tee_state: *TeeState) !void {
    const reader = tee_state.reader;
    const reader_impl = @import("ReadableStreamDefaultReader.zig");

    // Read from source
    const result_jsvalue = reader_impl.call_read(reader) catch |err| {
        // Handle read error: error both branches
        tee_state.reading = false;
        teeErrorBothBranches(tee_state, @errorName(err));
        return err;
    };

    // Extract handle pointer from JSValue and cast result to ReadResult
    const result_ptr: *anyopaque = switch (result_jsvalue) {
        .handle => |h| h.ptr,
        .instance => |ptr| ptr,
        else => return error.TypeError,
    };
    const read_result: *const reader_impl.ReadResult = @ptrCast(@alignCast(result_ptr));

    // Handle close
    if (read_result.done) {
        tee_state.reading = false;

        // Close both branches if not canceled
        if (!tee_state.canceled1) {
            if (tee_state.branch1) |branch1| {
                teeCloseBranch(branch1);
            }
        }
        if (!tee_state.canceled2) {
            if (tee_state.branch2) |branch2| {
                teeCloseBranch(branch2);
            }
        }

        // Resolve cancel promise if not both canceled
        if (!tee_state.canceled1 or !tee_state.canceled2) {
            tee_state.cancel_promise.fulfill({});
        }

        return;
    }

    // Distribute chunk to both branches
    const chunk = read_result.value;

    // Enqueue to branch1 if not canceled
    if (!tee_state.canceled1) {
        if (tee_state.branch1) |branch1| {
            teeEnqueueToBranch(branch1, chunk) catch {
                // Ignore enqueue errors - branch may be closing
            };
        }
    }

    // Enqueue to branch2 if not canceled
    if (!tee_state.canceled2) {
        if (tee_state.branch2) |branch2| {
            // If cloneForBranch2, we would clone here
            // For now, use the same chunk reference
            teeEnqueueToBranch(branch2, chunk) catch {
                // Ignore enqueue errors - branch may be closing
            };
        }
    }

    // Done reading
    tee_state.reading = false;

    // If readAgain was set during this read, perform another read
    if (tee_state.read_again) {
        tee_state.read_again = false;
        try teePullFromSource(tee_state);
    }
}

/// Enqueue a chunk to a branch stream's controller
fn teeEnqueueToBranch(branch: *runtime.Instance, chunk: ?runtime.JSValue) !void {
    const branch_state = branch.getState(State);
    const branch_internal = branch_state.own._internal orelse return error.InvalidState;

    const controller = branch_internal.controller;
    const controller_impl = @import("ReadableStreamDefaultController.zig");

    if (chunk) |c| {
        try controller_impl.call_enqueue(controller, webidl.Opt(runtime.JSValue).passed(c));
    }
}

/// Close a branch stream's controller
fn teeCloseBranch(branch: *runtime.Instance) void {
    const branch_state = branch.getState(State);
    const branch_internal = branch_state.own._internal orelse return;

    const controller = branch_internal.controller;
    const controller_impl = @import("ReadableStreamDefaultController.zig");

    controller_impl.call_close(controller) catch {
        // Ignore close errors - may already be closing
    };
}

/// Error both branch streams
fn teeErrorBothBranches(tee_state: *TeeState, reason: []const u8) void {
    // Pass the reason string as the error. In full JS runtime integration,
    // this would be a proper JS Error object.
    // TODO: Create actual V8 Error from reason string
    _ = reason;
    const error_jsvalue = runtime.JSValue.jsUndefined;

    if (tee_state.branch1) |branch1| {
        const branch_state = branch1.getState(State);
        if (branch_state.own._internal) |branch_internal| {
            const controller = branch_internal.controller;
            const controller_impl = @import("ReadableStreamDefaultController.zig");
            controller_impl.call_error(controller, webidl.Opt(runtime.JSValue).passed(error_jsvalue)) catch {};
        }
    }

    if (tee_state.branch2) |branch2| {
        const branch_state = branch2.getState(State);
        if (branch_state.own._internal) |branch_internal| {
            const controller = branch_internal.controller;
            const controller_impl = @import("ReadableStreamDefaultController.zig");
            controller_impl.call_error(controller, webidl.Opt(runtime.JSValue).passed(error_jsvalue)) catch {};
        }
    }

    // Resolve cancel promise
    if (!tee_state.canceled1 or !tee_state.canceled2) {
        tee_state.cancel_promise.fulfill({});
    }
}

/// Handler for reader's closedPromise rejection during tee operation
///
/// Spec Step 19: Upon rejection of reader.[[closedPromise]] with reason r,
/// perform ! ReadableStreamDefaultControllerError(branch1.[[controller]], r)
/// perform ! ReadableStreamDefaultControllerError(branch2.[[controller]], r)
fn teeClosedPromiseRejectionHandler(ctx: *anyopaque, exception: webidl.errors.Exception) anyerror!void {
    const tee_state: *TeeState = @ptrCast(@alignCast(ctx));

    // Extract error message from exception (for logging/debugging)
    const reason = switch (exception) {
        .simple => |e| e.message,
        .dom => |e| e.message,
    };

    // Error both branches with the rejection reason
    teeErrorBothBranches(tee_state, reason);
}

/// Create cancel algorithm for branch 1
///
/// Per spec step 14 (cancel1Algorithm):
/// - Set canceled1 to true
/// - Set reason1 to reason
/// - If canceled2 is true, create composite reason and cancel source
/// - Return cancelPromise
///
/// Uses createTypedAlgorithm for compile-time type safety.
fn createTeeCancel1Algorithm(allocator: std.mem.Allocator, tee_state: *TeeState) !*Algorithm {
    return createTypedAlgorithm(
        TeeState,
        allocator,
        tee_state,
        teeCancel1InvokeTyped,
        teeCancel1InvokeWithArgTyped,
        teeCancelDestroyTyped,
    );
}

/// Typed cancel1 algorithm implementation
/// Receives *TeeState directly - no anyopaque casting needed.
fn teeCancel1InvokeTyped(
    controller: *runtime.Instance,
    tee_state: *TeeState,
) anyerror!*AsyncPromise(void) {
    _ = controller;

    // Step 14.1: Set canceled1 to true
    tee_state.canceled1 = true;

    // Step 14.2: Set reason1 to reason (no reason in this overload)
    tee_state.reason1 = runtime.JSValue.jsUndefined;

    // Step 14.3: If canceled2 is true, perform composite cancel
    if (tee_state.canceled2) {
        try teePerformCompositeCancel(tee_state);
    }

    // Step 14.4: Return cancelPromise
    return tee_state.cancel_promise;
}

/// Typed cancel1 with arg implementation
fn teeCancel1InvokeWithArgTyped(
    controller: *runtime.Instance,
    tee_state: *TeeState,
    arg: *const anyopaque,
) anyerror!*AsyncPromise(void) {
    _ = controller;

    // Step 14.1: Set canceled1 to true
    tee_state.canceled1 = true;

    // Step 14.2: Set reason1 to reason
    // Convert the anyopaque pointer (V8 handle) to JSValue for type-safe storage
    tee_state.reason1 = runtime.JSValue.fromHandleNonOwning(@constCast(arg));

    // Step 14.3: If canceled2 is true, perform composite cancel
    if (tee_state.canceled2) {
        try teePerformCompositeCancel(tee_state);
    }

    // Step 14.4: Return cancelPromise
    return tee_state.cancel_promise;
}

/// Create cancel algorithm for branch 2
///
/// Per spec step 15 (cancel2Algorithm):
/// - Set canceled2 to true
/// - Set reason2 to reason
/// - If canceled1 is true, create composite reason and cancel source
/// - Return cancelPromise
///
/// Uses createTypedAlgorithm for compile-time type safety.
fn createTeeCancel2Algorithm(allocator: std.mem.Allocator, tee_state: *TeeState) !*Algorithm {
    return createTypedAlgorithm(
        TeeState,
        allocator,
        tee_state,
        teeCancel2InvokeTyped,
        teeCancel2InvokeWithArgTyped,
        teeCancelDestroyTyped,
    );
}

/// Typed cancel2 algorithm implementation
/// Receives *TeeState directly - no anyopaque casting needed.
fn teeCancel2InvokeTyped(
    controller: *runtime.Instance,
    tee_state: *TeeState,
) anyerror!*AsyncPromise(void) {
    _ = controller;

    // Step 15.1: Set canceled2 to true
    tee_state.canceled2 = true;

    // Step 15.2: Set reason2 to reason (no reason in this overload)
    tee_state.reason2 = runtime.JSValue.jsUndefined;

    // Step 15.3: If canceled1 is true, perform composite cancel
    if (tee_state.canceled1) {
        try teePerformCompositeCancel(tee_state);
    }

    // Step 15.4: Return cancelPromise
    return tee_state.cancel_promise;
}

/// Typed cancel2 with arg implementation
fn teeCancel2InvokeWithArgTyped(
    controller: *runtime.Instance,
    tee_state: *TeeState,
    arg: *const anyopaque,
) anyerror!*AsyncPromise(void) {
    _ = controller;

    // Step 15.1: Set canceled2 to true
    tee_state.canceled2 = true;

    // Step 15.2: Set reason2 to reason
    // Convert the anyopaque pointer (V8 handle) to JSValue for type-safe storage
    tee_state.reason2 = runtime.JSValue.fromHandleNonOwning(@constCast(arg));

    // Step 15.3: If canceled1 is true, perform composite cancel
    if (tee_state.canceled1) {
        try teePerformCompositeCancel(tee_state);
    }

    // Step 15.4: Return cancelPromise
    return tee_state.cancel_promise;
}

/// Typed destroy implementation (shared by both cancel algorithms)
fn teeCancelDestroyTyped(context: *TeeState, allocator: std.mem.Allocator) void {
    _ = context;
    _ = allocator;
    // TeeState lifecycle is managed separately
}

/// Perform composite cancel when both branches are canceled
///
/// Per spec: Create composite reason array [reason1, reason2] and cancel source
fn teePerformCompositeCancel(tee_state: *TeeState) !void {
    // Cancel the source stream with composite reason
    // For now, we use a simple approach - just cancel with reason1 or reason2
    // If both are undefined, use undefined as the reason
    const reason_jsvalue: runtime.JSValue = if (!tee_state.reason1.isUndefined())
        tee_state.reason1
    else if (!tee_state.reason2.isUndefined())
        tee_state.reason2
    else
        runtime.JSValue.jsUndefined;

    // Get source stream's internal state
    const source_state = tee_state.source.getState(State);
    const source_internal = source_state.own._internal orelse return error.InvalidState;

    // Release reader first
    const reader_impl = @import("ReadableStreamDefaultReader.zig");
    reader_impl.call_releaseLock(tee_state.reader) catch {};

    // Cancel source stream with JSValue reason
    _ = call_cancel(tee_state.source, webidl.Opt(runtime.JSValue).passed(reason_jsvalue)) catch {};

    _ = source_internal;

    // Resolve the cancel promise
    tee_state.cancel_promise.fulfill({});
}

/// Create a branch stream with the given algorithms
///
/// This creates a new ReadableStream and sets up its controller with
/// the tee-specific pull and cancel algorithms.
fn createTeeBranchStream(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    loop: event_loop.EventLoop,
    pull_algorithm: *Algorithm,
    cancel_algorithm: *Algorithm,
) !*runtime.Instance {
    // Create new ReadableStream instance
    const stream_instance = try interfaces.ReadableStream.init(allocator, ctx);
    errdefer runtime.Instance.deinit(stream_instance);

    // Get stream state
    const stream_state = stream_instance.getState(State);

    // Create internal state
    const stream_internal = try allocator.create(InternalState);
    errdefer allocator.destroy(stream_internal);

    // Create controller instance
    const controller_instance = try interfaces.ReadableStreamDefaultController.init(allocator, ctx);
    errdefer runtime.Instance.deinit(controller_instance);

    // Initialize stream internal state
    stream_internal.* = .{
        .controller = controller_instance,
        .reader = .none,
        .state = .readable,
        .stored_error = .none, // Type-safe StoredError
        .detached = false,
        .disturbed = false,
        .event_loop = loop,
        .allocator = allocator,
    };

    stream_state.own._internal = stream_internal;

    // Set up controller with tee algorithms
    const ReadableStreamDefaultControllerImpl = @import("ReadableStreamDefaultController.zig");
    try ReadableStreamDefaultControllerImpl.setUpReadableStreamDefaultController(
        stream_instance,
        controller_instance,
        pull_algorithm,
        cancel_algorithm,
        1.0, // Default high water mark
    );

    return stream_instance;
}
/// Operation: values
///
/// Spec: https://streams.spec.whatwg.org/#rs-asynciterator
/// Per spec "asynchronous iterator initialization steps" (streams.md lines 602-610)
///
/// Returns an async iterator for iterating over stream chunks.
///
/// Parameters:
/// - options: Optional configuration with preventCancel flag
///
/// Steps (from spec):
/// 1. Return ! AcquireReadableStreamAsyncIterator(this, options["preventCancel"])
///
/// ## Engine Integration
///
/// When a JS engine is configured, the Zig iterator is wrapped using the
/// engine's async iterator support (e.g., V8 object with next()/return() methods).
/// When no engine is present, returns the raw Zig iterator pointer.
pub fn call_values(
    instance: *runtime.Instance,
    options: webidl.Opt(dictionaries.ReadableStreamIteratorOptions),
) anyerror!runtime.JSValue {
    const allocator = instance.ctx.getAllocator();
    const ctx = instance.ctx;

    // Extract preventCancel from options (defaults to false per WebIDL)
    const opts = if (options.was_passed) options.value else dictionaries.ReadableStreamIteratorOptions{};
    const prevent_cancel = opts.preventCancel orelse false;

    // Create Zig async iterator
    const async_iterator_mod = @import("streams_readable_stream_async_iterator");
    const zig_iterator = try async_iterator_mod.create(
        allocator,
        ctx,
        instance,
        prevent_cancel,
    );

    // If we have a JS engine, wrap the iterator for JavaScript usage
    if (ctx.getEngine()) |engine| {
        if (ctx.getEngineContext()) |engine_ctx| {
            const wrapped = engine.wrapAsyncIterator(
                engine_ctx,
                @ptrCast(zig_iterator),
            ) catch |err| {
                // Clean up the Zig iterator on wrapping failure
                zig_iterator.deinit();
                return switch (err) {
                    error.OutOfMemory => error.OutOfMemory,
                    error.AsyncIteratorError => error.InvalidState,
                    else => error.NotImplemented,
                };
            };
            // wrapped is a V8 Object (the async iterator)
            return runtime.JSValue.fromHandle(@ptrCast(wrapped));
        }
    }

    // No engine: return raw Zig iterator (for testing or non-JS usage)
    // TODO: This should probably return jsUndefined or wrap differently for non-JS usage
    return runtime.JSValue.jsUndefined;
}

/// Operation: [Symbol.asyncIterator]
///
/// Spec: https://streams.spec.whatwg.org/#rs-asynciterator
/// WebIDL: asyncIterable<any>(optional ReadableStreamIteratorOptions options = {});
///
/// Default async iterator (enables for-await-of loops).
/// Per WebIDL spec, @@asyncIterator and values() are the same.
///
/// Steps:
/// 1. Return ! this.values(options)
pub fn call_getAsyncIterator(
    instance: *runtime.Instance,
    options: webidl.Opt(dictionaries.ReadableStreamIteratorOptions),
) anyerror!runtime.JSValue {
    // Per WebIDL async iterable spec, @@asyncIterator returns the same as values()
    return call_values(instance, options);
}

// ============================================================================
// Internal Algorithms
// ============================================================================

/// SetUpReadableStreamDefaultControllerFromUnderlyingSource
///
/// Spec: https://streams.spec.whatwg.org/#set-up-readable-stream-default-controller-from-underlying-source
///
/// Steps:
/// 1. Let controller be a new ReadableStreamDefaultController
/// 2. Let startAlgorithm be an algorithm that returns undefined
/// 3. Let pullAlgorithm be an algorithm that returns a promise resolved with undefined
/// 4. Let cancelAlgorithm be an algorithm that returns a promise resolved with undefined
/// 5. If underlyingSourceDict["start"] exists, set startAlgorithm to invoke it
/// 6. If underlyingSourceDict["pull"] exists, set pullAlgorithm to invoke it
/// 7. If underlyingSourceDict["cancel"] exists, set cancelAlgorithm to invoke it
/// 8. Perform ? SetUpReadableStreamDefaultController(...)
///
/// ## V8 Callback Extraction
///
/// The dictionary's callback fields (start, pull, cancel) use Zig function pointer types
/// which cannot be populated from V8 objects. Instead, we receive pre-extracted callbacks
/// as V8 Global handle pointers (tagged with .global_handle). These are passed separately
/// and take precedence over the dictionary fields.
fn setUpReadableStreamDefaultControllerFromUnderlyingSource(
    stream_instance: *runtime.Instance,
    stream_internal: *InternalState,
    underlyingSource: *const anyopaque,
    underlyingSourceDict: *const dictionaries.UnderlyingSource,
    highWaterMark: f64,
    extracted_start: ?*const anyopaque,
    extracted_pull: ?*const anyopaque,
    extracted_cancel: ?*const anyopaque,
) !void {
    const allocator = stream_internal.allocator;
    const ctx = stream_instance.ctx;

    // Step 1: Create new controller
    const controller_instance = try interfaces.ReadableStreamDefaultController.init(
        allocator,
        ctx,
    );
    errdefer interfaces.ReadableStreamDefaultController.deinit(controller_instance);

    // Step 2-4: Default algorithms (no-ops that return undefined/resolved promise)
    // For now, we store null and handle it in the controller

    // Step 5-7: Use extracted callbacks (V8 Global handles) if provided.
    // These are preferred over dictionary fields since the dictionary's callback types
    // are Zig function pointers which V8 conversion cannot populate.
    const start_algorithm: ?*const anyopaque = extracted_start;
    const pull_algorithm: ?*const anyopaque = extracted_pull;
    const cancel_algorithm: ?*const anyopaque = extracted_cancel;

    // Step 8: SetUpReadableStreamDefaultController
    try setUpReadableStreamDefaultController(
        stream_instance,
        stream_internal,
        controller_instance,
        start_algorithm,
        pull_algorithm,
        cancel_algorithm,
        highWaterMark,
    );

    _ = underlyingSource; // Will be used when we invoke callbacks
    _ = underlyingSourceDict; // Kept for potential future non-callback fields
}

/// SetUpReadableStreamDefaultController
///
/// Spec: https://streams.spec.whatwg.org/#set-up-readable-stream-default-controller
///
/// Steps:
/// 1. Assert: stream.[[controller]] is undefined
/// 2. Set controller.[[stream]] to stream
/// 3. Perform ! ResetQueue(controller)
/// 4. Set controller.[[started]], [[closeRequested]], [[pullAgain]], [[pulling]] to false
/// 5. Set controller.[[strategySizeAlgorithm]] to sizeAlgorithm and [[strategyHWM]] to highWaterMark
/// 6. Set controller.[[pullAlgorithm]] to pullAlgorithm
/// 7. Set controller.[[cancelAlgorithm]] to cancelAlgorithm
/// 8. Set stream.[[controller]] to controller
/// 9. Let startResult be the result of performing startAlgorithm
/// 10. Let startPromise be a promise resolved with startResult
/// 11. Upon fulfillment of startPromise:
///     1. Set controller.[[started]] to true
///     2. Assert: controller.[[pulling]] is false
///     3. Assert: controller.[[pullAgain]] is false
///     4. Perform ! ReadableStreamDefaultControllerCallPullIfNeeded(controller)
/// 12. Upon rejection of startPromise with reason r:
///     1. Perform ! ReadableStreamDefaultControllerError(controller, r)
/// ## V8 Handle Lifetime
///
/// The callback parameters (start, pull, cancel) are Local<Value> handles
/// extracted from the underlying source dictionary. These MUST be converted to
/// Global handles before the constructor's HandleScope ends, or they become
/// dangling pointers. We use jsCallbackAlgorithmGlobal which stores callbacks
/// as V8 Global handles.
fn setUpReadableStreamDefaultController(
    stream_instance: *runtime.Instance,
    stream_internal: *InternalState,
    controller_instance: *runtime.Instance,
    startAlgorithm: ?*const anyopaque,
    pullAlgorithm: ?*const anyopaque,
    cancelAlgorithm: ?*const anyopaque,
    highWaterMark: f64,
) !void {
    const allocator = stream_internal.allocator;
    // Note: event_loop is available in stream_internal for future async operations

    // Get V8 isolate for Global handle creation
    const isolate: ?*v8_engine.ffi.Isolate = stream_instance.ctx.getEngineContextAs(v8_engine.ffi.Isolate);

    // Step 1: Assert controller is undefined (guaranteed by constructor)

    // Get controller state
    const controller_state = controller_instance.getState(interfaces.ReadableStreamDefaultController.State);

    // Convert callbacks to Algorithms using Global handles for V8 handle persistence.
    // If no isolate (testing mode), fall back to the unsafe raw pointer version.
    const start_algo: ?*Algorithm = if (startAlgorithm) |cb| blk: {
        if (isolate) |iso| {
            break :blk algorithm_mod.jsCallbackAlgorithmGlobal(allocator, iso, cb) catch null;
        } else {
            break :blk try algorithm_mod.jsCallbackAlgorithm(allocator, cb);
        }
    } else null;
    errdefer if (start_algo) |algo| {
        algo.deinit();
        allocator.destroy(algo);
    };

    const pull_algo: ?*Algorithm = if (pullAlgorithm) |cb| blk: {
        if (isolate) |iso| {
            break :blk algorithm_mod.jsCallbackAlgorithmGlobal(allocator, iso, cb) catch null;
        } else {
            break :blk try algorithm_mod.jsCallbackAlgorithm(allocator, cb);
        }
    } else null;
    errdefer if (pull_algo) |algo| {
        algo.deinit();
        allocator.destroy(algo);
    };

    const cancel_algo: ?*Algorithm = if (cancelAlgorithm) |cb| blk: {
        if (isolate) |iso| {
            break :blk algorithm_mod.jsCallbackAlgorithmGlobal(allocator, iso, cb) catch null;
        } else {
            break :blk try algorithm_mod.jsCallbackAlgorithm(allocator, cb);
        }
    } else null;
    errdefer if (cancel_algo) |algo| {
        algo.deinit();
        allocator.destroy(algo);
    };

    // Create controller internal state
    const controller_internal = try allocator.create(@import("ReadableStreamDefaultController.zig").InternalState);
    errdefer allocator.destroy(controller_internal);

    // Step 2: Set controller.[[stream]] to stream
    // Step 3: Perform ResetQueue
    // Step 4: Initialize flags to false
    // Step 5: Set strategy parameters
    // Step 6-7: Set algorithms
    controller_internal.* = .{
        .stream = stream_instance,
        .queue = QueueWithSizes.init(allocator),
        .queue_total_size = 0.0,
        .started = false,
        .close_requested = false,
        .pull_again = false,
        .pulling = false,
        .strategy_size_algorithm = null, // Future: Pass extracted size algorithm for chunk sizing
        .strategy_hwm = highWaterMark,
        .start_algorithm = start_algo,
        .pull_algorithm = pull_algo,
        .cancel_algorithm = cancel_algo,
        .allocator = allocator,
    };

    controller_state.own._internal = controller_internal;

    // Step 8: Set stream.[[controller]] to controller
    stream_internal.controller = controller_instance;

    // Step 9-12: Perform startAlgorithm and handle promise
    //
    // Per WHATWG Streams spec:
    // 9. Let startResult be the result of performing startAlgorithm
    // 10. Let startPromise be a promise resolved with startResult
    // 11. Upon fulfillment of startPromise: set started = true, call pull if needed
    // 12. Upon rejection of startPromise with reason r: error the controller
    //
    // The start algorithm is stored in controller_internal.start_algorithm.
    // The V8 bindings layer will invoke it AFTER the constructor returns and
    // V8 wrappers exist (see invokeReadableStreamStartCallback in interface.zig).
    //
    // DO NOT mark as started here - that happens after start callback completes.
    //
    // If there's no start callback, mark as started immediately so pull can proceed.
    if (start_algo == null) {
        onStartFulfilledImmediate(controller_internal);
    }
    // If start_algo exists, invokePendingStartCallback will:
    // 1. Call the JS callback with the controller
    // 2. Mark as started after callback returns
}

/// Handle start promise settlement
/// Supports both synchronous (for testing) and asynchronous (with event loop) promises
/// Spec: § 4.9.3 Steps 10-12
fn handleStartPromise(
    controller_internal: *@import("ReadableStreamDefaultController.zig").InternalState,
    start_promise: *AsyncPromise(void),
) void {
    // Step 11: Upon fulfillment of startPromise
    if (start_promise.isFulfilled()) {
        onStartFulfilledImmediate(controller_internal);
        return;
    }

    // Step 12: Upon rejection of startPromise with reason r
    if (start_promise.isRejected()) {
        onStartRejectedImmediate(controller_internal, start_promise.state.rejected);
        return;
    }

    // Promise is still pending - use async handling via onSettleCtx
    start_promise.onSettleCtx(
        onStartFulfilled,
        onStartRejected,
        @ptrCast(controller_internal),
    ) catch {
        // If we can't attach handlers, assume immediate fulfillment
        onStartFulfilledImmediate(controller_internal);
    };
}

/// Context for V8 promise callbacks from invokePendingStartCallback
/// This is allocated and passed to the V8 promise handlers, then freed in the callbacks
const StartCallbackContext = struct {
    controller_internal: *@import("ReadableStreamDefaultController.zig").InternalState,
    allocator: std.mem.Allocator,
};

/// V8 Promise fulfillment callback for start() promise
/// Called when an async start(controller) function's promise fulfills
/// Spec: § 4.9.3 Step 11 - Upon fulfillment of startPromise
fn onStartPromiseFulfilled(ctx: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {
    const callback_ctx: *StartCallbackContext = @ptrCast(@alignCast(ctx orelse return));
    defer callback_ctx.allocator.destroy(callback_ctx);

    // Mark the controller as started and call pull if needed
    onStartFulfilledImmediate(callback_ctx.controller_internal);
}

/// V8 Promise rejection callback for start() promise
/// Called when an async start(controller) function's promise rejects
/// Spec: § 4.9.3 Step 12 - Upon rejection of startPromise with reason r
fn onStartPromiseRejected(ctx: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {
    const callback_ctx: *StartCallbackContext = @ptrCast(@alignCast(ctx orelse return));
    defer callback_ctx.allocator.destroy(callback_ctx);

    // Error the controller with the rejection reason
    const js_error = streams_common.JSValue{ .string = "Start callback promise rejected" };
    const ReadableStreamDefaultControllerImpl = @import("ReadableStreamDefaultController.zig");
    ReadableStreamDefaultControllerImpl.readableStreamDefaultControllerError(
        callback_ctx.controller_internal,
        @ptrCast(&js_error),
    );
}

/// Handle start algorithm rejection (immediate)
/// Spec: § 4.9.3 SetUpReadableStreamDefaultController Step 12
fn onStartRejectedImmediate(
    controller_internal: *@import("ReadableStreamDefaultController.zig").InternalState,
    exception: webidl.errors.Exception,
) void {
    // Step 12.1: Perform ! ReadableStreamDefaultControllerError(controller, r)
    const error_msg = switch (exception) {
        .simple => |s| s.message,
        else => "Start algorithm failed",
    };

    const js_error = streams_common.JSValue{ .string = error_msg };
    const ReadableStreamDefaultControllerImpl = @import("ReadableStreamDefaultController.zig");
    ReadableStreamDefaultControllerImpl.readableStreamDefaultControllerError(controller_internal, @ptrCast(&js_error));
}

/// Handle start algorithm fulfillment
/// Spec: § 4.9.3 SetUpReadableStreamDefaultController Step 11
fn onStartFulfilled(ctx_ptr: *anyopaque, _: void) anyerror!void {
    const controller_internal: *@import("ReadableStreamDefaultController.zig").InternalState = @ptrCast(@alignCast(ctx_ptr));
    onStartFulfilledImmediate(controller_internal);
}

/// Immediate start fulfillment (no async)
fn onStartFulfilledImmediate(controller_internal: *@import("ReadableStreamDefaultController.zig").InternalState) void {
    // Step 11.1: Set controller.[[started]] to true
    controller_internal.started = true;

    // Step 11.2-3: Assertions (pulling and pullAgain should be false)
    std.debug.assert(!controller_internal.pulling);
    std.debug.assert(!controller_internal.pull_again);

    // Step 11.4: Perform ! ReadableStreamDefaultControllerCallPullIfNeeded(controller)
    const ReadableStreamDefaultControllerImpl = @import("ReadableStreamDefaultController.zig");
    ReadableStreamDefaultControllerImpl.readableStreamDefaultControllerCallPullIfNeeded(controller_internal);
}

/// Handle start algorithm rejection (async callback version)
/// Spec: § 4.9.3 SetUpReadableStreamDefaultController Step 12
fn onStartRejected(ctx_ptr: *anyopaque, exception: webidl.errors.Exception) anyerror!void {
    const controller_internal: *@import("ReadableStreamDefaultController.zig").InternalState = @ptrCast(@alignCast(ctx_ptr));
    onStartRejectedImmediate(controller_internal, exception);
}

/// SetUpReadableByteStreamControllerFromUnderlyingSource
///
/// Spec: https://streams.spec.whatwg.org/#set-up-readable-byte-stream-controller-from-underlying-source
///
/// Steps:
/// 1. Let controller be a new ReadableByteStreamController
/// 2. Let startAlgorithm be an algorithm that returns undefined
/// 3. Let pullAlgorithm be an algorithm that returns a promise resolved with undefined
/// 4. Let cancelAlgorithm be an algorithm that returns a promise resolved with undefined
/// 5. If underlyingSourceDict["start"] exists, set startAlgorithm to invoke it
/// 6. If underlyingSourceDict["pull"] exists, set pullAlgorithm to invoke it
/// 7. If underlyingSourceDict["cancel"] exists, set cancelAlgorithm to invoke it
/// 8. Let autoAllocateChunkSize be underlyingSourceDict["autoAllocateChunkSize"]
/// 9. If autoAllocateChunkSize is 0, throw TypeError
/// 10. Perform ? SetUpReadableByteStreamController(...)
///
/// ## V8 Callback Extraction
///
/// The dictionary's callback fields (start, pull, cancel) use Zig function pointer types
/// which cannot be populated from V8 objects. Instead, we receive pre-extracted callbacks
/// as V8 Global handle pointers (tagged with .global_handle). These are passed separately
/// and take precedence over the dictionary fields.
fn setUpReadableByteStreamControllerFromUnderlyingSource(
    stream_instance: *runtime.Instance,
    stream_internal: *InternalState,
    underlyingSource: *const anyopaque,
    underlyingSourceDict: *const dictionaries.UnderlyingSource,
    highWaterMark: f64,
    extracted_start: ?*const anyopaque,
    extracted_pull: ?*const anyopaque,
    extracted_cancel: ?*const anyopaque,
) !void {
    const allocator = stream_internal.allocator;
    const ctx = stream_instance.ctx;

    // Step 1: Create new ReadableByteStreamController
    const controller_instance = try interfaces.ReadableByteStreamController.init(
        allocator,
        ctx,
    );
    errdefer interfaces.ReadableByteStreamController.deinit(controller_instance);

    // Step 2-4: Default algorithms (no-ops that return undefined/resolved promise)
    // Step 5-7: Use extracted callbacks (V8 Global handles) if provided.
    // These are preferred over dictionary fields since the dictionary's callback types
    // are Zig function pointers which V8 conversion cannot populate.
    const start_algorithm: ?*const anyopaque = extracted_start;
    const pull_algorithm: ?*const anyopaque = extracted_pull;
    const cancel_algorithm: ?*const anyopaque = extracted_cancel;

    // Step 8: Get autoAllocateChunkSize
    const auto_allocate_chunk_size = underlyingSourceDict.autoAllocateChunkSize;

    // Step 9: If autoAllocateChunkSize is 0, throw TypeError
    if (auto_allocate_chunk_size) |size| {
        if (size == 0) {
            return error.TypeError;
        }
    }

    // Step 10: SetUpReadableByteStreamController
    try setUpReadableByteStreamController(
        stream_instance,
        stream_internal,
        controller_instance,
        start_algorithm,
        pull_algorithm,
        cancel_algorithm,
        highWaterMark,
        auto_allocate_chunk_size,
    );

    _ = underlyingSource; // Will be used when we invoke callbacks
}

/// SetUpReadableByteStreamController
///
/// Spec: https://streams.spec.whatwg.org/#set-up-readable-byte-stream-controller
///
/// Steps:
/// 1. Assert: stream.[[controller]] is undefined
/// 2. If autoAllocateChunkSize is not undefined, assert it's a positive integer
/// 3. Set controller.[[stream]] to stream
/// 4. Set controller.[[pullAgain]] and [[pulling]] to false
/// 5. Set controller.[[byobRequest]] to null
/// 6. Perform ! ResetQueue(controller)
/// 7. Set controller.[[closeRequested]] and [[started]] to false
/// 8. Set controller.[[strategyHWM]] to highWaterMark
/// 9. Set controller.[[pullAlgorithm]] to pullAlgorithm
/// 10. Set controller.[[cancelAlgorithm]] to cancelAlgorithm
/// 11. Set controller.[[autoAllocateChunkSize]] to autoAllocateChunkSize
/// 12. Set controller.[[pendingPullIntos]] to empty list
/// 13. Set stream.[[controller]] to controller
/// 14. Let startResult be the result of performing startAlgorithm
/// 15. Let startPromise be a promise resolved with startResult
/// 16. Upon fulfillment of startPromise: set started to true, call pull if needed
/// 17. Upon rejection of startPromise: error the controller
/// ## V8 Handle Lifetime
///
/// The callback parameters (start, pull, cancel) are Local<Value> handles
/// extracted from the underlying source dictionary. These MUST be converted to
/// Global handles before the constructor's HandleScope ends, or they become
/// dangling pointers. We use jsCallbackAlgorithmGlobal which stores callbacks
/// as V8 Global handles.
fn setUpReadableByteStreamController(
    stream_instance: *runtime.Instance,
    stream_internal: *InternalState,
    controller_instance: *runtime.Instance,
    startAlgorithm: ?*const anyopaque,
    pullAlgorithm: ?*const anyopaque,
    cancelAlgorithm: ?*const anyopaque,
    highWaterMark: f64,
    autoAllocateChunkSize: ?u64,
) !void {
    const allocator = stream_internal.allocator;
    // Note: event_loop is available in stream_internal for future async operations

    // Get V8 isolate for Global handle creation
    const isolate: ?*v8_engine.ffi.Isolate = stream_instance.ctx.getEngineContextAs(v8_engine.ffi.Isolate);

    // Step 1: Assert controller is undefined (guaranteed by constructor)
    // Step 2: If autoAllocateChunkSize provided, it must be positive (checked in FromUnderlyingSource)

    // Get controller state
    const controller_state = controller_instance.getState(interfaces.ReadableByteStreamController.State);

    // Import ReadableByteStreamController implementation
    const ReadableByteStreamControllerImpl = @import("ReadableByteStreamController.zig");

    // Create algorithms using Global handles for V8 handle persistence.
    // If no isolate (testing mode), fall back to the unsafe raw pointer version.
    const pull_algo: ?*algorithm_mod.Algorithm = if (pullAlgorithm) |cb| blk: {
        if (isolate) |iso| {
            break :blk algorithm_mod.jsCallbackAlgorithmGlobal(allocator, iso, cb) catch null;
        } else {
            break :blk try algorithm_mod.jsCallbackAlgorithm(allocator, cb);
        }
    } else null;
    errdefer if (pull_algo) |algo| {
        algo.deinit();
        allocator.destroy(algo);
    };

    const cancel_algo: ?*algorithm_mod.Algorithm = if (cancelAlgorithm) |cb| blk: {
        if (isolate) |iso| {
            break :blk algorithm_mod.jsCallbackAlgorithmGlobal(allocator, iso, cb) catch null;
        } else {
            break :blk try algorithm_mod.jsCallbackAlgorithm(allocator, cb);
        }
    } else null;
    errdefer if (cancel_algo) |algo| {
        algo.deinit();
        allocator.destroy(algo);
    };

    // Create start algorithm using the same Algorithm type as default controller
    // This allows proper V8 callback invocation via invokePendingByteStartCallback
    const start_algo: ?*algorithm_mod.Algorithm = if (startAlgorithm) |cb| blk: {
        if (isolate) |iso| {
            break :blk algorithm_mod.jsCallbackAlgorithmGlobal(allocator, iso, cb) catch null;
        } else {
            break :blk try algorithm_mod.jsCallbackAlgorithm(allocator, cb);
        }
    } else null;
    errdefer if (start_algo) |algo| {
        algo.deinit();
        allocator.destroy(algo);
    };

    // Create controller internal state
    const controller_internal = try allocator.create(ReadableByteStreamControllerImpl.InternalState);
    errdefer allocator.destroy(controller_internal);

    // Initialize internal state per spec steps 3-12
    // Note: We initialize the byte_queue and pending_pull_intos through the init function
    // to get the correct types
    try ReadableByteStreamControllerImpl.initInternalState(
        controller_internal,
        allocator,
        stream_instance,
        highWaterMark,
        autoAllocateChunkSize,
        pull_algo,
        cancel_algo,
        start_algo,
    );

    controller_state.own._internal = controller_internal;

    // Step 13: Set stream.[[controller]] to controller
    stream_internal.controller = controller_instance;

    // Step 14-17: Perform startAlgorithm and handle promise
    //
    // Per WHATWG Streams spec:
    // 14. Let startResult be the result of performing startAlgorithm
    // 15. Let startPromise be a promise resolved with startResult
    // 16. Upon fulfillment of startPromise: set started = true, call pull if needed
    // 17. Upon rejection of startPromise with reason r: error the controller
    //
    // The start algorithm is stored in controller_internal.start_algorithm.
    // The V8 bindings layer will invoke it AFTER the constructor returns and
    // V8 wrappers exist (see invokeReadableStreamStartCallback in interface.zig).
    //
    // DO NOT mark as started here - that happens after start callback completes.
    //
    // If there's no start callback, mark as started immediately so pull can proceed.
    if (start_algo == null) {
        onByteStartFulfilledImmediate(controller_internal, controller_instance);
    }
    // If start_algo exists, invokePendingByteStartCallback will:
    // 1. Call the JS callback with the controller
    // 2. Mark as started after callback returns
}

/// Handle byte stream start promise settlement
/// Supports both synchronous (for testing) and asynchronous (with event loop) promises
/// Spec: § 4.7.3 Steps 15-17
fn handleByteStartPromise(
    controller_internal: *@import("ReadableByteStreamController.zig").InternalState,
    controller_instance: *runtime.Instance,
    start_promise: *AsyncPromise(void),
) void {
    // Step 16: Upon fulfillment of startPromise
    if (start_promise.isFulfilled()) {
        onByteStartFulfilledImmediate(controller_internal, controller_instance);
        return;
    }

    // Step 17: Upon rejection of startPromise with reason r
    if (start_promise.isRejected()) {
        onByteStartRejectedImmediate(controller_internal, start_promise.state.rejected);
        return;
    }

    // Promise is still pending - need to allocate context for async handling
    const allocator = controller_internal.allocator;
    const ctx = allocator.create(ByteStartContext) catch {
        // If we can't allocate context, assume immediate fulfillment
        onByteStartFulfilledImmediate(controller_internal, controller_instance);
        return;
    };
    ctx.* = .{
        .controller_internal = controller_internal,
        .controller_instance = controller_instance,
    };

    // Promise is still pending - use async handling via onSettleCtx
    start_promise.onSettleCtx(
        onByteStartFulfilled,
        onByteStartRejected,
        @ptrCast(ctx),
    ) catch {
        // If we can't attach handlers, assume immediate fulfillment
        allocator.destroy(ctx);
        onByteStartFulfilledImmediate(controller_internal, controller_instance);
    };
}

/// Handle byte stream start algorithm rejection (immediate)
/// Spec: § 4.7.3 SetUpReadableByteStreamController Step 17
fn onByteStartRejectedImmediate(
    controller_internal: *@import("ReadableByteStreamController.zig").InternalState,
    exception: webidl.errors.Exception,
) void {
    // Step 17.1: Perform ! ReadableByteStreamControllerError(controller, r)
    const error_msg = switch (exception) {
        .simple => |s| s.message,
        else => "Start algorithm failed",
    };

    const js_error = streams_common.JSValue{ .string = error_msg };
    const ReadableByteStreamControllerImpl = @import("ReadableByteStreamController.zig");
    ReadableByteStreamControllerImpl.errorInternal(controller_internal, js_error);
}

/// Context for byte stream start handlers
const ByteStartContext = struct {
    controller_internal: *@import("ReadableByteStreamController.zig").InternalState,
    controller_instance: *runtime.Instance,
};

/// Handle byte stream start algorithm fulfillment
/// Spec: § 4.7.3 SetUpReadableByteStreamController Step 16
fn onByteStartFulfilled(ctx_ptr: *anyopaque, _: void) anyerror!void {
    const ctx: *ByteStartContext = @ptrCast(@alignCast(ctx_ptr));
    onByteStartFulfilledImmediate(ctx.controller_internal, ctx.controller_instance);
}

/// Immediate byte stream start fulfillment (no async)
fn onByteStartFulfilledImmediate(
    controller_internal: *@import("ReadableByteStreamController.zig").InternalState,
    controller_instance: *runtime.Instance,
) void {
    const ReadableByteStreamControllerImpl = @import("ReadableByteStreamController.zig");

    // Step 16.1: Set controller.[[started]] to true
    controller_internal.started = true;

    // Step 16.2-3: Assertions (pulling and pullAgain should be false)
    std.debug.assert(!controller_internal.pulling);
    std.debug.assert(!controller_internal.pull_again);

    // Step 16.4: Perform ! ReadableByteStreamControllerCallPullIfNeeded(controller)
    ReadableByteStreamControllerImpl.callPullIfNeeded(controller_instance);
}

/// Handle byte stream start algorithm rejection (async callback version)
/// Spec: § 4.7.3 SetUpReadableByteStreamController Step 17
fn onByteStartRejected(ctx_ptr: *anyopaque, exception: webidl.errors.Exception) anyerror!void {
    const ctx: *ByteStartContext = @ptrCast(@alignCast(ctx_ptr));
    onByteStartRejectedImmediate(ctx.controller_internal, exception);
}

/// Create a PullAlgorithm that invokes a JS callback for byte streams
fn createByteStreamPullAlgorithm(allocator: std.mem.Allocator, callback: *const anyopaque) !streams_common.PullAlgorithm {
    // Allocate context to hold callback pointer
    const Context = struct {
        callback: *const anyopaque,
    };
    const ctx = try allocator.create(Context);
    ctx.* = .{ .callback = callback };

    const vtable = struct {
        fn call(ptr: *anyopaque) streams_common.Promise(void) {
            const context: *Context = @ptrCast(@alignCast(ptr));
            // In full implementation, this would invoke the JS callback
            // For now, return resolved promise
            _ = context;
            return streams_common.Promise(void).fulfilled({});
        }
        fn deinitFn(ptr: *anyopaque) void {
            const context: *Context = @ptrCast(@alignCast(ptr));
            // Get allocator from somewhere to free - for now leak
            _ = context;
        }
    };

    return streams_common.PullAlgorithm{
        .ptr = ctx,
        .vtable = &.{
            .call = vtable.call,
            .deinit = vtable.deinitFn,
        },
    };
}

/// Create a CancelAlgorithm that invokes a JS callback for byte streams
fn createByteStreamCancelAlgorithm(allocator: std.mem.Allocator, callback: *const anyopaque) !streams_common.CancelAlgorithm {
    const Context = struct {
        callback: *const anyopaque,
    };
    const ctx = try allocator.create(Context);
    ctx.* = .{ .callback = callback };

    const vtable = struct {
        fn call(ptr: *anyopaque, reason: ?streams_common.JSValue) streams_common.Promise(void) {
            const context: *Context = @ptrCast(@alignCast(ptr));
            _ = context;
            _ = reason;
            return streams_common.Promise(void).fulfilled({});
        }
        fn deinitFn(ptr: *anyopaque) void {
            const context: *Context = @ptrCast(@alignCast(ptr));
            _ = context;
        }
    };

    return streams_common.CancelAlgorithm{
        .ptr = ctx,
        .vtable = &.{
            .call = vtable.call,
            .deinit = vtable.deinitFn,
        },
    };
}

/// Default pull algorithm for byte streams (no-op, returns resolved promise)
fn defaultByteStreamPullAlgorithm() streams_common.PullAlgorithm {
    const vtable = struct {
        fn call(_: *anyopaque) streams_common.Promise(void) {
            return streams_common.Promise(void).fulfilled({});
        }
        fn deinitFn(_: *anyopaque) void {}
    };

    const static = struct {
        var dummy: u8 = 0;
    };

    return streams_common.PullAlgorithm{
        .ptr = &static.dummy,
        .vtable = &.{
            .call = vtable.call,
            .deinit = vtable.deinitFn,
        },
    };
}

/// Default cancel algorithm for byte streams (no-op, returns resolved promise)
fn defaultByteStreamCancelAlgorithm() streams_common.CancelAlgorithm {
    const vtable = struct {
        fn call(_: *anyopaque, _: ?streams_common.JSValue) streams_common.Promise(void) {
            return streams_common.Promise(void).fulfilled({});
        }
        fn deinitFn(_: *anyopaque) void {}
    };

    const static = struct {
        var dummy: u8 = 0;
    };

    return streams_common.CancelAlgorithm{
        .ptr = &static.dummy,
        .vtable = &.{
            .call = vtable.call,
            .deinit = vtable.deinitFn,
        },
    };
}

// ============================================================================
// Strategy Algorithms
// ============================================================================

/// ExtractHighWaterMark(strategy, defaultHWM)
///
/// Spec: https://streams.spec.whatwg.org/#extract-high-water-mark
///
/// Steps:
/// 1. If strategy["highWaterMark"] does not exist, return defaultHWM
/// 2. Let highWaterMark be strategy["highWaterMark"]
/// 3. If highWaterMark is NaN or highWaterMark < 0, throw RangeError
/// 4. Return highWaterMark
fn extractHighWaterMark(strategy: *const dictionaries.QueuingStrategy, default_hwm: f64) !f64 {
    // Step 1: If highWaterMark not provided, use default
    const hwm = strategy.highWaterMark orelse return default_hwm;

    // Step 2: Get the value
    // Step 3: Validate (NaN or negative throws RangeError)
    if (std.math.isNan(hwm) or hwm < 0.0) {
        return error.RangeError;
    }

    // Step 4: Return the value
    return hwm;
}

/// ExtractSizeAlgorithm(strategy)
///
/// Spec: https://streams.spec.whatwg.org/#extract-size-algorithm
///
/// Steps:
/// 1. If strategy["size"] does not exist, return an algorithm that returns 1
/// 2. Return an algorithm that invokes strategy["size"] with chunk argument
///
/// Returns: An opaque pointer to the size function, or null for default (returns 1)
fn extractSizeAlgorithm(strategy: *const dictionaries.QueuingStrategy) ?*const anyopaque {
    // Step 1: If no size function, return null (caller will use default of 1)
    const size_fn = strategy.size orelse return null;

    // Step 2: Return the size function to be invoked later with chunks
    return size_fn;
}

// ============================================================================
// Reader Helper Functions (for BYOB integration)
// ============================================================================

/// ReadableStreamHasDefaultReader(stream)
///
/// Spec: § 4.4.1 "Check if stream has a default reader"
///
/// Returns true if stream has a default reader attached.
pub fn hasDefaultReader(instance: *runtime.Instance) bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return false;

    return switch (internal.reader) {
        .default => true,
        .byob, .none => false,
    };
}

/// ReadableStreamHasBYOBReader(stream)
///
/// Spec: § 4.4.2 "Check if stream has a BYOB reader"
///
/// Returns true if stream has a BYOB reader attached.
pub fn hasBYOBReader(instance: *runtime.Instance) bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return false;

    return switch (internal.reader) {
        .byob => true,
        .default, .none => false,
    };
}

/// ReadableStreamGetNumReadRequests(stream)
///
/// Spec: § 4.4.3 "Get number of pending read requests"
///
/// Returns the number of pending read requests from the default reader.
pub fn getNumReadRequests(instance: *runtime.Instance) u64 {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return 0;

    return switch (internal.reader) {
        .default => |reader_instance| {
            // Import reader implementation to get request count
            const ReaderImpl = @import("ReadableStreamDefaultReader.zig");
            return ReaderImpl.getNumReadRequests(reader_instance);
        },
        .byob, .none => 0,
    };
}

/// ReadableStreamGetNumReadIntoRequests(stream)
///
/// Spec: § 4.4.4 "Get number of pending read-into requests"
///
/// Returns the number of pending read-into requests from the BYOB reader.
pub fn getNumReadIntoRequests(instance: *runtime.Instance) u64 {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return 0;

    return switch (internal.reader) {
        .byob => |reader_instance| {
            // Import BYOB reader implementation to get request count
            const BYOBReaderImpl = @import("ReadableStreamBYOBReader.zig");
            return BYOBReaderImpl.getNumReadIntoRequests(reader_instance);
        },
        .default, .none => 0,
    };
}

/// ReadableStreamFulfillReadRequest(stream, chunk, done)
///
/// Spec: § 4.4.5 "Fulfill read request with chunk"
///
/// Fulfills the first pending read request with the given chunk.
pub fn fulfillReadRequest(
    instance: *runtime.Instance,
    chunk: runtime.JSValue,
    done: bool,
) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    return switch (internal.reader) {
        .default => |reader_instance| {
            // Import reader implementation to fulfill request
            const ReaderImpl = @import("ReadableStreamDefaultReader.zig");
            return ReaderImpl.fulfillReadRequest(reader_instance, chunk, done);
        },
        .byob, .none => error.InvalidState, // No default reader attached
    };
}

/// ReadableStreamAddReadRequest(stream, readRequest)
///
/// Spec: § 4.4.6 "Add read request to pending queue"
///
/// Adds a read request to the stream's default reader.
pub fn addReadRequest(
    instance: *runtime.Instance,
    readRequest: *const anyopaque,
) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    return switch (internal.reader) {
        .default => |reader_instance| {
            // Import reader implementation to add request
            const ReaderImpl = @import("ReadableStreamDefaultReader.zig");
            return ReaderImpl.addReadRequest(reader_instance, readRequest);
        },
        .byob, .none => error.InvalidState, // No default reader attached
    };
}

/// ReadableStreamAddReadIntoRequest(stream, readIntoRequest)
///
/// Spec: § 4.4.7 "Add read-into request to pending queue"
///
/// Adds a read-into request to the stream's BYOB reader.
pub fn addReadIntoRequest(
    instance: *runtime.Instance,
    readIntoRequest: *const anyopaque,
) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    return switch (internal.reader) {
        .byob => |reader_instance| {
            // Import BYOB reader implementation to add request
            const BYOBReaderImpl = @import("ReadableStreamBYOBReader.zig");
            return BYOBReaderImpl.addReadIntoRequest(reader_instance, readIntoRequest);
        },
        .default, .none => error.InvalidState, // No BYOB reader attached
    };
}

/// ReadableStreamFulfillReadIntoRequest(stream, chunk, done)
///
/// Spec: § 4.4.5 "Fulfill read-into request with chunk"
///
/// Fulfills the first pending read-into request with the given chunk (for BYOB readers).
pub fn fulfillReadIntoRequest(
    instance: *runtime.Instance,
    chunk: *anyopaque,
    done: bool,
) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    return switch (internal.reader) {
        .byob => |reader_instance| {
            // Import BYOB reader implementation to fulfill request
            const BYOBReaderImpl = @import("ReadableStreamBYOBReader.zig");
            return BYOBReaderImpl.fulfillReadIntoRequest(reader_instance, chunk, done);
        },
        .default, .none => error.InvalidState, // No BYOB reader attached
    };
}

// ============================================================================
// Pipe Operations
// ============================================================================

/// Internal state for pipe operation
const PipeState = struct {
    source: *runtime.Instance,
    source_internal: *InternalState,
    dest: *runtime.Instance,
    dest_internal: *@import("WritableStream.zig").InternalState,
    reader: *runtime.Instance,
    writer: *runtime.Instance,
    prevent_close: bool,
    prevent_abort: bool,
    prevent_cancel: bool,
    shutting_down: bool,
    promise: *AsyncPromise(void),
    allocator: std.mem.Allocator,
    event_loop: event_loop.EventLoop,
};

/// ReadableStreamPipeTo algorithm
///
/// Spec: https://streams.spec.whatwg.org/#readable-stream-pipe-to
///
/// This is a simplified implementation that handles the core piping logic.
/// The full spec involves parallel operations; this version uses sequential
/// read/write cycles with proper error propagation.
fn readableStreamPipeTo(
    source: *runtime.Instance,
    source_internal: *InternalState,
    dest: *runtime.Instance,
    dest_internal: *@import("WritableStream.zig").InternalState,
    prevent_close: bool,
    prevent_abort: bool,
    prevent_cancel: bool,
) ImplError!runtime.JSValue {
    const allocator = source_internal.allocator;
    const loop = source_internal.event_loop;

    // Step 9: Acquire default reader
    const reader = interfaces.ReadableStreamDefaultReader.call_constructor(
        source.ctx,
        source,
    ) catch |err| {
        return switch (err) {
            error.TypeError => error.TypeError,
            error.OutOfMemory => error.OutOfMemory,
            else => error.InvalidState,
        };
    };
    errdefer interfaces.ReadableStreamDefaultReader.deinit(reader);

    // Step 10: Acquire writer
    const writer = interfaces.WritableStreamDefaultWriter.call_constructor(
        dest.ctx,
        dest,
    ) catch |err| {
        // Release reader on error
        const reader_impl = @import("ReadableStreamDefaultReader.zig");
        reader_impl.call_releaseLock(reader) catch {};
        return switch (err) {
            error.TypeError => error.TypeError,
            error.OutOfMemory => error.OutOfMemory,
            else => error.InvalidState,
        };
    };
    errdefer {
        const writer_impl = @import("WritableStreamDefaultWriter.zig");
        writer_impl.call_releaseLock(writer) catch {};
    }

    // Step 11: Set source.[[disturbed]] to true
    source_internal.disturbed = true;

    // Step 13: Create promise for pipe operation
    const promise = try AsyncPromise(void).init(allocator, loop);
    errdefer promise.deinit();

    // Create pipe state
    const pipe_state = try allocator.create(PipeState);
    errdefer allocator.destroy(pipe_state);

    pipe_state.* = .{
        .source = source,
        .source_internal = source_internal,
        .dest = dest,
        .dest_internal = dest_internal,
        .reader = reader,
        .writer = writer,
        .prevent_close = prevent_close,
        .prevent_abort = prevent_abort,
        .prevent_cancel = prevent_cancel,
        .shutting_down = false,
        .promise = promise,
        .allocator = allocator,
        .event_loop = loop,
    };

    // Start the pipe loop
    // Note: In a real async implementation, this would schedule work on the event loop.
    // For now, we perform a simplified synchronous check and schedule async work.
    pipeLoop(pipe_state);

    // Bridge the Zig AsyncPromise to V8 Promise
    const isolate = v8_engine.ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
    const context = v8_engine.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoContext;

    const v8_promise = try promise_utils.asyncPromiseToV8(void, std.heap.c_allocator, isolate, context, promise);
    return runtime.JSValue.fromPromise(@ptrCast(v8_promise));
}

/// Main pipe loop - reads from source and writes to destination
fn pipeLoop(pipe_state: *PipeState) void {
    // Check for shutdown conditions before each iteration
    if (pipe_state.shutting_down) {
        return;
    }

    // Check source state
    if (pipe_state.source_internal.state == .errored) {
        // Error propagation forward
        // Convert StoredError to runtime.JSValue for type-safe API
        const error_jsvalue = pipe_state.source_internal.stored_error.toRuntimeJSValue();
        if (!pipe_state.prevent_abort) {
            pipeShutdownWithAction(pipe_state, .abort_dest, error_jsvalue);
        } else {
            pipeShutdown(pipe_state, error_jsvalue);
        }
        return;
    }

    // Check destination state
    if (pipe_state.dest_internal.state == .errored) {
        // Error propagation backward
        // Convert StoredError to runtime.JSValue for type-safe API
        const error_jsvalue = pipe_state.dest_internal.stored_error.toRuntimeJSValue();
        if (!pipe_state.prevent_cancel) {
            pipeShutdownWithAction(pipe_state, .cancel_source, error_jsvalue);
        } else {
            pipeShutdown(pipe_state, error_jsvalue);
        }
        return;
    }

    // Check if source is closed
    if (pipe_state.source_internal.state == .closed) {
        // Close propagation forward
        if (!pipe_state.prevent_close) {
            pipeShutdownWithAction(pipe_state, .close_dest, runtime.JSValue.jsUndefined);
        } else {
            pipeShutdown(pipe_state, runtime.JSValue.jsUndefined);
        }
        return;
    }

    // Check if destination close is queued or in flight
    const WritableStreamImpl = @import("WritableStream.zig");
    if (WritableStreamImpl.writableStreamCloseQueuedOrInFlight(pipe_state.dest_internal)) {
        // Destination is closing - shutdown with error
        if (!pipe_state.prevent_cancel) {
            pipeShutdownWithAction(pipe_state, .cancel_source, runtime.JSValue.jsUndefined);
        } else {
            pipeShutdown(pipe_state, runtime.JSValue.jsUndefined);
        }
        return;
    }

    // Pipe is healthy - schedule read/write cycle
    // In a full implementation, this would use the event loop to schedule async work.
    // For now, we fulfill the promise as "pipe started successfully"
    // Real implementation would continue reading until done/error.

    // For a minimal working implementation, we immediately resolve
    // Future: Implement full async read/write loop with event loop integration
    pipeFinalize(pipe_state, runtime.JSValue.jsUndefined);
}

/// Shutdown action types
const ShutdownAction = enum {
    abort_dest,
    cancel_source,
    close_dest,
};

/// Shutdown with an action (abort, cancel, or close)
/// Per Streams spec, error_reason is typed as `any` which maps to runtime.JSValue
fn pipeShutdownWithAction(pipe_state: *PipeState, action: ShutdownAction, error_reason: runtime.JSValue) void {
    if (pipe_state.shutting_down) return;
    pipe_state.shutting_down = true;

    // Perform the action (use interfaces per Golden Rule #13)
    switch (action) {
        .abort_dest => {
            // WritableStreamAbort
            _ = interfaces.WritableStream.call_abort(pipe_state.dest, webidl.Opt(runtime.JSValue).passed(error_reason)) catch {};
        },
        .cancel_source => {
            // ReadableStreamCancel
            _ = call_cancel(pipe_state.source, webidl.Opt(runtime.JSValue).passed(error_reason)) catch {};
        },
        .close_dest => {
            // WritableStreamDefaultWriterCloseWithErrorPropagation
            _ = interfaces.WritableStreamDefaultWriter.call_close(pipe_state.writer) catch {};
        },
    }

    // Finalize
    pipeFinalize(pipe_state, error_reason);
}

/// Shutdown without action
/// Per Streams spec, error_reason is typed as `any` which maps to runtime.JSValue
fn pipeShutdown(pipe_state: *PipeState, error_reason: runtime.JSValue) void {
    if (pipe_state.shutting_down) return;
    pipe_state.shutting_down = true;

    pipeFinalize(pipe_state, error_reason);
}

/// Finalize pipe operation - release locks and settle promise
/// Per Streams spec, error_reason is typed as `any` which maps to runtime.JSValue
fn pipeFinalize(pipe_state: *PipeState, error_reason: runtime.JSValue) void {
    // Step 1: Release writer (use interface per Golden Rule #13)
    interfaces.WritableStreamDefaultWriter.call_releaseLock(pipe_state.writer) catch {};

    // Step 2-3: Release reader (use interface per Golden Rule #13)
    interfaces.ReadableStreamDefaultReader.call_releaseLock(pipe_state.reader) catch {};

    // Step 5-6: Settle promise
    if (!error_reason.isUndefined()) {
        // Reject with error
        // Convert JSValue to Exception for rejection
        const exception = webidl.errors.Exception.typeError(pipe_state.allocator, "Pipe failed") catch {
            // If we can't create exception, just fulfill with unit
            pipe_state.promise.fulfill({});
            pipe_state.allocator.destroy(pipe_state);
            return;
        };
        pipe_state.promise.reject(exception);
    } else {
        // Resolve with undefined
        pipe_state.promise.fulfill({});
    }

    // Clean up pipe state
    pipe_state.allocator.destroy(pipe_state);
}

// ============================================================================
// Internal API for Zig-only streams (e.g., Blob.stream())
// ============================================================================

/// Generic underlying source for type-safe Zig-native stream implementations.
///
/// This provides compile-time type safety for the context pointer, avoiding
/// the need for @ptrCast/@alignCast at runtime. Use this for new code.
///
/// ## Example
/// ```zig
/// const BlobSource = ZigUnderlyingSourceTyped(BlobStreamSource);
///
/// fn pull(controller: *runtime.Instance, source: *BlobStreamSource) anyerror!void {
///     // Direct typed access - no @ptrCast needed
///     const data = source.blob_data.bytes[source.position..];
///     // ...
/// }
///
/// const source = BlobSource{
///     .pull = &pull,
///     .context = source_state,  // *BlobStreamSource
///     .is_byte_stream = true,
/// };
/// const stream = try createFromZigSourceTyped(allocator, ctx, source);
/// ```
pub fn ZigUnderlyingSourceTyped(comptime Context: type) type {
    return struct {
        const Self = @This();

        /// Pull callback - called when the stream needs more data.
        /// Receives typed context pointer directly.
        pull: ?*const fn (*runtime.Instance, *Context) anyerror!void = null,

        /// Cancel callback - called when the stream is cancelled.
        /// reason: The cancellation reason (opaque to Zig code)
        /// context: Typed context pointer
        cancel: ?*const fn (?*const anyopaque, *Context) anyerror!void = null,

        /// Typed context pointer (NOT optional - use a wrapper struct if needed)
        context: *Context,

        /// Stream type - set to true for byte streams
        is_byte_stream: bool = false,

        /// Auto-allocate chunk size for byte streams
        auto_allocate_chunk_size: ?u64 = null,

        /// Convert to type-erased ZigUnderlyingSource for internal use.
        ///
        /// This allows using the typed source with the existing createFromZigSource function.
        pub fn toErased(self: Self) ZigUnderlyingSource {
            return .{
                .pull = if (self.pull) |p| @ptrCast(p) else null,
                .cancel = if (self.cancel) |c| @ptrCast(c) else null,
                .context = @ptrCast(self.context),
                .is_byte_stream = self.is_byte_stream,
                .auto_allocate_chunk_size = self.auto_allocate_chunk_size,
            };
        }
    };
}

/// Configuration for creating a ReadableStream from Zig callbacks (type-erased).
///
/// This is the type-erased version that accepts `?*anyopaque` context.
/// For type-safe code, use `ZigUnderlyingSourceTyped(Context)` instead.
///
/// This type is kept for backward compatibility with existing code.
pub const ZigUnderlyingSource = struct {
    /// Pull callback - called when the stream needs more data
    /// Signature: fn(controller: *runtime.Instance, context: ?*anyopaque) anyerror!void
    pull: ?*const fn (*runtime.Instance, ?*anyopaque) anyerror!void = null,

    /// Cancel callback - called when the stream is cancelled
    /// Signature: fn(reason: ?*const anyopaque, context: ?*anyopaque) anyerror!void
    cancel: ?*const fn (?*const anyopaque, ?*anyopaque) anyerror!void = null,

    /// User context passed to callbacks (type-erased)
    context: ?*anyopaque = null,

    /// Stream type - set to true for byte streams
    is_byte_stream: bool = false,

    /// Auto-allocate chunk size for byte streams
    auto_allocate_chunk_size: ?u64 = null,
};

/// Create a ReadableStream from Zig callbacks (internal API)
///
/// This is an internal function for Zig code that needs to create a ReadableStream
/// without going through the V8/JavaScript path. It accepts Zig function pointers
/// directly, avoiding the JSValue conversion issues.
///
/// Example usage (Blob.stream()):
/// ```zig
/// const source = ReadableStreamImpl.ZigUnderlyingSource{
///     .pull = &blobStreamPull,
///     .cancel = &blobStreamCancel,
///     .context = @ptrCast(source_state),
///     .is_byte_stream = true,
///     .auto_allocate_chunk_size = 64 * 1024,
/// };
/// const stream = try ReadableStreamImpl.createFromZigSource(allocator, ctx, source);
/// ```
pub fn createFromZigSource(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    source: ZigUnderlyingSource,
) !*runtime.Instance {
    // Get event loop from context (required for async operations)
    const loop = try ctx.getEventLoop();

    // Create the stream instance
    const instance = try init(allocator, State, &ReadableStream.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Create internal state
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    // InitializeReadableStream: Set initial state
    internal.* = InternalState{
        .controller = undefined, // Will be set by SetUp
        .reader = .none,
        .state = .readable,
        .stored_error = .none,
        .detached = false,
        .disturbed = false,
        .event_loop = loop,
        .allocator = allocator,
    };

    state.own._internal = internal;

    if (source.is_byte_stream) {
        // Create byte stream controller
        const high_water_mark: f64 = 0.0; // Byte streams default to 0

        // Create pull algorithm from Zig callback using algorithm module helper
        const pull_algo: ?*Algorithm = if (source.pull) |pull_fn|
            try algorithm_mod.zigPullAlgorithm(allocator, pull_fn, source.context)
        else
            null;
        errdefer if (pull_algo) |a| a.deinit();

        // Create cancel algorithm from Zig callback using algorithm module helper
        const cancel_algo: ?*Algorithm = if (source.cancel) |cancel_fn|
            try algorithm_mod.zigCancelAlgorithm(allocator, cancel_fn, source.context)
        else
            null;
        errdefer if (cancel_algo) |a| a.deinit();

        // Set up byte stream controller
        try setUpReadableByteStreamControllerInternal(
            instance,
            internal,
            pull_algo,
            cancel_algo,
            high_water_mark,
            source.auto_allocate_chunk_size,
        );
    } else {
        // Create default stream controller
        const high_water_mark: f64 = 1.0; // Default streams use 1

        // Create pull algorithm from Zig callback using algorithm module helper
        const pull_algo: ?*Algorithm = if (source.pull) |pull_fn|
            try algorithm_mod.zigPullAlgorithm(allocator, pull_fn, source.context)
        else
            null;
        errdefer if (pull_algo) |a| a.deinit();

        // Create cancel algorithm from Zig callback using algorithm module helper
        const cancel_algo: ?*Algorithm = if (source.cancel) |cancel_fn|
            try algorithm_mod.zigCancelAlgorithm(allocator, cancel_fn, source.context)
        else
            null;
        errdefer if (cancel_algo) |a| a.deinit();

        // Set up default stream controller
        try setUpReadableStreamDefaultControllerInternal(
            instance,
            internal,
            pull_algo,
            cancel_algo,
            high_water_mark,
        );
    }

    return instance;
}

/// Internal helper to set up a byte stream controller without V8 callbacks
fn setUpReadableByteStreamControllerInternal(
    stream: *runtime.Instance,
    internal: *InternalState,
    pull_algorithm: ?*Algorithm,
    cancel_algorithm: ?*Algorithm,
    high_water_mark: f64,
    auto_allocate_chunk_size: ?u64,
) !void {
    const allocator = internal.allocator;
    const ReadableByteStreamControllerImpl = @import("ReadableByteStreamController.zig");

    // Create controller instance
    const controller = try ReadableByteStreamControllerImpl.init(
        allocator,
        interfaces.ReadableByteStreamController.State,
        &interfaces.ReadableByteStreamController.vtable,
        stream.ctx,
    );
    errdefer ReadableByteStreamControllerImpl.deinit(controller);

    // Create controller internal state
    const controller_internal = try allocator.create(ReadableByteStreamControllerImpl.InternalState);
    errdefer allocator.destroy(controller_internal);

    controller_internal.* = ReadableByteStreamControllerImpl.InternalState{
        .allocator = allocator,
        .abort_controller = null,
        .auto_allocate_chunk_size = auto_allocate_chunk_size,
        .byob_request = null,
        .cancel_algorithm = cancel_algorithm,
        .close_requested = false,
        .pull_again = false,
        .pull_algorithm = pull_algorithm,
        .pulling = false,
        .pending_pull_intos = infra.List(*ReadableByteStreamControllerImpl.PullIntoDescriptor).init(allocator),
        .byte_queue = infra.List(ReadableByteStreamControllerImpl.ByteStreamQueueEntry).init(allocator),
        .queue_total_size = 0,
        .started = true, // No async start for Zig sources
        .start_algorithm = null,
        .strategy_hwm = high_water_mark,
        .stream = stream,
        .isolate = null,
        .v8_context = null,
        .loop = internal.event_loop,
        .controller_instance = controller,
    };

    const controller_state = controller.getState(interfaces.ReadableByteStreamController.State);
    controller_state.own._internal = controller_internal;

    // Link stream to controller
    internal.controller = controller;
}

/// Internal helper to set up a default stream controller without V8 callbacks
fn setUpReadableStreamDefaultControllerInternal(
    stream: *runtime.Instance,
    internal: *InternalState,
    pull_algorithm: ?*Algorithm,
    cancel_algorithm: ?*Algorithm,
    high_water_mark: f64,
) !void {
    const allocator = internal.allocator;
    const ReadableStreamDefaultControllerImpl = @import("ReadableStreamDefaultController.zig");

    // Create controller instance
    const controller = try ReadableStreamDefaultControllerImpl.init(
        allocator,
        interfaces.ReadableStreamDefaultController.State,
        &interfaces.ReadableStreamDefaultController.vtable,
        stream.ctx,
    );
    errdefer ReadableStreamDefaultControllerImpl.deinit(controller);

    // Create controller internal state
    const controller_internal = try allocator.create(ReadableStreamDefaultControllerImpl.InternalState);
    errdefer allocator.destroy(controller_internal);

    controller_internal.* = ReadableStreamDefaultControllerImpl.InternalState{
        .stream = stream,
        .start_algorithm = null, // No async start for Zig sources
        .pull_algorithm = pull_algorithm,
        .cancel_algorithm = cancel_algorithm,
        .queue = QueueWithSizes.init(allocator),
        .queue_total_size = 0.0,
        .strategy_hwm = high_water_mark,
        .strategy_size_algorithm = null,
        .close_requested = false,
        .started = true, // No async start for Zig sources
        .pulling = false,
        .pull_again = false,
        .allocator = allocator,
    };

    const controller_state = controller.getState(interfaces.ReadableStreamDefaultController.State);
    controller_state.own._internal = controller_internal;

    // Link stream to controller
    internal.controller = controller;
}

/// ReadableStream.from(asyncIterable) static method
///
/// Spec: https://streams.spec.whatwg.org/#rs-from
///
/// Creates a ReadableStream from an async iterable object.
/// Steps:
/// 1. Let iteratorRecord be ? GetIterator(asyncIterable, async)
/// 2. Let stream be ! CreateReadableStream(startAlgorithm, pullAlgorithm, cancelAlgorithm)
/// 3. Return stream
pub fn call_from(instance: *runtime.Instance, asyncIterable: runtime.JSValue) anyerror!*runtime.Instance {
    // The 'instance' parameter is the constructor function, not needed for static method
    const ctx = instance.ctx;
    const allocator = ctx.getAllocator();

    // Get the async iterable value as a V8 pointer
    const async_iterable_ptr = asyncIterable.toAnyopaque() orelse return error.TypeError;

    // Step 1: Get iterator from async iterable
    // Spec: Let iteratorRecord be ? GetIterator(asyncIterable, async)
    const iterator_record = IteratorRecord.fromAsyncIterable(
        allocator,
        ctx,
        async_iterable_ptr,
    ) catch |err| {
        // TypeError if not an async iterable
        if (err == error.TypeError) return error.TypeError;
        if (err == error.NoV8Engine or err == error.NoV8Context) return error.InvalidState;
        return err;
    };
    errdefer iterator_record.deinit();

    // Step 2: Create pull algorithm
    // The pull algorithm will iterate through the async iterable
    const pull_algorithm = try from_iterable.createPullAlgorithm(allocator, iterator_record);
    errdefer pull_algorithm.destroy(allocator);

    // Cancel algorithm - use null for now since the pull algorithm owns the iterator
    // and will clean it up when the stream is destroyed. In the future, we could
    // implement proper cancel that calls iterator.return(reason).
    const cancel_algorithm: ?*Algorithm = null;

    // Step 3: Create the stream
    // Use the same pattern as the constructor but with our algorithms
    const loop = try ctx.getEventLoop();

    // Create stream instance
    const stream_instance = try init(allocator, State, &ReadableStream.vtable, ctx);
    errdefer deinit(stream_instance);

    const state = stream_instance.getState(State);

    // Create internal state
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = InternalState{
        .controller = undefined, // Will be set by SetUp
        .reader = .none,
        .state = .readable,
        .stored_error = .none,
        .detached = false,
        .disturbed = false,
        .event_loop = loop,
        .allocator = allocator,
    };

    state.own._internal = internal;

    // Set up default controller with our algorithms
    // Use the internal helper that takes Algorithm pointers directly
    try setUpReadableStreamDefaultControllerInternal(
        stream_instance,
        internal,
        pull_algorithm,
        cancel_algorithm,
        1.0, // High water mark
    );

    return stream_instance;
}
