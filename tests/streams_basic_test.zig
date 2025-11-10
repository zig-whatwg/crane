const std = @import("std");
const testing = std.testing;

// Import streams module
const streams = @import("streams");

test "ReadableStream - basic creation" {
    const allocator = testing.allocator;
    
    var stream = try streams.ReadableStream.init(allocator);
    defer stream.deinit();
    
    try testing.expect(!stream.locked());
    try testing.expectEqual(streams.ReadableStream.StreamState.readable, stream.state);
}

test "WritableStream - basic creation" {
    const allocator = testing.allocator;
    
    var stream = try streams.WritableStream.init(allocator);
    defer stream.deinit();
    
    try testing.expect(!stream.locked());
    try testing.expectEqual(streams.WritableStream.StreamState.writable, stream.state);
}

test "TransformStream - basic creation" {
    const allocator = testing.allocator;
    
    var stream = try streams.TransformStream.init(allocator);
    defer stream.deinit();
    
    try testing.expect(stream.readable() != null);
    try testing.expect(stream.writable() != null);
}

test "ReadableStream - getReader locks stream" {
    const allocator = testing.allocator;
    
    var stream = try streams.ReadableStream.init(allocator);
    defer stream.deinit();
    
    try testing.expect(!stream.locked());
    
    const reader = try stream.getReader(null);
    try testing.expect(stream.locked());
    
    switch (reader) {
        .default => |r| r.releaseLock(),
        else => {},
    }
    
    try testing.expect(!stream.locked());
}

test "WritableStream - getWriter locks stream" {
    const allocator = testing.allocator;
    
    var stream = try streams.WritableStream.init(allocator);
    defer stream.deinit();
    
    try testing.expect(!stream.locked());
    
    _ = try stream.getWriter();
    try testing.expect(stream.locked());
}
