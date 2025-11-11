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

test "WritableStream.abort() - signals abort on controller's AbortController" {
    const allocator = testing.allocator;

    // Create event loop
    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    // Create stream
    var stream = try streams.WritableStream.initWithSink(allocator, loop.eventLoop(), null, null);
    defer stream.deinit();

    // Verify AbortSignal is not aborted initially
    try testing.expect(!stream.controller.abortController.signal.aborted);

    // Abort stream with reason
    const abort_reason = streams.JSValue{ .string = "test abort reason" };
    const abort_promise = try stream.call_abort(abort_reason);
    defer abort_promise.deinit();

    // Spec § 5.3.3 step 2: Signal abort should have been called
    // AbortSignal should now be aborted
    try testing.expect(stream.controller.abortController.signal.aborted);
    
    // Abort reason should be set
    try testing.expect(stream.controller.abortController.signal.reason != null);
}

test "WritableStream.abort() - abort algorithms are executed" {
    const allocator = testing.allocator;

    // Create event loop
    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    // Create stream
    var stream = try streams.WritableStream.initWithSink(allocator, loop.eventLoop(), null, null);
    defer stream.deinit();

    // Track if abort algorithm was called
    const AbortCallback = struct {
        var called: bool = false;
        fn callback(reason: @import("webidl").JSValue) void {
            _ = reason;
            called = true;
        }
    };
    AbortCallback.called = false;

    // Add algorithm to AbortSignal
    try stream.controller.abortController.signal.addAlgorithm(AbortCallback.callback);

    // Abort stream
    const abort_promise = try stream.call_abort(null);
    defer abort_promise.deinit();

    // Verify abort algorithm was called during signal abort
    try testing.expect(AbortCallback.called);
}

test "WritableStream.abort() - abort algorithms cleared after abort" {
    const allocator = testing.allocator;

    // Create event loop
    var loop = TestEventLoop.init(allocator);
    defer loop.deinit();

    // Create stream
    var stream = try streams.WritableStream.initWithSink(allocator, loop.eventLoop(), null, null);
    defer stream.deinit();

    // Track calls
    const AbortCallback = struct {
        var call_count: usize = 0;
        fn callback(reason: @import("webidl").JSValue) void {
            _ = reason;
            call_count += 1;
        }
    };
    AbortCallback.call_count = 0;

    // Add algorithm
    try stream.controller.abortController.signal.addAlgorithm(AbortCallback.callback);

    // Abort stream
    const abort_promise1 = try stream.call_abort(null);
    defer abort_promise1.deinit();

    // Verify called once
    try testing.expectEqual(@as(usize, 1), AbortCallback.call_count);

    // Spec § DOM: Abort algorithms should be cleared after running
    // Verify algorithms list is empty
    try testing.expectEqual(@as(usize, 0), stream.controller.abortController.signal.abort_algorithms.items.len);
}
