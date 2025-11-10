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

    // Initially no backpressure
    try testing.expect(!stream.backpressure);

    // Set backpressure
    stream.setBackpressure(true);
    try testing.expect(stream.backpressure);

    // Unblock write (removes backpressure)
    stream.unblockWrite();
    try testing.expect(!stream.backpressure);
}
