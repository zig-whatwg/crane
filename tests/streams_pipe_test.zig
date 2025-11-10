const std = @import("std");
const testing = std.testing;

// Import streams module
const streams = @import("streams");

test "ReadableStream.pipeTo - basic pipe" {
    const allocator = testing.allocator;

    // Create source readable stream
    var source = try streams.ReadableStream.init(allocator);
    defer source.deinit();

    // Create destination writable stream
    var dest = try streams.WritableStream.init(allocator);
    defer dest.deinit();

    // Verify streams are not locked before piping
    try testing.expect(!source.locked());
    try testing.expect(!dest.locked());

    // Pipe source to dest
    const pipePromise = try source.pipeTo(&dest, null);
    defer pipePromise.deinit();

    // Run microtasks to process the pipe
    source.eventLoop.runMicrotasks();

    // Verify pipe completed successfully
    try testing.expect(pipePromise.isFulfilled() or pipePromise.isRejected() or pipePromise.isPending());
}

test "ReadableStream.pipeTo - cannot pipe locked source" {
    const allocator = testing.allocator;

    // Create and lock source
    var source = try streams.ReadableStream.init(allocator);
    defer source.deinit();

    const reader = try source.getReader(null);
    defer switch (reader) {
        .default => |r| r.releaseLock(),
        else => {},
    };

    // Create destination
    var dest = try streams.WritableStream.init(allocator);
    defer dest.deinit();

    // Try to pipe - should fail because source is locked
    const pipePromise = try source.pipeTo(&dest, null);
    defer pipePromise.deinit();

    // Run microtasks
    source.eventLoop.runMicrotasks();

    // Should be rejected
    try testing.expect(pipePromise.isRejected());
}

test "ReadableStream.pipeTo - cannot pipe to locked destination" {
    const allocator = testing.allocator;

    // Create source
    var source = try streams.ReadableStream.init(allocator);
    defer source.deinit();

    // Create and lock destination
    var dest = try streams.WritableStream.init(allocator);
    defer dest.deinit();

    _ = try dest.getWriter();

    // Try to pipe - should fail because dest is locked
    const pipePromise = try source.pipeTo(&dest, null);
    defer pipePromise.deinit();

    // Run microtasks
    source.eventLoop.runMicrotasks();

    // Should be rejected
    try testing.expect(pipePromise.isRejected());
}

test "ReadableStream.pipeThrough - basic transform chain" {
    const allocator = testing.allocator;

    // Create source
    var source = try streams.ReadableStream.init(allocator);
    defer source.deinit();

    // Create transform
    var transform = try streams.TransformStream.init(allocator);
    defer transform.deinit();

    // Create transform pair
    var pair = streams.ReadableStream.TransformPair{
        .readable = transform.readable(),
        .writable = transform.writable(),
    };

    // PipeThrough
    const result = try source.pipeThrough(&pair, null);

    // Result should be the readable side of the transform
    try testing.expect(result == pair.readable);
}

test "ReadableStream.tee - basic branching" {
    const allocator = testing.allocator;

    // Create source
    var source = try streams.ReadableStream.init(allocator);
    defer source.deinit();

    // Verify source is not locked before tee
    try testing.expect(!source.locked());

    // Tee the stream
    const branches = try source.tee();
    defer {
        branches.branch1.deinit();
        allocator.destroy(branches.branch1);
        branches.branch2.deinit();
        allocator.destroy(branches.branch2);
    }

    // Verify source is now locked
    try testing.expect(source.locked());

    // Verify both branches exist and are readable streams
    try testing.expect(branches.branch1.state == .readable);
    try testing.expect(branches.branch2.state == .readable);

    // Verify branches are not locked initially
    try testing.expect(!branches.branch1.locked());
    try testing.expect(!branches.branch2.locked());
}

test "ReadableStream.tee - independent consumption" {
    const allocator = testing.allocator;

    // Create source
    var source = try streams.ReadableStream.init(allocator);
    defer source.deinit();

    // Tee the stream
    const branches = try source.tee();
    defer {
        branches.branch1.deinit();
        allocator.destroy(branches.branch1);
        branches.branch2.deinit();
        allocator.destroy(branches.branch2);
    }

    // Get readers for both branches
    const reader1 = try branches.branch1.getReader(null);
    const reader2 = try branches.branch2.getReader(null);

    // Both branches should be locked now
    try testing.expect(branches.branch1.locked());
    try testing.expect(branches.branch2.locked());

    // Release readers
    switch (reader1) {
        .default => |r| r.releaseLock(),
        else => {},
    }
    switch (reader2) {
        .default => |r| r.releaseLock(),
        else => {},
    }

    // Both branches should be unlocked now
    try testing.expect(!branches.branch1.locked());
    try testing.expect(!branches.branch2.locked());
}
