//! Implementation for ReadableStreamBYOBReader interface
//!
//! Spec: https://streams.spec.whatwg.org/#byob-reader-class
//!
//! Allows reading bytes with zero-copy optimization using user-provided buffers.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const arraybuffer_view = runtime.arraybuffer_view;
const ReadableStreamBYOBReader = interfaces.ReadableStreamBYOBReader;

// BYOB-specific imports
const ReadIntoRequestModule = @import("streams_read_into_request");
const ReadIntoRequest = ReadIntoRequestModule.ReadIntoRequest;

// Promise integration
const event_loop = @import("streams_event_loop");
const AsyncPromise = @import("streams_async_promise").AsyncPromise;
const ReadIntoRequestWithPromise = @import("streams_read_into_request_promise").ReadIntoRequestWithPromise;
const ReadIntoResult = @import("streams_read_into_request_promise").ReadIntoResult;

pub const State = ReadableStreamBYOBReader.State;

pub const ImplError = error{
    TypeError,
    InvalidState,
    OutOfMemory,
    NotImplemented,
    RangeError,
    NullValue,
    BufferDetached, // From ReadableByteStreamController.pullInto
    NoEventLoop,
};

/// Type alias for read-into requests list
const ReadIntoRequestsList = std.ArrayList(*const anyopaque);

/// Internal state for ReadableStreamBYOBReader
///
/// Spec: § 4.5 "ReadableStreamBYOBReader"
///
/// Note: This includes fields from ReadableStreamGenericReader mixin
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// [[stream]]: The stream being read (null if released)
    stream: ?*runtime.Instance,

    /// [[readIntoRequests]]: List of pending read-into requests
    /// TODO: Use proper ReadIntoRequest type when available
    read_into_requests: ReadIntoRequestsList,

    /// [[closedPromise]]: Promise for the reader's closed state
    closed_promise: *AsyncPromise(void),

    /// Event loop for promise scheduling
    loop_instance: event_loop.EventLoop,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        self.read_into_requests.deinit(allocator);
        self.closed_promise.deinit();
    }
};

/// Initialize instance
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Get event loop from context
    const loop = ctx.getEventLoop() catch return error.NoEventLoop;

    const state = instance.getState(StateType);
    state.own._internal = try allocator.create(InternalState);
    errdefer allocator.destroy(state.own._internal.?);

    const internal = state.own._internal.?;
    internal.allocator = allocator;
    internal.stream = null;
    internal.read_into_requests = .{};
    internal.read_into_requests.clearRetainingCapacity();
    internal.loop_instance = loop;

    // Initialize closed promise (will be fulfilled/rejected during setup)
    internal.closed_promise = try AsyncPromise(void).init(allocator, loop);

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(internal.allocator);
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
///
/// Spec: § 4.5.2 "new ReadableStreamBYOBReader(stream)"
pub fn call_constructor(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    stream: *runtime.Instance,
) !*runtime.Instance {
    // Note: Event loop is now obtained from context inside init()
    _ = stream.getState(interfaces.ReadableStream.State);

    const instance = try init(allocator, State, &ReadableStreamBYOBReader.vtable, ctx);
    errdefer deinit(instance);

    // Step 1: Perform ? SetUpReadableStreamBYOBReader(this, stream)
    try setUpReadableStreamBYOBReader(instance, stream);

    return instance;
}

// ============================================================================
// WebIDL Interface Methods
// ============================================================================

/// Getter for closed
///
/// Spec: § 4.5.2 "The closed getter steps are:"
pub fn get_closed(instance: *runtime.Instance) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Return this.[[closedPromise]]
    return @ptrCast(internal.closed_promise);
}

/// Operation: read
///
/// Spec: § 4.5.3 "The read(view, options) method steps are:"
pub fn call_read(
    instance: *runtime.Instance,
    view: typedefs.ArrayBufferView,
    options: dictionaries.ReadableStreamBYOBReaderReadOptions,
) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: If view.[[ByteLength]] is 0, reject with TypeError
    const view_byte_length = arraybuffer_view.getViewByteLength(view);
    if (view_byte_length == 0) {
        return error.TypeError;
    }

    // Step 2: If buffer byte length is 0, reject with TypeError
    // Step 3: If buffer is detached, reject with TypeError
    if (arraybuffer_view.isViewDetached(view)) {
        return error.TypeError;
    }

    // Step 4: If stream is undefined, reject with TypeError
    if (internal.stream == null) {
        return error.TypeError;
    }

    // Step 5: Parse options (default min = 1)
    const min = options.min orelse 1;

    // Step 6: Return ReadableStreamBYOBReaderRead(this, view, min)
    return try readInternal(instance, view, min);
}

