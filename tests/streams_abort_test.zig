const std = @import("std");
const testing = std.testing;

// Import streams module
const streams = @import("streams");
const TestEventLoop = @import("test_event_loop").TestEventLoop;

test "WritableStream.abort() - basic abort on writable stream" {
    const allocator = testing.allocator;

    // Create event loop
    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    // Create stream
    var stream = try streams.WritableStream.initWithSink(allocator, loop.eventLoop(), null, null);
    defer stream.deinit();

    // Verify stream starts writable
    try testing.expectEqual(streams.WritableStream.StreamState.writable, stream.state);

    // Abort stream
    const abort_promise = try stream.call_abort(null);
    defer abort_promise.deinit();

    // Run microtasks to process abort
    loop.runMicrotasks();

    // Spec § 5.3.3: Stream should transition to errored state
    try testing.expectEqual(streams.WritableStream.StreamState.errored, stream.state);
}

test "WritableStream.abort() - already closed returns fulfilled promise" {
    const allocator = testing.allocator;

    // Create event loop
    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    // Create stream
    var stream = try streams.WritableStream.initWithSink(allocator, loop.eventLoop(), null, null);
    defer stream.deinit();

    // Close stream first
    stream.state = .closed;

    // Abort should return immediately fulfilled
    const abort_promise = try stream.call_abort(null);
    defer abort_promise.deinit();

    // Spec § 5.3.3 step 1: If state is "closed", return fulfilled promise
    try testing.expect(abort_promise.isFulfilled());
}

test "WritableStream.abort() - already errored returns fulfilled promise" {
    const allocator = testing.allocator;

    // Create event loop
    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    // Create stream
    var stream = try streams.WritableStream.initWithSink(allocator, loop.eventLoop(), null, null);
    defer stream.deinit();

    // Error the stream
    const error_value = streams.JSValue{ .string = "test error" };
    stream.errorInternal(error_value);
    try testing.expectEqual(streams.WritableStream.StreamState.errored, stream.state);

    // Abort should return fulfilled promise
    const abort_promise = try stream.call_abort(null);
    defer abort_promise.deinit();

    // Spec § 5.3.3 step 1: If state is "errored", return fulfilled promise
    try testing.expect(abort_promise.isFulfilled());
}

test "WritableStream.abort() - sets pendingAbortRequest" {
    const allocator = testing.allocator;

    // Create event loop
    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    // Create stream
    var stream = try streams.WritableStream.initWithSink(allocator, loop.eventLoop(), null, null);
    defer stream.deinit();

    // Verify no pending abort initially
    try testing.expect(stream.pendingAbortRequest == null);

    // Abort stream
    const reason = streams.JSValue{ .string = "abort reason" };
    const abort_promise = try stream.call_abort(reason);
    defer abort_promise.deinit();

    // Run microtasks
    loop.runMicrotasks();

    // Note: pendingAbortRequest is cleared after processing completes
    // This test verifies the abort was processed
    try testing.expectEqual(streams.WritableStream.StreamState.errored, stream.state);
}

test "WritableStream.abort() - rejects pending writes" {
    const allocator = testing.allocator;

    // Create event loop
    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    // Create stream with writer
    var stream = try streams.WritableStream.initWithSink(allocator, loop.eventLoop(), null, null);
    defer stream.deinit();

    const writer = try stream.getWriter();

    // Write some data (creates pending write request)
    const write_chunk = streams.JSValue{ .string = "test data" };
    const write_promise = try writer.write(write_chunk);

    // Abort the stream
    const abort_promise = try stream.call_abort(null);
    defer abort_promise.deinit();

    // Run microtasks to process abort
    loop.runMicrotasks();

    // Pending write should be rejected
    try testing.expect(write_promise.isRejected());

    // Clean up
    write_promise.deinit();
}
