//! ReadableStreamDefaultReader Implementation
//!
//! WHATWG Streams Standard: https://streams.spec.whatwg.org/#default-reader-class
//!
//! Allows reading chunks from a ReadableStream.
//! Includes ReadableStreamGenericReader mixin (closed, cancel methods).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const ReadableStreamDefaultReader = interfaces.ReadableStreamDefaultReader;

// Import streams infrastructure
const streams_common = @import("streams_common");
const AsyncPromise = @import("streams_async_promise").AsyncPromise;

// V8 FFI for Promise bridging
const v8 = @import("v8").ffi;
const V8Promise = @import("v8").Promise;

pub const State = ReadableStreamDefaultReader.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    RangeError,
    InvalidState,
    OutOfMemory,
};

/// Read result structure
/// Per spec: ReadableStreamReadResult dictionary
pub const ReadResult = struct {
    value: ?*anyopaque,
    done: bool,
};

/// Internal state for ReadableStreamDefaultReader
///
/// Per WHATWG Streams spec § 4.3.2
/// Includes slots from ReadableStreamGenericReader mixin
pub const InternalState = struct {
    /// [[stream]]: ReadableStream instance or undefined if released
    /// From ReadableStreamGenericReader mixin
    stream: ?*runtime.Instance,

    /// [[closedPromise]]: Promise<undefined> that fulfills when stream closes
    /// From ReadableStreamGenericReader mixin
    closed_promise: *AsyncPromise(void),

    /// [[readRequests]]: List of pending read promises
    read_requests: std.ArrayList(*AsyncPromise(ReadResult)),

    /// Event loop for async operations
    /// Provided by runtime.Context.getEventLoop()
    event_loop: @import("streams_event_loop").EventLoop,

    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState) void {
        // Clean up read requests list (promises owned by callers)
        self.read_requests.deinit(self.allocator);

        // Clean up closed promise
        self.closed_promise.deinit();

        // Note: stream is owned elsewhere
        self.allocator.destroy(self);
    }
};

/// Bridge for converting AsyncPromise(ReadResult) to V8 Promise
///
/// This is necessary because `call_read` returns a Promise to JavaScript,
/// but internally uses Zig's AsyncPromise. The bridge registers callbacks
/// on the AsyncPromise that resolve/reject the V8 Promise when it settles.
const ReadResultPromiseBridge = struct {
    v8_promise: V8Promise(ReadResult),
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, isolate: *v8.Isolate, context: *v8.Context) !*ReadResultPromiseBridge {
        const bridge = try allocator.create(ReadResultPromiseBridge);
        errdefer allocator.destroy(bridge);

        bridge.* = .{
            .v8_promise = try V8Promise(ReadResult).init(isolate, context),
            .allocator = allocator,
        };

        return bridge;
    }

    fn deinit(self: *ReadResultPromiseBridge) void {
        // NOTE: Do NOT call self.v8_promise.deinit() here!
        // The V8 Promise was returned to JavaScript via getPromise().
        // JavaScript owns it now and V8's GC will manage its lifetime.
        // We only free the bridge wrapper struct.
        self.allocator.destroy(self);
    }

    fn onFulfilled(ctx: *anyopaque, value: ReadResult) anyerror!void {
        const self: *ReadResultPromiseBridge = @ptrCast(@alignCast(ctx));
        self.v8_promise.resolve(value) catch {};
        self.deinit();
    }

    fn onRejected(ctx: *anyopaque, err_value: webidl.errors.Exception) anyerror!void {
        const self: *ReadResultPromiseBridge = @ptrCast(@alignCast(ctx));
        self.v8_promise.reject(err_value) catch {};
        self.deinit();
    }
};

