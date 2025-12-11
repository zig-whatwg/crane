//! ReadableStream Async Iterator
//!
//! WHATWG Streams Standard: https://streams.spec.whatwg.org/#rs-asynciterator
//! Spec sections: lines 602-661 in streams.md
//!
//! Implements async iteration protocol for ReadableStream, enabling:
//! - `for await (const chunk of stream) { ... }`
//! - `stream.values({ preventCancel: true })`
//! - `stream[Symbol.asyncIterator]()`
//!
//! ## Type Safety Design
//!
//! This module maintains strict separation between V8 Promises and Zig AsyncPromises:
//!
//! - **V8 Promise**: JavaScript Promise object managed by V8's garbage collector.
//!   Returned by `ReadableStreamDefaultReader.read()` when called from JS.
//!
//! - **Zig AsyncPromise**: Zig-native promise type for async coordination.
//!   Created here to return to the async iterator machinery.
//!
//! The `next()` function bridges these by:
//! 1. Creating a Zig `AsyncPromise(IteratorResult)`
//! 2. Calling `reader.read()` which returns a V8 Promise (as runtime.JSValue)
//! 3. Using `v8_promise_chaining.chainToIteratorPromise()` to attach handlers
//! 4. When V8 Promise settles, handlers resolve/reject the Zig AsyncPromise
//!
//! This avoids the unsafe pattern of casting V8 Promise pointers directly to
//! AsyncPromise pointers, which causes type confusion and crashes.

const std = @import("std");
const runtime = @import("runtime");
const AsyncPromise = @import("async_promise").AsyncPromise;
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const reader_ops = @import("reader_ops");
const v8_promise_chaining = @import("v8_promise_chaining");

/// ReadableStreamAsyncIterator
///
/// This is NOT a WebIDL interface - it's an internal ES async iterator object
/// returned by ReadableStream.prototype[@@asyncIterator] and values().
///
/// Per spec (streams.md lines 602-610), this has:
/// - [[stream]]: The ReadableStream being iterated
/// - [[reader]]: ReadableStreamDefaultReader acquired during initialization
/// - [[preventCancel]]: Boolean flag controlling stream cancellation
pub const ReadableStreamAsyncIterator = struct {
    /// [[reader]]: ReadableStreamDefaultReader instance
    /// Acquired in initialization steps (spec line 604)
    reader: *runtime.Instance,

    /// [[preventCancel]]: boolean
    /// Controls whether return() cancels the stream (spec line 610)
    prevent_cancel: bool,

    allocator: std.mem.Allocator,

    pub fn deinit(self: *ReadableStreamAsyncIterator) void {
        // Note: reader is owned by stream, we just hold a reference
        self.allocator.destroy(self);
    }
};

/// Iterator result for next() method
/// Per ES spec, async iterators return { value, done } objects
pub const IteratorResult = struct {
    /// The value returned by the iterator (may be undefined if done is true)
    /// Uses runtime.JSValue for type-safe JavaScript value storage
    value: ?runtime.JSValue,
    done: bool,
};

/// Create ReadableStreamAsyncIterator
///
/// Per spec "asynchronous iterator initialization steps" (streams.md lines 602-610):
/// 1. Let reader be ? AcquireReadableStreamDefaultReader(stream)
/// 2. Set iterator's reader to reader
/// 3. Let preventCancel be args[0]["preventCancel"]
/// 4. Set iterator's prevent cancel to preventCancel
///
/// This is called by ReadableStream.values() and [@@asyncIterator]
pub fn create(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    stream: *runtime.Instance,
    prevent_cancel: bool,
) !*ReadableStreamAsyncIterator {
    // Step 1: Acquire reader from stream
    // NOTE: This calls ReadableStream.getReader() which in turn calls
    // AcquireReadableStreamDefaultReader
    const reader = try reader_ops.acquireReadableStreamDefaultReader(
        ctx,
        stream,
    );
    errdefer {
        // If we fail after acquiring reader, release it
        reader_ops.readableStreamDefaultReaderRelease(reader) catch {};
    }

    // Steps 2-4: Create iterator with reader and preventCancel
    const iterator = try allocator.create(ReadableStreamAsyncIterator);
    iterator.* = .{
        .reader = reader,
        .prevent_cancel = prevent_cancel,
        .allocator = allocator,
    };

    return iterator;
}

/// Get next iteration result
///
/// Per spec "get the next iteration result steps" (streams.md lines 612-640):
/// 1. Let reader be iterator's reader
/// 2. Assert: reader.[[stream]] is not undefined
/// 3. Let promise be a new promise
/// 4. Let readRequest be a new read request with:
///    - chunk steps: Resolve promise with chunk
///    - close steps: Release reader, resolve promise with end of iteration
///    - error steps: Release reader, reject promise with error
/// 5. Perform ! ReadableStreamDefaultReaderRead(this, readRequest)
/// 6. Return promise
///
/// **Implementation**: Creates a Zig AsyncPromise and bridges the V8 Promise
/// from reader.read() to it using v8_promise_chaining. This maintains type
/// safety by never casting V8 Promise pointers to AsyncPromise pointers.
pub fn next(
    iterator: *ReadableStreamAsyncIterator,
) !*AsyncPromise(IteratorResult) {
    // Step 1: Get reader
    const reader = iterator.reader;

    // Step 2: Assert reader.[[stream]] is not undefined
    // (ensured by type system)

    // Step 3: Create a new Zig AsyncPromise for the iterator result
    const event_loop = reader_ops.getReaderEventLoop(reader);
    const iterator_promise = try AsyncPromise(IteratorResult).init(
        iterator.allocator,
        event_loop,
    );
    errdefer iterator_promise.deinit();

    // Steps 4-5: Call reader.read() which returns a V8 Promise (as JSValue)
    // Use interface instead of impl (per Golden Rule #12)
    const ReadableStreamDefaultReader = interfaces.ReadableStreamDefaultReader;
    const read_result_js_value = try ReadableStreamDefaultReader.call_read(reader);

    // Bridge the V8 Promise to our Zig AsyncPromise
    // The V8 Promise will settle with { value, done } which we convert to IteratorResult
    try bridgeReadResultToIteratorPromise(
        iterator.allocator,
        read_result_js_value,
        iterator_promise,
    );

    // Step 6: Return promise
    return iterator_promise;
}

