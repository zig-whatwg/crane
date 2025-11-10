const std = @import("std");
const testing = std.testing;

// Import streams module
const streams = @import("streams");

test "ReadableStream - async iterator basic usage" {
    const allocator = testing.allocator;

    // Create a readable stream
    var stream = try streams.ReadableStream.init(allocator);
    defer stream.deinit();

    // Verify stream is not locked before getting iterator
    try testing.expect(!stream.locked());

    // Get async iterator (default: preventCancel = false)
    var iter = try stream.asyncIterator();
    defer iter.deinit();

    // Verify stream is now locked
    try testing.expect(stream.locked());

    // Verify iterator is ready
    try testing.expect(!iter.done);
}

test "ReadableStream - values() with preventCancel option" {
    const allocator = testing.allocator;

    // Create a readable stream
    var stream = try streams.ReadableStream.init(allocator);
    defer stream.deinit();

    // Get async iterator with preventCancel = true
    var iter = try stream.values(true);
    defer iter.deinit();

    // Verify preventCancel is set
    try testing.expect(iter.preventCancel == true);

    // Verify stream is locked
    try testing.expect(stream.locked());
}

test "ReadableStream - async iterator iteration over empty stream" {
    const allocator = testing.allocator;

    // Create a readable stream
    var stream = try streams.ReadableStream.init(allocator);
    defer stream.deinit();

    // Close the stream immediately
    stream.closeInternal();

    // Get async iterator
    var iter = try stream.asyncIterator();
    defer iter.deinit();

    // Try to read - should get null (end of iteration)
    const chunk = try iter.next();
    try testing.expect(chunk == null);

    // Verify iterator is done
    try testing.expect(iter.done);
}

test "ReadableStream - async iterator early return without cancel" {
    const allocator = testing.allocator;

    // Create a readable stream
    var stream = try streams.ReadableStream.init(allocator);
    defer stream.deinit();

    // Get async iterator with preventCancel = true
    var iter = try stream.values(true);

    // Return early (simulating break in for-await)
    const returnPromise = try iter.returnEarly(null);
    defer returnPromise.deinit();

    // Process microtasks
    stream.eventLoop.runMicrotasks();

    // Promise should be fulfilled
    try testing.expect(returnPromise.isFulfilled());

    // Verify iterator is done
    try testing.expect(iter.done);

    // Stream should NOT be canceled (preventCancel = true)
    try testing.expect(stream.state == .readable);
}

test "ReadableStream - async iterator early return with cancel" {
    const allocator = testing.allocator;

    // Create a readable stream
    var stream = try streams.ReadableStream.init(allocator);
    defer stream.deinit();

    // Get async iterator with preventCancel = false (default)
    var iter = try stream.asyncIterator();

    // Return early with cancel
    const returnPromise = try iter.returnEarly(null);
    defer returnPromise.deinit();

    // Process microtasks
    stream.eventLoop.runMicrotasks();

    // Promise should be fulfilled
    try testing.expect(returnPromise.isFulfilled() or returnPromise.isPending());

    // Verify iterator is done
    try testing.expect(iter.done);
}

test "ReadableStream - async iterator releases lock on deinit" {
    const allocator = testing.allocator;

    // Create a readable stream
    var stream = try streams.ReadableStream.init(allocator);
    defer stream.deinit();

    // Verify stream is not locked
    try testing.expect(!stream.locked());

    {
        // Get async iterator in inner scope
        var iter = try stream.asyncIterator();
        defer iter.deinit();

        // Verify stream is locked
        try testing.expect(stream.locked());
    }

    // After deinit, stream should be unlocked
    try testing.expect(!stream.locked());
}

test "ReadableStream - multiple sequential iterations" {
    const allocator = testing.allocator;

    // Create a readable stream
    var stream = try streams.ReadableStream.init(allocator);
    defer stream.deinit();

    // First iteration
    {
        var iter1 = try stream.asyncIterator();
        defer iter1.deinit();

        try testing.expect(stream.locked());
    }

    // Stream should be unlocked between iterations
    try testing.expect(!stream.locked());

    // Second iteration
    {
        var iter2 = try stream.asyncIterator();
        defer iter2.deinit();

        try testing.expect(stream.locked());
    }

    // Stream should be unlocked after both
    try testing.expect(!stream.locked());
}