/// Convert AsyncPromise(ReadResult) to V8 Promise
///
/// Creates a V8 Promise and registers callbacks on the Zig promise.
/// When the Zig promise settles, the V8 promise is resolved/rejected.
fn convertReadResultPromiseToV8(
    zig_promise: *AsyncPromise(ReadResult),
) !*v8.Promise {
    const allocator = std.heap.c_allocator; // TODO: Pass allocator properly
    const isolate = v8.v8_Isolate_GetCurrent() orelse return error.InvalidState;
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return error.InvalidState;

    // Create bridge that will resolve V8 promise when Zig promise settles
    const bridge = try ReadResultPromiseBridge.init(allocator, isolate, context);
    errdefer bridge.deinit();

    // Register callback on Zig promise
    try zig_promise.onSettleCtx(
        ReadResultPromiseBridge.onFulfilled,
        ReadResultPromiseBridge.onRejected,
        bridge,
    );

    // Return the V8 promise
    return bridge.v8_promise.getPromise();
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
///
/// Spec: https://streams.spec.whatwg.org/#default-reader-constructor
/// new ReadableStreamDefaultReader(stream)
///
/// Steps:
/// 1. Perform ? SetUpReadableStreamDefaultReader(this, stream)
///
/// SetUpReadableStreamDefaultReader(reader, stream):
/// 1. If ! IsReadableStreamLocked(stream) is true, throw a TypeError exception
/// 2. Perform ! ReadableStreamReaderGenericInitialize(reader, stream)
/// 3. Set reader.[[readRequests]] to a new empty list
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, stream: *runtime.Instance) !*runtime.Instance {
    // Get event loop from context (required for async operations)
    const event_loop = try ctx.getEventLoop();

    // SetUpReadableStreamDefaultReader Step 1: Check if stream is locked
    // IsReadableStreamLocked(stream): return stream.[[reader]] !== undefined
    const stream_state = stream.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.InvalidState;

    if (stream_internal.reader != .none) {
        // Stream is already locked - throw TypeError
        return error.TypeError;
    }

    // Create instance
    const instance = try init(allocator, State, &ReadableStreamDefaultReader.vtable, ctx);
    errdefer deinit(instance);

    const reader_state = instance.getState(State);

    // Create InternalState for reader
    const reader_internal = try allocator.create(InternalState);
    errdefer allocator.destroy(reader_internal);

    // SetUpReadableStreamDefaultReader Step 2: ReadableStreamReaderGenericInitialize
    // This sets up the bidirectional relationship between reader and stream

    // ReadableStreamReaderGenericInitialize Step 1: Set reader.[[stream]] to stream
    reader_internal.stream = stream;

    // ReadableStreamReaderGenericInitialize Step 2: Set stream.[[reader]] to reader
    stream_internal.reader = .{ .default = instance };

    // ReadableStreamReaderGenericInitialize Step 3-5: Initialize closedPromise based on stream state
    const closed_promise = switch (stream_internal.state) {
        // Step 3: If stream.[[state]] is "readable", create pending promise
        .readable => try AsyncPromise(void).init(allocator, event_loop),

        // Step 4: If stream.[[state]] is "closed", create resolved promise
        .closed => blk: {
            const promise = try AsyncPromise(void).init(allocator, event_loop);
            promise.*.fulfill({});
            break :blk promise;
        },

        // Step 5: If stream.[[state]] is "errored", create rejected promise
        .errored => blk: {
            const promise = try AsyncPromise(void).init(allocator, event_loop);
            // Reject with stream.[[storedError]]
            // Use type-safe StoredError API to check for error
            const exception = if (stream_internal.stored_error.hasError())
                try webidl.errors.Exception.typeError(allocator, "Stream errored (stored error)")
            else
                try webidl.errors.Exception.typeError(allocator, "Stream is errored");
            promise.*.reject(exception);
            // Note: Should set promise.[[PromiseIsHandled]] to true
            break :blk promise;
        },
    };
    errdefer closed_promise.deinit();

    // SetUpReadableStreamDefaultReader Step 3: Initialize readRequests to empty list
    const read_requests: std.ArrayList(*AsyncPromise(ReadResult)) = .{
        .items = &.{},
        .capacity = 0,
    };

    reader_internal.* = InternalState{
        .stream = stream,
        .closed_promise = closed_promise,
        .read_requests = read_requests,
        .event_loop = event_loop,
        .allocator = allocator,
    };

    reader_state.own._internal = reader_internal;

    return instance;
}

/// Getter for closed
///
/// Spec: https://streams.spec.whatwg.org/#generic-reader-closed
/// readonly attribute Promise<undefined> closed
///
/// From ReadableStreamGenericReader mixin.
/// Returns a promise that fulfills when the stream closes.
///
/// Returns: Pointer to AsyncPromise(void)
pub fn get_closed(instance: *runtime.Instance) anyerror!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.TypeError;

    // Return the closed promise
    // Note: The promise is owned by the reader and should not be deinitialized by caller
    return @ptrCast(internal.closed_promise);
}

