const std = @import("std");
const testing = std.testing;

// Import streams module
const streams = @import("streams");
const TestEventLoop = @import("test_event_loop").TestEventLoop;

test "ReadableStream.cancel() - closes stream before calling controller cancel" {
    const allocator = testing.allocator;

    // Create event loop
    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    // Create stream
    var stream = try streams.ReadableStream.initWithSource(allocator, loop.eventLoop(), null, null);
    defer stream.deinit();

    // Verify stream starts readable
    try testing.expectEqual(streams.ReadableStream.StreamState.readable, stream.state);

    // Cancel stream
    const cancel_promise = try stream.call_cancel(null);
    defer cancel_promise.deinit();

    // Run microtasks to process cancel
    loop.runMicrotasks();

    // Spec § 4.3.14 step 4: ReadableStreamClose is called before controller cancel
    // The stream should be closed after cancel
    try testing.expectEqual(streams.ReadableStream.StreamState.closed, stream.state);
}

test "ReadableStream.cancel() - sets disturbed flag" {
    const allocator = testing.allocator;

    // Create event loop
    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    // Create stream
    var stream = try streams.ReadableStream.initWithSource(allocator, loop.eventLoop(), null, null);
    defer stream.deinit();

    // Verify stream starts not disturbed
    try testing.expect(!stream.disturbed);

    // Cancel stream
    const cancel_promise = try stream.call_cancel(null);
    defer cancel_promise.deinit();

    // Spec § 4.3.14 step 1: Set stream.[[disturbed]] to true
    try testing.expect(stream.disturbed);
}

test "ReadableStream.cancel() - already closed returns fulfilled promise" {
    const allocator = testing.allocator;

    // Create event loop
    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    // Create stream
    var stream = try streams.ReadableStream.initWithSource(allocator, loop.eventLoop(), null, null);
    defer stream.deinit();

    // Close stream first
    stream.controller.closeInternal();
    try testing.expectEqual(streams.ReadableStream.StreamState.closed, stream.state);

    // Cancel should return immediately fulfilled
    const cancel_promise = try stream.call_cancel(null);
    defer cancel_promise.deinit();

    // Spec § 4.3.14 step 2: If stream.[[state]] is "closed", return fulfilled promise
    try testing.expect(cancel_promise.isFulfilled());
}

test "ReadableStream.cancel() - errored stream returns rejected promise" {
    const allocator = testing.allocator;

    // Create event loop
    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    // Create stream
    var stream = try streams.ReadableStream.initWithSource(allocator, loop.eventLoop(), null, null);
    defer stream.deinit();

    // Error the stream
    const error_value = streams.JSValue{ .string = "test error" };
    stream.errorInternal(error_value);
    try testing.expectEqual(streams.ReadableStream.StreamState.errored, stream.state);

    // Cancel should return rejected promise
    const cancel_promise = try stream.call_cancel(null);
    defer cancel_promise.deinit();

    // Spec § 4.3.14 step 3: If stream.[[state]] is "errored", return rejected promise
    try testing.expect(cancel_promise.isRejected());
}
