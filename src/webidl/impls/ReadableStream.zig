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

pub const State = ReadableStream.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    RangeError,
    InvalidState,
    OutOfMemory,
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
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, underlyingSource: *const anyopaque, strategy: dictionaries.QueuingStrategy) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &ReadableStream.vtable, ctx);
    errdefer deinit(instance);

    _ = underlyingSource;
    _ = strategy;
    // TODO: Implement constructor logic with parameters

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
pub fn call_from(instance: *runtime.Instance, asyncIterable: *const anyopaque) ImplError!*runtime.Instance {
    _ = instance;
    _ = asyncIterable;
    return error.NotImplemented;
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
        // TODO: Reject with actual stream.[[storedError]]
        const exception = try webidl.errors.Exception.typeError(internal.allocator, "Stream is errored");
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
    // TODO: Implement controller.[[CancelSteps]]
    // For now, return a resolved promise
    _ = reason;

    const promise = try AsyncPromise(void).init(
        internal.allocator,
        internal.event_loop,
    );

    // Step 8: React to sourceCancelPromise with fulfillment that returns undefined
    // For now, just fulfill immediately
    // TODO: Chain promises properly when controller.[[CancelSteps]] is implemented
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

    // TODO: Reject reader.[[closedPromise]] if reader exists
    // TODO: Reject all pending read requests with e
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
    // TODO: Once we have proper option handling, check options.mode
    // For now, assume default mode (no mode specified)
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
