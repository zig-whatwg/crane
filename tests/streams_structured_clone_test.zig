//! Tests for StructuredClone and CloneAsUint8Array
//!
//! These algorithms are critical for tee() correctness, ensuring branches
//! receive independent copies of chunks.

const std = @import("std");
const webidl = @import("webidl");

// Import from internal
const structured_clone = @import("../src/streams/internal/structured_clone.zig");
const common = @import("../src/streams/internal/common.zig");

test "structured_clone: CloneAsUint8Array - basic clone" {
    const allocator = std.testing.allocator;

    // Create source buffer with test data
    var src_buffer = webidl.ArrayBuffer{
        .data = try allocator.alloc(u8, 16),
        .detached = false,
    };
    defer allocator.free(src_buffer.data);

    // Fill with test pattern
    for (src_buffer.data, 0..) |*byte, i| {
        byte.* = @intCast(i);
    }

    // Create a view of the buffer
    const src_view = try webidl.TypedArray(u8).init(&src_buffer, 4, 8);
    const view_wrapper: webidl.ArrayBufferView = .{ .uint8_array = src_view };

    // Clone it
    const cloned = try structured_clone.cloneAsUint8Array(allocator, view_wrapper);
    defer {
        const buf = cloned.uint8_array.buffer;
        allocator.free(buf.data);
        allocator.destroy(buf);
    }

    // Verify it's a Uint8Array
    try std.testing.expect(cloned == .uint8_array);

    // Verify the data was copied correctly
    const cloned_array = cloned.uint8_array;
    try std.testing.expectEqual(@as(usize, 8), cloned_array.length);

    // Check values match
    for (0..8) |i| {
        const expected: u8 = @intCast(i + 4); // Original offset was 4
        const actual = try cloned_array.get(i);
        try std.testing.expectEqual(expected, actual);
    }
}

test "structured_clone: CloneAsUint8Array - mutations are independent" {
    const allocator = std.testing.allocator;

    // Create source buffer
    var src_buffer = webidl.ArrayBuffer{
        .data = try allocator.alloc(u8, 8),
        .detached = false,
    };
    defer allocator.free(src_buffer.data);

    // Fill with zeros
    @memset(src_buffer.data, 0);

    var src_view = try webidl.TypedArray(u8).init(&src_buffer, 0, 8);
    const view_wrapper: webidl.ArrayBufferView = .{ .uint8_array = src_view };

    // Clone it
    const cloned = try structured_clone.cloneAsUint8Array(allocator, view_wrapper);
    defer {
        const buf = cloned.uint8_array.buffer;
        allocator.free(buf.data);
        allocator.destroy(buf);
    }

    // Mutate the original
    try src_view.set(0, 42);

    // Verify clone is unaffected
    const cloned_value = try cloned.uint8_array.get(0);
    try std.testing.expectEqual(@as(u8, 0), cloned_value);

    // Verify original was mutated
    const src_value = try src_view.get(0);
    try std.testing.expectEqual(@as(u8, 42), src_value);
}

test "structured_clone: CloneAsUint8Array - detached buffer error" {
    const allocator = std.testing.allocator;

    var src_buffer = webidl.ArrayBuffer{
        .data = try allocator.alloc(u8, 8),
        .detached = true, // Already detached
    };
    defer allocator.free(src_buffer.data);

    const src_view = try webidl.TypedArray(u8).init(&src_buffer, 0, 8);
    const view_wrapper: webidl.ArrayBufferView = .{ .uint8_array = src_view };

    // Should fail with DetachedBuffer error
    try std.testing.expectError(
        error.DetachedBuffer,
        structured_clone.cloneAsUint8Array(allocator, view_wrapper),
    );
}

test "structured_clone: StructuredClone - primitives" {
    const allocator = std.testing.allocator;

    // Undefined
    {
        const cloned = try structured_clone.structuredClone(allocator, .undefined);
        try std.testing.expect(cloned == .undefined);
    }

    // Null
    {
        const cloned = try structured_clone.structuredClone(allocator, .null);
        try std.testing.expect(cloned == .null);
    }

    // Boolean
    {
        const cloned = try structured_clone.structuredClone(allocator, .{ .boolean = true });
        try std.testing.expect(cloned == .boolean);
        try std.testing.expectEqual(true, cloned.boolean);
    }

    // Number
    {
        const cloned = try structured_clone.structuredClone(allocator, .{ .number = 42.5 });
        try std.testing.expect(cloned == .number);
        try std.testing.expectEqual(@as(f64, 42.5), cloned.number);
    }
}

test "structured_clone: StructuredClone - string independence" {
    const allocator = std.testing.allocator;

    const original = "Hello, World!";
    const cloned = try structured_clone.structuredClone(allocator, .{ .string = original });
    defer structured_clone.freeClonedValue(allocator, cloned);

    // Verify it's a string
    try std.testing.expect(cloned == .string);

    // Verify content matches
    try std.testing.expectEqualStrings(original, cloned.string);

    // Verify it's a different pointer (deep copy)
    try std.testing.expect(original.ptr != cloned.string.ptr);
}

test "structured_clone: StructuredClone - bytes independence" {
    const allocator = std.testing.allocator;

    const original = &[_]u8{ 1, 2, 3, 4, 5 };
    const cloned = try structured_clone.structuredClone(allocator, .{ .bytes = original });
    defer structured_clone.freeClonedValue(allocator, cloned);

    // Verify it's bytes
    try std.testing.expect(cloned == .bytes);

    // Verify content matches
    try std.testing.expectEqualSlices(u8, original, cloned.bytes);

    // Verify it's a different pointer (deep copy)
    try std.testing.expect(original.ptr != cloned.bytes.ptr);
}

test "structured_clone: tee scenario - both branches get independent copies" {
    const allocator = std.testing.allocator;

    // Simulate what happens in tee: one chunk needs to go to two branches
    var original_buffer = webidl.ArrayBuffer{
        .data = try allocator.alloc(u8, 8),
        .detached = false,
    };
    defer allocator.free(original_buffer.data);

    // Fill with test data
    for (original_buffer.data, 0..) |*byte, i| {
        byte.* = @intCast(i);
    }

    const original_view = try webidl.TypedArray(u8).init(&original_buffer, 0, 8);
    const view_wrapper: webidl.ArrayBufferView = .{ .uint8_array = original_view };

    // Clone for branch1
    const branch1_chunk = try structured_clone.cloneAsUint8Array(allocator, view_wrapper);
    defer {
        const buf = branch1_chunk.uint8_array.buffer;
        allocator.free(buf.data);
        allocator.destroy(buf);
    }

    // Clone for branch2
    const branch2_chunk = try structured_clone.cloneAsUint8Array(allocator, view_wrapper);
    defer {
        const buf = branch2_chunk.uint8_array.buffer;
        allocator.free(buf.data);
        allocator.destroy(buf);
    }

    // Both should have same initial values
    for (0..8) |i| {
        const expected: u8 = @intCast(i);
        try std.testing.expectEqual(expected, try branch1_chunk.uint8_array.get(i));
        try std.testing.expectEqual(expected, try branch2_chunk.uint8_array.get(i));
    }

    // Mutate branch1
    var branch1_view = branch1_chunk.uint8_array;
    try branch1_view.set(0, 99);

    // Verify branch2 is unaffected (independence)
    try std.testing.expectEqual(@as(u8, 0), try branch2_chunk.uint8_array.get(0));

    // Verify branch1 was mutated
    try std.testing.expectEqual(@as(u8, 99), try branch1_view.get(0));
}