/// Operation: releaseLock
///
/// Spec: § 4.5.3 "The releaseLock() method steps are:"
pub fn call_releaseLock(instance: *runtime.Instance) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: If this.[[stream]] is undefined, return
    if (internal.stream == null) {
        return;
    }

    // Step 2: Perform ! ReadableStreamBYOBReaderRelease(this)
    readableStreamBYOBReaderRelease(internal);
}

/// Operation: cancel
///
/// Spec: § 4.5.3 "The cancel(reason) method steps are:"
pub fn call_cancel(instance: *runtime.Instance, reason: *const anyopaque) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: If this.[[stream]] is undefined, reject with TypeError
    if (internal.stream == null) {
        return error.TypeError;
    }

    // Step 2: Return ! ReadableStreamReaderGenericCancel(this, reason)
    return readableStreamReaderGenericCancel(internal, reason);
}

// ============================================================================
// Internal Algorithms
// ============================================================================

/// ReadableStreamBYOBReaderRead(reader, view, min)
///
/// Spec: § 4.5.4 "Read with BYOB"
fn readInternal(
    instance: *runtime.Instance,
    view: typedefs.ArrayBufferView,
    min: u64,
) ImplError!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Let stream be reader.[[stream]]
    const stream = internal.stream orelse return error.TypeError;

    // Step 2: Assert: stream is not undefined
    // (Checked above)

    // Step 3: Set stream.[[disturbed]] to true
    const stream_state = stream.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.InvalidState;
    stream_internal.disturbed = true;

    // Step 4: If stream.[[state]] is "errored", reject promise with stored error
    if (stream_internal.state == .errored) {
        // Create a rejected promise with the stored error
        const promise = try AsyncPromise(ReadIntoResult).init(
            internal.allocator,
            internal.loop_instance,
        );
        // Reject with stored error (as opaque pointer for now)
        // In full JS runtime integration, this would preserve the original error
        const exception = webidl.errors.Exception{
            .simple = .{ .type = .TypeError, .message = "Stream is in errored state" },
        };
        promise.reject(exception);
        return @ptrCast(promise);
    }

    // Step 5: Return ! ReadableByteStreamControllerPullInto(stream.[[controller]], view, min, readIntoRequest)

    // Create a promise for this read operation
    const promise = try AsyncPromise(ReadIntoResult).init(
        internal.allocator,
        internal.loop_instance,
    );

    // Create promise context that will fulfill the promise
    const promise_ctx = try internal.allocator.create(PromiseContext);
    promise_ctx.* = .{
        .promise = promise,
        .view = view,
        .allocator = internal.allocator,
    };

    // Create readIntoRequest with callbacks that fulfill the promise
    const readIntoRequest = ReadIntoRequest.init(
        internal.allocator,
        promiseChunkSteps,
        promiseCloseSteps,
        promiseErrorSteps,
        @ptrCast(promise_ctx),
    );

    // Get the controller
    const controller = stream_internal.controller;

    // Call controller.pullInto()
    const ReadableByteStreamControllerImpl = @import("ReadableByteStreamController.zig");
    try ReadableByteStreamControllerImpl.pullInto(controller, view, min, readIntoRequest);

    // Return the promise (caller will wait for it to fulfill)
    return @ptrCast(promise);
}

