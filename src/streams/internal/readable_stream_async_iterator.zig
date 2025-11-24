//! ReadableStream Async Iterator
//!
//! WHATWG Streams Standard: https://streams.spec.whatwg.org/#rs-asynciterator
//! Spec sections: lines 602-661 in streams.md
//!
//! Implements async iteration protocol for ReadableStream, enabling:
//! - `for await (const chunk of stream) { ... }`
//! - `stream.values({ preventCancel: true })`
//! - `stream[Symbol.asyncIterator]()`

const std = @import("std");
const runtime = @import("runtime");
const AsyncPromise = @import("async_promise").AsyncPromise;
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const reader_ops = @import("reader_ops");

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
    value: ?*anyopaque,
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
        allocator,
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
pub fn next(
    iterator: *ReadableStreamAsyncIterator,
) !*AsyncPromise(IteratorResult) {
    // Step 1: Get reader
    const reader = iterator.reader;

    // Step 2: Assert reader.[[stream]] is not undefined
    // (ensured by type system - reader always has stream reference)

    // Step 3: Create promise for the result
    const promise = try AsyncPromise(IteratorResult).init(
        iterator.allocator,
        // Get event loop from reader
        reader_ops.getReaderEventLoop(reader),
    );
    errdefer promise.deinit();

    // Step 4: Create read request with chunk/close/error steps
    // Step 5: Perform ReadableStreamDefaultReaderRead
    const ReadRequest = struct {
        promise_ref: *AsyncPromise(IteratorResult),
        reader_ref: *runtime.Instance,

        pub fn chunkSteps(ctx: *anyopaque, chunk: *anyopaque) void {
            const req: *@This() = @ptrCast(@alignCast(ctx));
            // Resolve promise with { value: chunk, done: false }
            req.promise_ref.fulfill(.{
                .value = chunk,
                .done = false,
            });
        }

        pub fn closeSteps(ctx: *anyopaque) void {
            const req: *@This() = @ptrCast(@alignCast(ctx));
            // Release reader
            reader_ops.readableStreamDefaultReaderRelease(req.reader_ref) catch {};
            // Resolve promise with { value: undefined, done: true }
            req.promise_ref.fulfill(.{
                .value = null,
                .done = true,
            });
        }

        pub fn errorSteps(ctx: *anyopaque, err: *anyopaque) void {
            const req: *@This() = @ptrCast(@alignCast(ctx));
            // Release reader
            reader_ops.readableStreamDefaultReaderRelease(req.reader_ref) catch {};
            // Reject promise with error
            req.promise_ref.reject(err);
        }
    };

    const request = try iterator.allocator.create(ReadRequest);
    request.* = .{
        .promise_ref = promise,
        .reader_ref = reader,
    };

    // Perform the read operation
    try reader_ops.readableStreamDefaultReaderRead(
        reader,
        request,
        ReadRequest.chunkSteps,
        ReadRequest.closeSteps,
        ReadRequest.errorSteps,
    );

    // Step 6: Return promise
    return promise;
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
    reason: ?*anyopaque,
) !*AsyncPromise(void) {
    // Step 1: Get reader
    const reader = iterator.reader;

    // Steps 2-3: Asserts (guaranteed by async iterator machinery)

    // Step 4: If preventCancel is false, cancel the stream
    if (!iterator.prevent_cancel) {
        // Step 4a: Cancel the stream
        const cancel_promise = try reader_ops.readableStreamReaderGenericCancel(
            reader,
            reason,
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
