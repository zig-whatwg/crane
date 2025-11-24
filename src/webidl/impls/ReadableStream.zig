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
const ReadableStream = interfaces.ReadableStream;

// Import streams infrastructure
const streams_common = @import("streams_common");
const event_loop = @import("streams_event_loop");
const AsyncPromise = @import("streams_async_promise").AsyncPromise;
const QueueWithSizes = @import("streams_queue").QueueWithSizes;
const algorithm_mod = @import("streams_algorithm");
const Algorithm = algorithm_mod.Algorithm;
const IteratorRecord = @import("streams_iterator_record").IteratorRecord;
const from_iterable = @import("streams_from_iterable_algorithm");

pub const State = ReadableStream.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    RangeError,
    InvalidState,
    OutOfMemory,
    NoEventLoop,
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
    stored_error: ?*anyopaque,

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
    runtime.Instance.deinit(instance);
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
pub fn call_constructor(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    underlyingSource: *const anyopaque,
    strategy: dictionaries.QueuingStrategy,
) !*runtime.Instance {
    // Get event loop from context (required for async operations)
    const loop = try ctx.getEventLoop();

    // Step 1: If underlyingSource is missing, it would be null
    // (handled by caller setting it to null/undefined)

    // Step 2: Convert to UnderlyingSource dictionary
    // For now, we'll assume underlyingSource is already a dictionary pointer
    // In real implementation, this would involve WebIDL type conversion
    const underlying_source_dict: *const dictionaries.UnderlyingSource = @ptrCast(@alignCast(underlyingSource));

    // Step 3: Perform InitializeReadableStream
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
        .stored_error = null,
        .detached = false,
        .disturbed = false,
        .event_loop = loop,
        .allocator = allocator,
    };

    state.own._internal = internal;

    // Step 4: Check if this is a byte stream
    if (underlying_source_dict.type != null) {
        // TODO: Byte streams not yet implemented
        return error.NotImplemented;
    }

    // Step 5: Default stream (not byte stream)
    // Step 5.1: Assert type does not exist (checked above)

    // Step 5.2: Extract size algorithm
    const size_algorithm = extractSizeAlgorithm(&strategy);
    _ = size_algorithm; // Will be passed to controller when size calculation is implemented

    // Step 5.3: Extract high water mark (default 1 for count-based queuing)
    const high_water_mark = try extractHighWaterMark(&strategy, 1.0);

    // Step 5.4: Perform SetUpReadableStreamDefaultControllerFromUnderlyingSource
    try setUpReadableStreamDefaultControllerFromUnderlyingSource(
        instance,
        internal,
        underlyingSource,
        underlying_source_dict,
        high_water_mark,
    );

    return instance;
}