/// SetUpReadableStreamBYOBReader(reader, stream)
///
/// Spec: § 4.5.4 "Set up BYOB reader"
fn setUpReadableStreamBYOBReader(
    instance: *runtime.Instance,
    stream: *runtime.Instance,
) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: If ! IsReadableStreamLocked(stream) is true, throw TypeError
    const stream_state = stream.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return error.InvalidState;

    const ReadableStreamImpl = @import("ReadableStream.zig");
    if (stream_internal.reader != ReadableStreamImpl.Reader.none) {
        return error.TypeError;
    }

    // Step 2: If stream.[[controller]] does not implement ReadableByteStreamController, throw TypeError
    // Check if the controller is a ReadableByteStreamController by comparing vtables
    const controller = stream_internal.controller;
    if (controller.vtable != &interfaces.ReadableByteStreamController.vtable) {
        // Controller is not a ReadableByteStreamController (likely a DefaultController)
        return error.TypeError;
    }

    // Step 3: Perform ! ReadableStreamReaderGenericInitialize(reader, stream)
    try readableStreamReaderGenericInitialize(instance, stream, stream_internal);

    // Step 4: Set reader.[[readIntoRequests]] to a new empty list
    internal.read_into_requests.clearRetainingCapacity();
}

/// ReadableStreamReaderGenericInitialize(reader, stream)
///
/// Spec: § 4.5.4 "Initialize generic reader"
fn readableStreamReaderGenericInitialize(
    reader_instance: *runtime.Instance,
    stream_instance: *runtime.Instance,
    stream_internal: *anyopaque,
) ImplError!void {
    const reader_state = reader_instance.getState(State);
    const reader_internal = reader_state.own._internal orelse return error.InvalidState;

    // Step 1: Set reader.[[stream]] to stream
    reader_internal.stream = stream_instance;

    // Step 2: Set stream.[[reader]] to reader
    const stream_state = stream_instance.getState(interfaces.ReadableStream.State);
    const stream_int = stream_state.own._internal orelse return error.InvalidState;
    const ReadableStreamImpl = @import("ReadableStream.zig");
    stream_int.reader = ReadableStreamImpl.Reader{ .byob = reader_instance };

    // Step 3: If stream.[[state]] is "readable"
    _ = stream_internal;
    if (stream_int.state == .readable) {
        // Step 3.1: Set reader.[[closedPromise]] to a new promise
        // Already initialized in init(), will be fulfilled when stream closes
    } else if (stream_int.state == .closed) {
        // Step 4: Otherwise, if stream.[[state]] is "closed"
        // Step 4.1: Set reader.[[closedPromise]] to a promise resolved with undefined
        reader_internal.closed_promise.fulfill({});
    } else {
        // Step 5: Otherwise (state is "errored")
        // Step 5.1: Set reader.[[closedPromise]] to a promise rejected with stream.[[storedError]]
        const exception = webidl.errors.Exception{
            .simple = .{ .type = .TypeError, .message = "Stream is in errored state" },
        };
        reader_internal.closed_promise.reject(exception);
    }
}

/// ReadableStreamBYOBReaderRelease(reader)
///
/// Spec: § 4.5.4 "Release BYOB reader"
fn readableStreamBYOBReaderRelease(internal: *InternalState) void {
    // Step 1: Perform ! ReadableStreamReaderGenericRelease(reader)
    readableStreamReaderGenericRelease(internal);

    // Step 2: Let e be a new TypeError exception
    // Step 3: Perform ! ReadableStreamBYOBReaderErrorReadIntoRequests(reader, e)
    readableStreamBYOBReaderErrorReadIntoRequests(internal);
}

