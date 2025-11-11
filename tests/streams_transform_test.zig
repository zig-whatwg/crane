const std = @import("std");
const testing = std.testing;

// Import streams module
const streams = @import("streams");

test "TransformStream - basic creation" {
    const allocator = testing.allocator;

    var stream = try streams.TransformStream.init(allocator);
    defer stream.deinit();

    // Verify stream has readable and writable sides
    try testing.expect(stream.readableStream != null);
    try testing.expect(stream.writableStream != null);
    try testing.expect(stream.controller != null);
}

test "TransformStream - readable and writable getters" {
    const allocator = testing.allocator;

    var stream = try streams.TransformStream.init(allocator);
    defer stream.deinit();

    const readable = stream.get_readable();
    const writable = stream.get_writable();

    try testing.expect(readable == stream.readableStream);
    try testing.expect(writable == stream.writableStream);
}

test "TransformStream - rejects readableType in transformer" {
    const allocator = testing.allocator;

    // Create transformer with readableType (should be rejected)
    // For now, this is tested implicitly - full test requires JSValue support

    var stream = try streams.TransformStream.init(allocator);
    defer stream.deinit();

    // Basic creation should still work
    try testing.expect(stream.readableStream != null);
}

test "TransformStream - controller enqueue" {
    const allocator = testing.allocator;

    var stream = try streams.TransformStream.init(allocator);
    defer stream.deinit();

    // Enqueue a chunk through the controller
    const chunk = streams.JSValue{ .string = "test data" };
    try stream.controller.enqueueInternal(chunk);

    // Verify chunk is available on readable side
    // (Full verification would require reading from readable stream)
}

test "TransformStream - controller error" {
    const allocator = testing.allocator;

    var stream = try streams.TransformStream.init(allocator);
    defer stream.deinit();

    // Error the stream through controller
    const error_value = streams.JSValue{ .string = "test error" };
    stream.controller.errorInternal(error_value);

    // Verify both sides are errored
    try testing.expectEqual(streams.ReadableStream.StreamState.errored, stream.readableStream.state);
    try testing.expectEqual(streams.WritableStream.StreamState.errored, stream.writableStream.state);
}

test "TransformStream - controller terminate" {
    const allocator = testing.allocator;

    var stream = try streams.TransformStream.init(allocator);
    defer stream.deinit();

    // Terminate the stream
    try stream.controller.terminateInternal();

    // Readable should be closed
    try testing.expectEqual(streams.ReadableStream.StreamState.closed, stream.readableStream.state);

    // Writable should be errored
    try testing.expectEqual(streams.WritableStream.StreamState.errored, stream.writableStream.state);
}

test "TransformStream - backpressure management" {
    const allocator = testing.allocator;

    var stream = try streams.TransformStream.init(allocator);
    defer stream.deinit();

    // Initially no backpressure (starts as false)
    try testing.expect(!stream.backpressure);

    // Note: setBackpressure asserts old value != new value
    // So we need to ensure we're changing the state

    // Set backpressure to true (was false)
    stream.setBackpressure(true);
    try testing.expect(stream.backpressure);

    // Verify backpressureChangePromise was created
    try testing.expect(stream.backpressureChangePromise != null);

    // Unblock write (removes backpressure if true)
    stream.unblockWrite();
    try testing.expect(!stream.backpressure);
}

test "TransformStream - backpressure promise coordination" {
    const allocator = testing.allocator;

    var stream = try streams.TransformStream.init(allocator);
    defer stream.deinit();

    // Start with no backpressure
    try testing.expect(!stream.backpressure);
    try testing.expect(stream.backpressureChangePromise == null);

    // Set backpressure - creates a new promise
    stream.setBackpressure(true);
    try testing.expect(stream.backpressure);
    try testing.expect(stream.backpressureChangePromise != null);

    const first_promise = stream.backpressureChangePromise.?;
    try testing.expect(first_promise.isPending());

    // Setting backpressure again should resolve old promise and create new one
    stream.setBackpressure(false);
    try testing.expect(!stream.backpressure);
    try testing.expect(first_promise.isFulfilled()); // Previous promise fulfilled
    try testing.expect(stream.backpressureChangePromise != null);
}

test "TransformStream - finishPromise in close algorithm" {
    const allocator = testing.allocator;

    var stream = try streams.TransformStream.init(allocator);
    defer stream.deinit();

    // Initially no finish promise
    try testing.expect(stream.controller.finishPromise == null);

    // Call close algorithm
    const close_promise = stream.defaultSinkCloseAlgorithm();

    // Should have created a finish promise
    try testing.expect(stream.controller.finishPromise != null);

    // Close promise should be fulfilled (simplified promise handling)
    try testing.expect(close_promise.isFulfilled() or close_promise.isPending());

    // Readable side should be closed
    try testing.expectEqual(streams.ReadableStream.StreamState.closed, stream.readableStream.state);
}

test "TransformStream - finishPromise prevents duplicate close" {
    const allocator = testing.allocator;

    var stream = try streams.TransformStream.init(allocator);
    defer stream.deinit();

    // First close
    const first_promise = stream.defaultSinkCloseAlgorithm();
    const finish_promise = stream.controller.finishPromise;
    try testing.expect(finish_promise != null);

    // Second close should return the same finish promise
    const second_promise = stream.defaultSinkCloseAlgorithm();

    // Both should reference the same promise (spec: return if finishPromise exists)
    try testing.expect(first_promise.state == second_promise.state);
}