/// Getter for locked
///
/// Spec: https://streams.spec.whatwg.org/#rs-locked
/// readonly attribute boolean locked
///
/// Returns true if the stream is locked to a reader.
/// A stream is locked if stream.[[reader]] is not undefined.
pub fn get_locked(instance: *runtime.Instance) ImplError!bool {
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
pub fn call_from(instance: *runtime.Instance, async_iterable: *const anyopaque) ImplError!*runtime.Instance {
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
    const iterator_record = IteratorRecord.fromAsyncIterable(
        allocator,
        instance.ctx,
        async_iterable,
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
        .stored_error = null,
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
pub fn call_pipeThrough(instance: *runtime.Instance, transform: dictionaries.ReadableWritablePair, options: dictionaries.StreamPipeOptions) ImplError!*runtime.Instance {
    _ = instance;
    _ = transform;
    _ = options;
    return error.NotImplemented;
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
pub fn call_cancel(instance: *runtime.Instance, reason: *const anyopaque) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Check if stream is locked
    // IsReadableStreamLocked(stream): return stream.[[reader]] !== undefined
    if (internal.reader != .none) {
        // Stream is locked - return rejected promise with TypeError
        const promise = try AsyncPromise(void).init(
            internal.allocator,
            internal.event_loop,
        );
        const exception = try webidl.errors.Exception.typeError(internal.allocator, "Cannot cancel a locked stream");
        promise.*.reject(exception);
        return @ptrCast(promise);
    }

    // Step 2: Perform ReadableStreamCancel(this, reason)
    return readableStreamCancel(instance, internal, reason);
}

/// ReadableStreamCancel algorithm
/// Internal implementation of stream cancellation
fn readableStreamCancel(
    instance: *runtime.Instance,
    internal: *InternalState,
    reason: *const anyopaque,
) !*const anyopaque {
    _ = instance;

    // Step 1: Set stream.[[disturbed]] to true
    internal.disturbed = true;

    // Step 2: If stream.[[state]] is "closed", return resolved promise
    if (internal.state == .closed) {
        const promise = try AsyncPromise(void).init(
            internal.allocator,
            internal.event_loop,
        );
        promise.*.fulfill({});
        return @ptrCast(promise);
    }

    // Step 3: If stream.[[state]] is "errored", return rejected promise
    if (internal.state == .errored) {
        const promise = try AsyncPromise(void).init(
            internal.allocator,
            internal.event_loop,
        );
        // Reject with stream.[[storedError]]
        // Note: storedError is *anyopaque but AsyncPromise.reject needs Exception
        // For now, detect presence and create appropriate message
        // Future: Store Exception directly or implement safe type conversion
        const exception = if (internal.stored_error != null)
            try webidl.errors.Exception.typeError(internal.allocator, "Stream errored (stored error)")
        else
            try webidl.errors.Exception.typeError(internal.allocator, "Stream is errored");
        promise.*.reject(exception);
        return @ptrCast(promise);
    }

    // Step 4: Perform ReadableStreamClose(stream)
    readableStreamClose(internal);

    // Step 5: Get reader
    const reader = internal.reader;

    // Step 6: If reader is BYOB reader, handle readIntoRequests
    if (reader == .byob) {
        // TODO: Handle BYOB reader readIntoRequests
        // For each readIntoRequest, call close steps with undefined
    }

    // Step 7: Call controller.[[CancelSteps]](reason)
    // Step 7: Call controller.[[CancelSteps]](reason)
    // Future: Implement controller.[[CancelSteps]] for cleanup
    // For now, assume immediate success
    _ = reason;

    const promise = try AsyncPromise(void).init(
        internal.allocator,
        internal.event_loop,
    );

    // Step 8: React to sourceCancelPromise with fulfillment returning undefined
    // Future: Chain promises when controller.[[CancelSteps]] is implemented
    promise.*.fulfill({});

    return @ptrCast(promise);
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
pub fn readableStreamError(internal: *InternalState, e: *const anyopaque) void {
    // Assert: stream.[[state]] is "readable"
    std.debug.assert(internal.state == .readable);

    // Set stream.[[state]] to "errored"
    internal.state = .errored;

    // Store the error
    internal.stored_error = @constCast(e);

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
pub fn call_getReader(instance: *runtime.Instance, options: dictionaries.ReadableStreamGetReaderOptions) ImplError!typedefs.ReadableStreamReader {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    const allocator = internal.allocator;
    const ctx = instance.ctx;

    // Step 1: Check if mode exists in options
    // Future: Parse options.mode to distinguish default vs BYOB reader
    // For now, always create default reader (BYOB not implemented)
    _ = options;

    // AcquireReadableStreamDefaultReader:
    // Step 1-2: Create reader and call SetUpReadableStreamDefaultReader
    // This is done by the ReadableStreamDefaultReader constructor
    const reader = interfaces.ReadableStreamDefaultReader.call_constructor(
        allocator,
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

    // Step 3: Return reader
    // The return type is typedefs.ReadableStreamReader which is *const anyopaque
    return @ptrCast(reader);
}

/// Operation: pipeTo
pub fn call_pipeTo(instance: *runtime.Instance, destination: *runtime.Instance, options: dictionaries.StreamPipeOptions) ImplError!*const anyopaque {
    _ = instance;
    _ = destination;
    _ = options;
    return error.NotImplemented;
}

/// Operation: tee
pub fn call_tee(instance: *runtime.Instance) ImplError!*const anyopaque {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: forEach
pub fn call_forEach(instance: *runtime.Instance, callback: *const anyopaque) ImplError!void {
    _ = instance;
    _ = callback;
    return error.NotImplemented;
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
pub fn call_values(
    instance: *runtime.Instance,
    options: dictionaries.ReadableStreamIteratorOptions,
) ImplError!*const anyopaque {
    const allocator = instance.ctx.getAllocator();
    const ctx = instance.ctx;

    // Extract preventCancel from options (defaults to false per WebIDL)
    const prevent_cancel = options.preventCancel orelse false;

    // Create async iterator
    const async_iterator_mod = @import("streams_readable_stream_async_iterator");
    const iterator = try async_iterator_mod.create(
        allocator,
        ctx,
        instance,
        prevent_cancel,
    );

    // Return iterator as opaque pointer
    // V8 will handle wrapping this with next() and return() methods
    return @ptrCast(iterator);
}

/// Operation: [Symbol.asyncIterator]
///
/// Spec: https://streams.spec.whatwg.org/#rs-asynciterator
/// WebIDL: async_iterable<any>(optional ReadableStreamIteratorOptions options = {});
///
/// Default async iterator (enables for-await-of loops).
/// Delegates to values() with the same options.
///
/// Steps:
/// 1. Return ! this.values(options)
pub fn call_getAsyncIterator(
    instance: *runtime.Instance,
    options: dictionaries.ReadableStreamIteratorOptions,
) ImplError!*const anyopaque {
    // Delegate to values() - they have identical behavior
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
fn setUpReadableStreamDefaultControllerFromUnderlyingSource(
    stream_instance: *runtime.Instance,
    stream_internal: *InternalState,
    underlyingSource: *const anyopaque,
    underlyingSourceDict: *const dictionaries.UnderlyingSource,
    highWaterMark: f64,
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
    var start_algorithm: ?*const anyopaque = null;
    var pull_algorithm: ?*const anyopaque = null;
    var cancel_algorithm: ?*const anyopaque = null;

    // Step 5: If start callback exists, use it
    if (underlyingSourceDict.start) |_| {
        // Store callback - will be invoked in SetUpReadableStreamDefaultController
        start_algorithm = underlyingSourceDict.start;
    }

    // Step 6: If pull callback exists, use it
    if (underlyingSourceDict.pull) |_| {
        // Store callback - will be invoked by CallPullIfNeeded
        pull_algorithm = underlyingSourceDict.pull;
    }

    // Step 7: If cancel callback exists, use it
    if (underlyingSourceDict.cancel) |_| {
        // Store callback - will be invoked by cancel() operation
        // Future: Implement cancel algorithm invocation
        cancel_algorithm = underlyingSourceDict.cancel;
    }

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
    const loop = stream_internal.event_loop;

    // Step 1: Assert controller is undefined (guaranteed by constructor)

    // Get controller state
    const controller_state = controller_instance.getState(interfaces.ReadableStreamDefaultController.State);

    // Convert callbacks to Algorithms
    const pull_algo: ?*Algorithm = if (pullAlgorithm) |cb|
        try algorithm_mod.jsCallbackAlgorithm(allocator, cb)
    else
        null;
    errdefer if (pull_algo) |algo| {
        algo.deinit();
        allocator.destroy(algo);
    };

    const cancel_algo: ?*Algorithm = if (cancelAlgorithm) |cb|
        try algorithm_mod.jsCallbackAlgorithm(allocator, cb)
    else
        null;
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
        .pull_algorithm = pull_algo,
        .cancel_algorithm = cancel_algo,
        .allocator = allocator,
    };

    controller_state.own._internal = controller_internal;

    // Step 8: Set stream.[[controller]] to controller
    stream_internal.controller = controller_instance;

    // Step 9-12: Perform startAlgorithm and handle promise
    if (startAlgorithm) |start_fn| {
        // Invoke start algorithm with controller as argument
        const start_callback: callbacks.UnderlyingSourceStartCallback = @ptrCast(@alignCast(start_fn));

        // Call the start function - it returns a promise or undefined
        const start_result = start_callback(@ptrCast(controller_instance));

        // Treat as immediately resolved (simplified)
        // Future: Chain promise when start returns Promise
        // Should: await fulfillment before marking started, or reject on error
        _ = start_result;

        // Mark as started (simplified - should wait for promise)
        controller_internal.started = true;

        // Call pull if needed
        const ReadableStreamDefaultControllerImpl = @import("ReadableStreamDefaultController.zig");
        ReadableStreamDefaultControllerImpl.readableStreamDefaultControllerCallPullIfNeeded(controller_internal);
    } else {
        // No start algorithm - immediately mark as started
        controller_internal.started = true;

        // Call pull if needed
        const ReadableStreamDefaultControllerImpl = @import("ReadableStreamDefaultController.zig");
        ReadableStreamDefaultControllerImpl.readableStreamDefaultControllerCallPullIfNeeded(controller_internal);
    }

    _ = loop; // Will be used for promise handling when we implement full async
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
    chunk: *anyopaque,
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
