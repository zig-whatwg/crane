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
const ReadableStreamDefaultReader = interfaces.ReadableStreamDefaultReader;

// Import streams infrastructure
const streams_common = @import("streams_common");
const AsyncPromise = @import("streams_async_promise").AsyncPromise;

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
    /// [[stream]]: ReadableStream or undefined if released
    /// From ReadableStreamGenericReader mixin
    stream: ?*runtime.Instance,

    /// [[closedPromise]]: Promise<undefined> that fulfills when stream closes
    /// From ReadableStreamGenericReader mixin
    closed_promise: *AsyncPromise(void),

    /// [[readRequests]]: List of pending read promises
    read_requests: std.ArrayList(*AsyncPromise(ReadResult)),

    /// Event loop for async operations
    /// TODO: This should come from runtime.Context once event loop support is added
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
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
///
/// Spec: https://streams.spec.whatwg.org/#default-reader-constructor
/// new ReadableStreamDefaultReader(stream)
///
/// Steps:
/// 1. Perform ? SetUpReadableStreamDefaultReader(this, stream)
///
/// TODO: Stream instance (runtime.Instance) is not accessible from interfaces.ReadableStream.
/// This needs to be addressed - either:
/// 1. Change constructor signature to accept *runtime.Instance
/// 2. Add a way to get *runtime.Instance from interfaces.ReadableStream
/// 3. Store stream reference differently
pub fn call_constructor(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    stream: interfaces.ReadableStream,
) !*runtime.Instance {
    // Create instance
    const instance = try init(allocator, State, &ReadableStreamDefaultReader.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Get event loop from context (required for async operations)
    const event_loop = try ctx.getEventLoop();

    // The stream parameter is already an interface struct, not an instance
    // We need to store it appropriately
    // TODO: Properly handle stream reference - need to get the runtime.Instance
    // for the stream to store it
    _ = stream;

    // TODO: Call SetUpReadableStreamDefaultReader(this, stream)
    // This requires:
    // 1. Check if stream is locked (if so, throw TypeError)
    // 2. Set stream.[[reader]] to this
    // 3. Initialize closed promise
    // 4. Initialize read requests list

    // Create closed promise
    const closed_promise = try AsyncPromise(void).init(allocator, event_loop);
    errdefer closed_promise.deinit();

    // Create InternalState
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = InternalState{
        .stream = null, // TODO: Store stream reference properly (need runtime.Instance)
        .closed_promise = closed_promise,
        .read_requests = std.ArrayList(*AsyncPromise(ReadResult)){},
        .event_loop = event_loop,
        .allocator = allocator,
    };

    state.own._internal = internal;

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
pub fn get_closed(instance: *runtime.Instance) !*const anyopaque {
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
/// 2. Return ! ReadableStreamDefaultReaderRead(this)
///
/// Returns: Pointer to AsyncPromise(ReadResult) - caller owns and must deinit
///
/// TODO: Stream instance access needed to implement full algorithm
pub fn call_read(instance: *runtime.Instance) !*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.TypeError;

    // Step 1: Check if reader has been released
    if (internal.stream == null) {
        // TODO: Return rejected promise with TypeError
        // For now, return Zig error until webidl.errors is accessible
        return error.TypeError;
    }

    // Step 2: Perform ReadableStreamDefaultReaderRead(this)
    // TODO: Implement full read algorithm:
    // - If stream has queued chunks, return fulfilled promise immediately
    // - Otherwise, create pending promise and add to readRequests
    // - The controller will fulfill this promise when data arrives

    // Placeholder: return pending promise and add to read requests
    const promise = try AsyncPromise(ReadResult).init(
        internal.allocator,
        internal.event_loop,
    );
    try internal.read_requests.append(internal.allocator, promise);

    return @ptrCast(promise);
}

/// Operation: releaseLock
///
/// Spec: https://streams.spec.whatwg.org/#default-reader-release-lock
/// undefined releaseLock()
///
/// Steps:
/// 1. If this.[[stream]] is undefined, return
/// 2. Perform ! ReadableStreamReaderGenericRelease(this)
pub fn call_releaseLock(instance: *runtime.Instance) !void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.TypeError;

    // Step 1: Check if already released
    if (internal.stream == null) {
        return;
    }

    // Step 2: Perform generic release
    // TODO: Implement ReadableStreamReaderGenericRelease
    // This involves:
    // - Rejecting closed promise if stream is readable
    // - Calling controller release steps
    // - Clearing stream.[[reader]]
    // - Clearing this.[[stream]]

    // Placeholder
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
/// Returns: Pointer to AsyncPromise(void) - caller owns and must deinit
///
/// TODO: Stream instance access needed to implement full algorithm
pub fn call_cancel(instance: *runtime.Instance, reason: *const anyopaque) !*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.TypeError;

    // Step 1: Check if reader has been released
    if (internal.stream == null) {
        // TODO: Return rejected promise with TypeError
        // For now, return Zig error until webidl.errors is accessible
        return error.TypeError;
    }

    // Step 2: Perform ReadableStreamReaderGenericCancel(this, reason)
    // TODO: Implement generic cancel algorithm:
    // - Get stream from internal.stream
    // - Call stream's cancel method with reason
    // - Return the promise from stream.cancel()
    _ = reason;

    // Placeholder: return pending promise
    const promise = try AsyncPromise(void).init(
        internal.allocator,
        internal.event_loop,
    );
    return @ptrCast(promise);
}