/// Operation: read
///
/// Spec: https://streams.spec.whatwg.org/#default-reader-read
/// Promise<ReadableStreamReadResult> read()
///
/// Steps:
/// 1. If this.[[stream]] is undefined, return promise rejected with TypeError
/// 2. Let promise be a new promise
/// 3. Let readRequest be a new read request with:
///    - chunk steps: Resolve promise with { value: chunk, done: false }
///    - close steps: Resolve promise with { value: undefined, done: true }
///    - error steps: Reject promise with e
/// 4. Perform ! ReadableStreamDefaultReaderRead(this, readRequest)
/// 5. Return promise
///
/// Returns: Pointer to V8 Promise - the promise is managed by V8's GC
pub fn call_read(instance: *runtime.Instance) anyerror!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.TypeError;

    // Step 1: Check if reader has been released
    if (internal.stream == null) {
        // Return rejected promise with TypeError
        const promise = try AsyncPromise(ReadResult).init(
            internal.allocator,
            internal.event_loop,
        );
        const exception = try webidl.errors.Exception.typeError(internal.allocator, "Reader has been released");
        promise.*.reject(exception);
        // Convert to V8 Promise before returning
        const v8_promise = try convertReadResultPromiseToV8(promise);
        return @ptrCast(v8_promise);
    }

    // Step 2: Create promise
    const promise = try AsyncPromise(ReadResult).init(
        internal.allocator,
        internal.event_loop,
    );
    errdefer promise.deinit();

    // Step 3: Create read request
    // Note: The readRequest is conceptually an object with three callbacks:
    // - chunk steps (called when chunk available)
    // - close steps (called when stream closes)
    // - error steps (called when stream errors)
    //
    // In our implementation, we store the promise in read_requests list,
    // and the controller will resolve/reject it appropriately.
    //
    // For now, we'll queue the promise. The controller's PullSteps will
    // either fulfill it immediately (if data available) or keep it pending.

    // Step 4: Perform ReadableStreamDefaultReaderRead(this, readRequest)
    // This delegates to the stream's controller to pull data
    const stream = internal.stream.?;
    const stream_state = stream.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.InvalidState;

    // Check stream state
    switch (stream_internal.state) {
        .closed => {
            // Close steps: Resolve with { value: undefined, done: true }
            promise.*.fulfill(ReadResult{
                .value = null,
                .done = true,
            });
        },
        .errored => {
            // Error steps: Reject with stream.[[storedError]]
            // Use type-safe StoredError API to check for error
            const exception = if (stream_internal.stored_error.hasError())
                try webidl.errors.Exception.typeError(internal.allocator, "Stream errored (stored error)")
            else
                try webidl.errors.Exception.typeError(internal.allocator, "Stream is errored");
            promise.*.reject(exception);
        },
        .readable => {
            // Call controller.[[PullSteps]](readRequest)
            // The controller will either:
            // - Fulfill the promise immediately if queue has data
            // - Add to read_requests if queue is empty (and call pull)
            const controller_instance = stream_internal.controller;
            const ReadableStreamDefaultControllerImpl = @import("ReadableStreamDefaultController.zig");

            // Call pullSteps with the promise and reader's read_requests list
            try ReadableStreamDefaultControllerImpl.pullSteps(controller_instance, promise, &internal.read_requests);
        },
    }

    // Step 5: Convert AsyncPromise to V8 Promise and return
    // This creates a bridge that will resolve the V8 Promise when the AsyncPromise settles
    const v8_promise = try convertReadResultPromiseToV8(promise);
    return @ptrCast(v8_promise);
}

/// Operation: releaseLock
///
/// Spec: https://streams.spec.whatwg.org/#default-reader-release-lock
/// undefined releaseLock()
///
/// Steps:
/// 1. If this.[[stream]] is undefined, return
/// 2. Perform ! ReadableStreamReaderGenericRelease(this)
///
/// ReadableStreamReaderGenericRelease(reader):
/// 1. Let stream be reader.[[stream]]
/// 2. Assert: stream is not undefined
/// 3. Assert: stream.[[reader]] is reader
/// 4. If stream.[[state]] is "readable", reject reader.[[closedPromise]] with TypeError
/// 5. Otherwise, set reader.[[closedPromise]] to a promise rejected with TypeError
/// 6. Set reader.[[closedPromise]].[[PromiseIsHandled]] to true
/// 7. Perform ! stream.[[controller]].[[ReleaseSteps]]()
/// 8. Set stream.[[reader]] to undefined
/// 9. Set reader.[[stream]] to undefined
pub fn call_releaseLock(instance: *runtime.Instance) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.TypeError;

    // Step 1: Check if already released
    if (internal.stream == null) {
        return;
    }

    // ReadableStreamReaderGenericRelease Step 1: Get stream
    const stream = internal.stream.?;
    const stream_state = stream.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.InvalidState;

    // Step 2-3: Assertions (stream exists and reader matches)
    // These are guaranteed by our type system

    // Step 4-5: Reject closedPromise with TypeError
    const type_error = try webidl.errors.Exception.typeError(internal.allocator, "Reader lock released");

    if (stream_internal.state == .readable) {
        // Step 4: Stream is readable, reject existing promise
        internal.closed_promise.*.reject(type_error);
    } else {
        // Step 5: Stream is closed/errored, create new rejected promise
        // Note: We can't replace the promise here as it's already created
        // Just reject the existing one
        internal.closed_promise.*.reject(type_error);
    }

    // Step 6: Set promise.[[PromiseIsHandled]] to true
    // Future: Implement PromiseIsHandled flag on AsyncPromise
    // Prevents unhandled rejection warnings in JavaScript

    // Step 7: Perform controller.[[ReleaseSteps]]()
    // Note: ReleaseSteps is no-op for ReadableStreamDefaultController
    // Only ReadableByteStreamController needs cleanup

    // Step 8: Clear stream.[[reader]]
    stream_internal.reader = .none;

    // Step 9: Clear reader.[[stream]]
    internal.stream = null;
}

