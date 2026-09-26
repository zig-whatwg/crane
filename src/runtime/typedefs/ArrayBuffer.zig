//! ECMAScript ArrayBuffer, as Zig state
//!
//! Spec: ECMAScript § 25.1 ArrayBuffer Objects
//!
//! The ArrayBuffer object is used to represent a generic raw binary data buffer.
//! This is the Zig-side value an impl keeps: bytes it owns. An ArrayBuffer that
//! script holds is the engine's, reached through the Engine table (AGENTS.md,
//! "The engine boundary") - never through this type.

const std = @import("std");

/// ArrayBuffer represents a fixed-length raw binary data buffer
///
/// Spec: ECMAScript § 25.1.2 The ArrayBuffer Constructor
pub const ArrayBuffer = struct {
    data: []u8,
    allocator: std.mem.Allocator,
    detached: bool,

    /// Create an ArrayBuffer of `size` bytes, owned by `allocator`.
    pub fn init(allocator: std.mem.Allocator, size: usize) !ArrayBuffer {
        const data = try allocator.alloc(u8, size);
        return ArrayBuffer{
            .data = data,
            .allocator = allocator,
            .detached = false,
        };
    }

    pub fn deinit(self: *ArrayBuffer) void {
        self.allocator.free(self.data);
        self.data = &[_]u8{};
    }

    /// Detach the ArrayBuffer (transfer ownership or neuter)
    ///
    /// Spec: ECMAScript § 25.1.3.2 DetachArrayBuffer
    pub fn detach(self: *ArrayBuffer) void {
        self.allocator.free(self.data);
        self.data = &[_]u8{};
        self.detached = true;
    }

    /// Check if the ArrayBuffer is detached
    ///
    /// Spec: ECMAScript § 25.1.5.3 IsDetachedBuffer
    pub fn isDetached(self: ArrayBuffer) bool {
        return self.detached;
    }

    /// Get the byte length of the ArrayBuffer
    ///
    /// Spec: ECMAScript § 25.1.5.1 get ArrayBuffer.prototype.byteLength
    pub fn byteLength(self: ArrayBuffer) usize {
        if (self.isDetached()) return 0;
        return self.data.len;
    }

    /// The bytes, or null when the buffer is detached.
    pub fn getData(self: *ArrayBuffer) ?[]u8 {
        if (self.isDetached()) return null;
        return self.data;
    }
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "ArrayBuffer - Zig-managed creation" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit();

    try testing.expectEqual(@as(usize, 1024), buffer.byteLength());
    try testing.expect(!buffer.isDetached());
}

test "ArrayBuffer - Zig-managed detach" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit();

    buffer.detach();

    try testing.expect(buffer.isDetached());
    try testing.expectEqual(@as(usize, 0), buffer.byteLength());
}

test "ArrayBuffer - Zig-managed getData" {
    var buffer = try ArrayBuffer.init(testing.allocator, 1024);
    defer buffer.deinit();

    const data = buffer.getData() orelse return error.GetDataFailed;
    try testing.expectEqual(@as(usize, 1024), data.len);

    // Write and verify
    data[0] = 42;
    data[1023] = 99;
    try testing.expectEqual(@as(u8, 42), data[0]);
    try testing.expectEqual(@as(u8, 99), data[1023]);
}
