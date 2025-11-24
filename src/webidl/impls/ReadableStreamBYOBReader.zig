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
const ReadableStreamBYOBReader = interfaces.ReadableStreamBYOBReader;

// BYOB-specific imports
const ReadIntoRequestModule = @import("streams_read_into_request");
const ReadIntoRequest = ReadIntoRequestModule.ReadIntoRequest;

pub const State = ReadableStreamBYOBReader.State;

pub const ImplError = error{
    TypeError,
    InvalidState,
    OutOfMemory,
    NotImplemented,
    RangeError,
    NullValue,
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
    /// TODO: Implement when Promise integration is ready
    closed_promise: ?*const anyopaque,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        self.read_into_requests.deinit(allocator);
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

    const state = instance.getState(StateType);
    state.own._internal = try allocator.create(InternalState);
    errdefer allocator.destroy(state.own._internal.?);

    const internal = state.own._internal.?;
    internal.allocator = allocator;
    internal.stream = null;
    internal.read_into_requests = .{};
    internal.read_into_requests.clearRetainingCapacity();
    internal.closed_promise = null;

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
    return internal.closed_promise orelse error.NotImplemented;
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
    // TODO: Check byte length when ArrayBufferView API is ready

    // Step 2: If buffer byte length is 0, reject with TypeError
    // TODO: Check buffer byte length

    // Step 3: If buffer is detached, reject with TypeError
    // TODO: Check buffer detachment

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
        // TODO: Return rejected promise with stream.[[storedError]]
        return error.InvalidState;
    }

    // Step 5: Return ! ReadableByteStreamControllerPullInto(stream.[[controller]], view, min, readIntoRequest)
    // Get the controller
    const controller = stream_internal.controller;

    // Create readIntoRequest
    // TODO: Create proper ReadIntoRequest callbacks for promise fulfillment
    const readIntoRequest = ReadIntoRequest.init(
        internal.allocator,
        chunkSteps,
        closeSteps,
        errorSteps,
        null, // context - TODO: pass promise context
    );

    // Call controller.pullInto()
    const ReadableByteStreamControllerImpl = @import("ReadableByteStreamController.zig");
    try ReadableByteStreamControllerImpl.pullInto(controller, view, min, readIntoRequest);

    // TODO: Return promise that will be fulfilled by readIntoRequest
    return error.NotImplemented;
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
    // TODO: Check controller type

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
        // TODO: Create promise
    } else if (stream_int.state == .closed) {
        // Step 4: Otherwise, if stream.[[state]] is "closed"
        // Step 4.1: Set reader.[[closedPromise]] to a promise resolved with undefined
        // TODO: Create resolved promise
    } else {
        // Step 5: Otherwise (state is "errored")
        // Step 5.1: Set reader.[[closedPromise]] to a promise rejected with stream.[[storedError]]
        // TODO: Create rejected promise
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

    // Step 3: If stream.[[state]] is "readable", reject reader.[[closedPromise]] with TypeError
    // TODO: Reject closedPromise

    // Step 4: Otherwise, set reader.[[closedPromise]] to a promise rejected with TypeError
    // TODO: Set closedPromise

    // Step 5: Set reader.[[closedPromise]].[[PromiseIsHandled]] to true
    // TODO: Mark promise as handled

    // Step 6: Perform ! stream.[[controller]].[[ReleaseSteps]]()
    // TODO: Call controller release steps

    // Step 7: Set stream.[[reader]] to undefined
    const stream_state = stream.getState(interfaces.ReadableStream.State);
    if (stream_state.own._internal) |stream_internal| {
        const ReadableStreamImpl = @import("ReadableStream.zig");
        stream_internal.reader = ReadableStreamImpl.Reader.none;
    }

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
    for (internal.read_into_requests.items) |request| {
        // Step 3.1: Perform readIntoRequest's error steps, given e
        // TODO: Call error steps on readIntoRequest
        _ = request;
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
    // TODO: Implement ReadableStream.cancel() properly
    _ = reason;
    _ = stream;
    return error.NotImplemented;
}

/// ReadIntoRequest callback stubs
///
/// TODO: Implement proper promise fulfillment
fn chunkSteps(ctx: ?*anyopaque, chunk: ReadIntoRequestModule.ArrayBufferView) void {
    _ = ctx;
    _ = chunk;
    // TODO: Fulfill promise with chunk
}

fn closeSteps(ctx: ?*anyopaque) void {
    _ = ctx;
    // TODO: Fulfill promise with done=true
}

fn errorSteps(ctx: ?*anyopaque, error_value: ReadIntoRequestModule.Value) void {
    _ = ctx;
    _ = error_value;
    // TODO: Reject promise with error
}

// ============================================================================
// Helper Functions for Controller Integration
// ============================================================================

/// Add a read-into request to the reader's queue
pub fn addReadIntoRequest(instance: *runtime.Instance, request: *const anyopaque) !void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    try internal.read_into_requests.append(request);
}

/// Get the number of pending read-into requests
pub fn getNumReadIntoRequests(instance: *runtime.Instance) usize {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return 0;
    return internal.read_into_requests.items.len;
}