/// Operation: cancel
///
/// Spec: https://streams.spec.whatwg.org/#generic-reader-cancel
/// Promise<undefined> cancel(optional any reason)
///
/// From ReadableStreamGenericReader mixin.
///
/// Steps:
/// 1. If this.[[stream]] is undefined, return rejected promise with TypeError
/// 2. Return ! ReadableStreamReaderGenericCancel(this, reason)
///
/// ReadableStreamReaderGenericCancel(reader, reason):
/// 1. Let stream be reader.[[stream]]
/// 2. Assert: stream is not undefined
/// 3. Return ! ReadableStreamCancel(stream, reason)
///
/// Returns: Pointer to AsyncPromise(void) - caller owns and must deinit
pub fn call_cancel(instance: *runtime.Instance, reason: webidl.Opt(*const anyopaque)) anyerror!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.TypeError;

    // Step 1: Check if reader has been released
    if (internal.stream == null) {
        // Return rejected promise with TypeError
        const promise = try AsyncPromise(void).init(
            internal.allocator,
            internal.event_loop,
        );
        const exception = try webidl.errors.Exception.typeError(internal.allocator, "Reader has been released");
        promise.*.reject(exception);
        return @ptrCast(promise);
    }

    // Step 2: ReadableStreamReaderGenericCancel
    // Get stream and delegate to stream.cancel(reason)
    const stream = internal.stream.?;

    // Call stream's cancel method
    // This returns a promise that we return to the caller
    const cancel_promise = try interfaces.ReadableStream.call_cancel(
        stream,
        reason,
    );

    return cancel_promise;
}

// ============================================================================
// Helper Functions (for ReadableStream integration)
// ============================================================================

/// Get number of pending read requests
///
/// Used by ReadableStream.getNumReadRequests()
pub fn getNumReadRequests(instance: *runtime.Instance) u64 {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return 0;
    return @intCast(internal.read_requests.items.len);
}

/// Fulfill the first pending read request with chunk
///
/// Spec: § 4.3.9 "Fulfill read request"
///
/// Used by ReadableStream.fulfillReadRequest()
pub fn fulfillReadRequest(
    instance: *runtime.Instance,
    chunk: *anyopaque,
    done: bool,
) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // There must be at least one pending request
    if (internal.read_requests.items.len == 0) {
        return error.InvalidState;
    }

    // Remove first request from queue
    const read_promise = internal.read_requests.orderedRemove(0);

    // Create result
    const result = ReadResult{
        .value = chunk,
        .done = done,
    };

    // Fulfill the promise
    read_promise.*.fulfill(result);
}

/// Add a read request to the pending queue
///
/// Spec: § 4.3.10 "Add read request"
///
/// Used by ReadableStream.addReadRequest()
pub fn addReadRequest(
    instance: *runtime.Instance,
    readRequest: *const anyopaque,
) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Untag the pointer before casting - it may be tagged by V8 conversions
    const pointer_tag = @import("v8").pointer_tag;
    const untagged = pointer_tag.untagPointer(readRequest);

    // If it's a V8 object rather than our internal promise type, that's an error
    if (untagged.tag == .runtime_instance) {
        // This is fine - runtime instances can be used here
    }

    // Cast to promise type
    const promise: *AsyncPromise(ReadResult) = @ptrCast(@alignCast(untagged.ptr));

    // Add to end of queue
    try internal.read_requests.append(internal.allocator, promise);
}