/// ReadableStreamReaderGenericRelease(reader)
///
/// Spec: § 4.5.4 "Release generic reader"
fn readableStreamReaderGenericRelease(internal: *InternalState) void {
    // Step 1: Let stream be reader.[[stream]]
    const stream = internal.stream orelse return;

    // Step 2: Assert: stream.[[reader]] is reader
    // (Implicit)

    const stream_state = stream.getState(interfaces.ReadableStream.State);
    const stream_internal = stream_state.own._internal orelse return;

    // Step 3: If stream.[[state]] is "readable", reject reader.[[closedPromise]] with TypeError
    if (stream_internal.state == .readable) {
        const exception = webidl.errors.Exception{
            .simple = .{
                .type = .TypeError,
                .message = "Reader was released while stream was readable",
            },
        };
        internal.closed_promise.reject(exception);
    } else {
        // Step 4: Otherwise, set reader.[[closedPromise]] to a promise rejected with TypeError
        // Note: We can't replace the promise (it's already shared), so we reject the existing one
        const exception = webidl.errors.Exception{
            .simple = .{
                .type = .TypeError,
                .message = "Reader was released",
            },
        };
        internal.closed_promise.reject(exception);
    }

    // Step 5: Set reader.[[closedPromise]].[[PromiseIsHandled]] to true
    // Note: AsyncPromise doesn't have this flag yet; this prevents unhandled rejection warnings
    // Future: Add PromiseIsHandled flag to AsyncPromise

    // Step 6: Perform ! stream.[[controller]].[[ReleaseSteps]]()
    // For ReadableByteStreamController, this clears pending pull-into descriptors
    const ReadableByteStreamControllerImpl = @import("ReadableByteStreamController.zig");
    ReadableByteStreamControllerImpl.releaseSteps(stream_internal.controller);

    // Step 7: Set stream.[[reader]] to undefined
    const ReadableStreamImpl = @import("ReadableStream.zig");
    stream_internal.reader = ReadableStreamImpl.Reader.none;

    // Step 8: Set reader.[[stream]] to undefined
    internal.stream = null;
}

/// ReadableStreamBYOBReaderErrorReadIntoRequests(reader, e)
///
/// Spec: § 4.5.4 "Error read-into requests"
fn readableStreamBYOBReaderErrorReadIntoRequests(internal: *InternalState) void {
    // Step 1: Let readIntoRequests be reader.[[readIntoRequests]]
    // Step 2: Set reader.[[readIntoRequests]] to a new empty list
    defer internal.read_into_requests.clearRetainingCapacity();

    // Step 3: For each readIntoRequest of readIntoRequests
    for (internal.read_into_requests.items) |request_ptr| {
        // Step 3.1: Perform readIntoRequest's error steps, given e
        // Cast to ReadIntoRequest and call error steps with a TypeError
        const request: *const ReadIntoRequest = @ptrCast(@alignCast(request_ptr));
        // Create error value for the callback
        const error_value = ReadIntoRequestModule.Value{ .string = "Reader was released" };
        request.executeErrorSteps(error_value);
    }
}

/// ReadableStreamReaderGenericCancel(reader, reason)
///
/// Spec: § 4.5.4 "Cancel with reason"
fn readableStreamReaderGenericCancel(internal: *InternalState, reason: *const anyopaque) ImplError!*const anyopaque {
    // Step 1: Let stream be reader.[[stream]]
    const stream = internal.stream orelse return error.InvalidState;

    // Step 2: Assert: stream is not undefined
    // (Checked above)

    // Step 3: Return ! ReadableStreamCancel(stream, reason)
    // Note: We need to call the internal readableStreamCancel, not call_cancel
    // because call_cancel checks if stream is locked (and reader holds the lock)
    const ReadableStreamImpl = @import("ReadableStream.zig");
    return ReadableStreamImpl.readableStreamCancelFromReader(stream, reason);
}

// ============================================================================
// Promise Integration Callbacks
// ============================================================================

/// Context for promise-based read operations
const PromiseContext = struct {
    promise: *AsyncPromise(ReadIntoResult),
    view: typedefs.ArrayBufferView,
    allocator: std.mem.Allocator,
};

/// Chunk steps callback: Fulfill promise with ReadIntoResult { view, done: false }
fn promiseChunkSteps(ctx: ?*anyopaque, view: ReadIntoRequestModule.ArrayBufferView) void {
    const promise_ctx: *PromiseContext = @ptrCast(@alignCast(ctx orelse return));
    // Create a mutable copy to pass as pointer
    var view_mut = view;
    const result = ReadIntoResult{
        .view = @ptrCast(&view_mut),
        .done = false,
    };
    promise_ctx.promise.fulfill(result);

    // Clean up context
    promise_ctx.allocator.destroy(promise_ctx);
}

/// Close steps callback: Fulfill promise with ReadIntoResult { view, done: true }
fn promiseCloseSteps(ctx: ?*anyopaque) void {
    const promise_ctx: *PromiseContext = @ptrCast(@alignCast(ctx orelse return));
    const result = ReadIntoResult{
        .view = @ptrCast(@constCast(&promise_ctx.view)),
        .done = true,
    };
    promise_ctx.promise.fulfill(result);

    // Clean up context
    promise_ctx.allocator.destroy(promise_ctx);
}