/// Context for bridging read result V8 Promise to Zig AsyncPromise(IteratorResult)
const ReadResultBridgeContext = struct {
    /// The Zig AsyncPromise to settle when V8 Promise settles
    promise: *AsyncPromise(IteratorResult),
    /// Allocator for cleanup
    allocator: std.mem.Allocator,
};

/// Bridge a V8 Promise (from reader.read()) to a Zig AsyncPromise(IteratorResult)
///
/// This sets up handlers on the V8 Promise that will resolve/reject the
/// AsyncPromise when the V8 Promise settles.
fn bridgeReadResultToIteratorPromise(
    allocator: std.mem.Allocator,
    read_result_js_value: runtime.JSValue,
    iterator_promise: *AsyncPromise(IteratorResult),
) !void {
    // Extract the V8 Promise pointer from the JSValue
    const v8_promise_ptr: *anyopaque = switch (read_result_js_value) {
        .handle => |h| h.ptr,
        .instance => |ptr| ptr,
        else => return error.TypeError,
    };

    // Create bridge context that will be passed to callbacks
    const bridge_ctx = try allocator.create(ReadResultBridgeContext);
    bridge_ctx.* = .{
        .promise = iterator_promise,
        .allocator = allocator,
    };
    errdefer allocator.destroy(bridge_ctx);

    // Chain handlers onto the V8 Promise using the promise chaining utility
    try v8_promise_chaining.chainToIteratorPromise(
        v8_promise_ptr,
        @ptrCast(bridge_ctx),
        onReadFulfilled,
        onReadRejected,
    );
}

/// Callback when read() V8 Promise fulfills
/// Resolves the Zig AsyncPromise with an IteratorResult
fn onReadFulfilled(ctx: *anyopaque, value: ?runtime.JSValue, done: bool) void {
    const bridge_ctx: *ReadResultBridgeContext = @ptrCast(@alignCast(ctx));
    defer bridge_ctx.allocator.destroy(bridge_ctx);

    // Fulfill the AsyncPromise with the iterator result
    bridge_ctx.promise.fulfill(.{
        .value = value,
        .done = done,
    });
}

/// Callback when read() V8 Promise rejects
/// Rejects the Zig AsyncPromise with the error
fn onReadRejected(ctx: *anyopaque, error_value: ?runtime.JSValue) void {
    const bridge_ctx: *ReadResultBridgeContext = @ptrCast(@alignCast(ctx));
    defer bridge_ctx.allocator.destroy(bridge_ctx);

    // Reject the AsyncPromise with an error
    // Convert the JS error to a WebIDL exception
    _ = error_value; // TODO: Extract error message from JS error
    bridge_ctx.promise.reject(webidl.errors.Exception{ .simple = .{
        .type = .TypeError,
        .message = "ReadableStream read failed",
    } });
}

/// Async iterator return (early termination)
///
/// Per spec "asynchronous iterator return steps" (streams.md lines 642-660):
/// 1. Let reader be iterator's reader
/// 2. Assert: reader.[[stream]] is not undefined
/// 3. Assert: reader.[[readRequests]] is empty (async iterator machinery guarantees this)
/// 4. If iterator's prevent cancel is false:
///    a. Let result be ! ReadableStreamReaderGenericCancel(reader, arg)
///    b. Perform ! ReadableStreamDefaultReaderRelease(reader)
///    c. Return result
/// 5. Perform ! ReadableStreamDefaultReaderRelease(reader)
/// 6. Return a promise resolved with undefined
pub fn returnEarly(
    iterator: *ReadableStreamAsyncIterator,
    reason: ?runtime.JSValue,
) !*AsyncPromise(void) {
    // Step 1: Get reader
    const reader = iterator.reader;

    // Steps 2-3: Asserts (guaranteed by async iterator machinery)

    // Step 4: If preventCancel is false, cancel the stream
    if (!iterator.prevent_cancel) {
        // Step 4a: Cancel the stream
        // Convert JSValue to anyopaque for the cancel operation
        const reason_ptr: ?*anyopaque = if (reason) |r| r.asEngineHandle() else null;
        const cancel_promise = try reader_ops.readableStreamReaderGenericCancel(
            reader,
            reason_ptr,
        );

        // Step 4b: Release reader
        try reader_ops.readableStreamDefaultReaderRelease(reader);

        // Step 4c: Return cancel promise
        return cancel_promise;
    }

    // Step 5: preventCancel is true, just release reader
    try reader_ops.readableStreamDefaultReaderRelease(reader);

    // Step 6: Return resolved promise
    const promise = try AsyncPromise(void).init(
        iterator.allocator,
        reader_ops.getReaderEventLoop(reader),
    );
    promise.fulfill({});
    return promise;
}
