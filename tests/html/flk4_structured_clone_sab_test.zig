//! Crane's own structured-clone walker (src/html/structured_clone) is the
//! JavaScriptCore adapter's planned path (docs/engine-protocol.md,
//! "Structured serialization": JSC has no API for it). It has no shared memory
//! yet - the V8 adapter carries a SharedArrayBuffer's backing store in the
//! `SharedMemory` sidecar - so a SharedArrayBuffer through it must fail as
//! DataCloneError, as HTML's StructuredSerializeInternal does wherever shared
//! memory cannot cross. It used to yield a record with an undefined
//! byte-length cell and agent cluster 0 (audit small item, lane flk4).
//! Every throwing path of the walker freed its record twice - its own destroy
//! and the errdefer at the allocation - which the walker's inline tests never
//! showed: src/html/structured_clone is html_core's, whose test blocks no test
//! step collects. The symbol, function and detached-buffer cases pin that.
const std = @import("std");
const structured_clone = @import("html_core").structured_clone;

const bytes = [_]u8{ 1, 2, 3, 4 };

test "a SharedArrayBuffer through the walker throws DataCloneError, not a record with no length" {
    const value: structured_clone.JSValue = .{ .array_buffer = .{ .data = &bytes, .shared = true } };
    try std.testing.expectError(error.DataCloneError, structured_clone.structuredSerialize(std.testing.allocator, &value));
}

test "a growable SharedArrayBuffer through the walker throws DataCloneError" {
    const value: structured_clone.JSValue = .{ .array_buffer = .{ .data = &bytes, .shared = true, .max_byte_length = 16 } };
    try std.testing.expectError(error.DataCloneError, structured_clone.structuredSerialize(std.testing.allocator, &value));
}

test "a SharedArrayBuffer for storage still throws DataCloneError" {
    const value: structured_clone.JSValue = .{ .array_buffer = .{ .data = &bytes, .shared = true } };
    try std.testing.expectError(error.DataCloneError, structured_clone.structuredSerializeForStorage(std.testing.allocator, &value));
}

test "an ArrayBuffer that is not shared still serializes" {
    const value: structured_clone.JSValue = .{ .array_buffer = .{ .data = &bytes } };
    const serialized = try structured_clone.structuredSerialize(std.testing.allocator, &value);
    defer {
        serialized.deinit();
        std.testing.allocator.destroy(serialized);
    }
    try std.testing.expectEqualSlices(u8, &bytes, serialized.data.array_buffer.data);
}

test "a symbol through the walker throws DataCloneError and frees its record once" {
    const value: structured_clone.JSValue = .{ .symbol = {} };
    try std.testing.expectError(error.DataCloneError, structured_clone.structuredSerialize(std.testing.allocator, &value));
}

test "a function through the walker throws DataCloneError and frees its record once" {
    const value: structured_clone.JSValue = .{ .function = {} };
    try std.testing.expectError(error.DataCloneError, structured_clone.structuredSerialize(std.testing.allocator, &value));
}

test "a detached ArrayBuffer through the walker throws and frees its record once" {
    const value: structured_clone.JSValue = .{ .array_buffer = .{ .data = &bytes, .detached = true } };
    try std.testing.expectError(error.DetachedBuffer, structured_clone.structuredSerialize(std.testing.allocator, &value));
}