/// Error steps callback: Reject promise with error
///
/// Converts the error value to a webidl.errors.Exception and rejects the promise.
/// Spec: Promise is rejected with the error value from the stream.
fn promiseErrorSteps(ctx: ?*anyopaque, error_value: ReadIntoRequestModule.Value) void {
    const promise_ctx: *PromiseContext = @ptrCast(@alignCast(ctx orelse return));

    // Convert error value to Exception
    const exception = convertValueToException(promise_ctx.allocator, error_value) catch {
        // Fallback: If conversion fails, create generic TypeError
        const fallback = webidl.errors.Exception.typeError(promise_ctx.allocator, "Stream read operation failed") catch {
            // Even fallback failed - just clean up and return
            promise_ctx.allocator.destroy(promise_ctx);
            return;
        };
        promise_ctx.promise.reject(fallback);
        promise_ctx.allocator.destroy(promise_ctx);
        return;
    };

    // Reject promise with the exception
    promise_ctx.promise.reject(exception);

    // Clean up context
    promise_ctx.allocator.destroy(promise_ctx);
}

/// Convert ReadIntoRequestModule.Value to webidl.errors.Exception
fn convertValueToException(
    allocator: std.mem.Allocator,
    value: ReadIntoRequestModule.Value,
) !webidl.errors.Exception {
    return switch (value) {
        .string => |s| try webidl.errors.Exception.fromString(allocator, s),
        .bytes => |b| {
            // Convert bytes to string first
            const str = try allocator.dupe(u8, b);
            defer allocator.free(str);
            return try webidl.errors.Exception.fromString(allocator, str);
        },
        else => try webidl.errors.Exception.typeError(allocator, "Stream error"),
    };
}

// ============================================================================
// Helper Functions for Controller Integration
// ============================================================================

/// Add a read-into request to the reader's queue
pub fn addReadIntoRequest(instance: *runtime.Instance, request: *const anyopaque) !void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    try internal.read_into_requests.append(internal.allocator, request);
}

/// Get the number of pending read-into requests
pub fn getNumReadIntoRequests(instance: *runtime.Instance) usize {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return 0;
    return internal.read_into_requests.items.len;
}

/// ReadableStreamFulfillReadIntoRequest(stream, chunk, done)
///
/// Spec: § 4.5.4 "Fulfill read-into request"
///
/// Fulfills the first pending read-into request with the provided chunk and done flag.
/// Called by ReadableByteStreamController when data is available for a BYOB read.
pub fn fulfillReadIntoRequest(instance: *runtime.Instance, chunk: *anyopaque, done: bool) ImplError!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: Assert readIntoRequests is not empty
    if (internal.read_into_requests.items.len == 0) {
        return error.InvalidState;
    }

    // Step 2: Let readIntoRequest be reader.[[readIntoRequests]][0]
    // Step 3: Remove readIntoRequest from reader.[[readIntoRequests]]
    const request_ptr = internal.read_into_requests.orderedRemove(0);

    // Cast to ReadIntoRequest
    const request: *const ReadIntoRequest = @ptrCast(@alignCast(request_ptr));

    // Step 4: If done is true, perform readIntoRequest's close steps
    // Step 5: Otherwise, perform readIntoRequest's chunk steps with chunk
    if (done) {
        request.executeCloseSteps();
    } else {
        // Create ArrayBufferView from the chunk pointer
        // The chunk is expected to be a V8 TypedArray or our internal buffer
        // For now, we pass the raw pointer - the callback will interpret it
        const view = ReadIntoRequestModule.ArrayBufferView{
            .data = @as([*]u8, @ptrCast(chunk))[0..0], // Placeholder - actual data in chunk
            .offset = 0,
            .length = 0,
        };
        _ = view;

        // The chunk is the actual view pointer created by the controller
        // Cast it appropriately for the callback
        const view_ptr: *ReadIntoRequestModule.ArrayBufferView = @ptrCast(@alignCast(chunk));
        request.executeChunkSteps(view_ptr.*);
    }
}
