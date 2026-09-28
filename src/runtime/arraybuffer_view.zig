//! ArrayBufferView metadata, as Zig state
//!
//! The element types of TypedArray and DataView objects and the metadata a
//! BYOB stream keeps about a view. Introspecting a view that script holds is
//! the engine's work, done through the Engine table (AGENTS.md, "The engine
//! boundary") - never here.
//!
//! Spec: ECMAScript § 22.2 TypedArray Objects
//!       ECMAScript § 25.3 DataView Objects

const std = @import("std");

/// Simple ArrayBuffer representation for Streams BYOB operations
///
/// This matches the structure used in streams/internal/pull_into_descriptor.zig
/// We define it here to avoid circular dependencies.
pub const ArrayBuffer = struct {
    data: []u8,
    byte_length: usize,
    detached: bool = false,

    pub fn init(allocator: std.mem.Allocator, byte_length: usize) !ArrayBuffer {
        const data = try allocator.alloc(u8, byte_length);
        return .{
            .data = data,
            .byte_length = byte_length,
        };
    }

    pub fn deinit(self: *ArrayBuffer, allocator: std.mem.Allocator) void {
        if (!self.detached) {
            allocator.free(self.data);
        }
    }

    pub fn isDetached(self: *const ArrayBuffer) bool {
        return self.detached;
    }

    pub fn transfer(self: *ArrayBuffer) !ArrayBuffer {
        const new_buffer = ArrayBuffer{
            .data = self.data,
            .byte_length = self.byte_length,
            .detached = false,
        };
        self.detached = true;
        self.data = &[_]u8{};
        self.byte_length = 0;
        return new_buffer;
    }
};

/// TypedArray element types
pub const ViewType = enum {
    int8_array,
    uint8_array,
    uint8_clamped_array,
    int16_array,
    uint16_array,
    int32_array,
    uint32_array,
    float32_array,
    float64_array,
    bigint64_array,
    biguint64_array,
    data_view,

    /// Get element size in bytes for this view type
    pub fn elementSize(self: ViewType) u64 {
        return switch (self) {
            .int8_array, .uint8_array, .uint8_clamped_array => 1,
            .int16_array, .uint16_array => 2,
            .int32_array, .uint32_array, .float32_array => 4,
            .float64_array, .bigint64_array, .biguint64_array => 8,
            .data_view => 1, // DataView has no fixed element size
        };
    }
};

/// ArrayBufferView metadata
///
/// Contains all information needed to work with a TypedArray or DataView
pub const ViewMetadata = struct {
    buffer: *ArrayBuffer,
    byte_offset: u64,
    byte_length: u64,
    view_type: ViewType,
    detached: bool,
};

// ============================================================================
// Test Helpers
// ============================================================================

/// Create a test Uint8Array view for testing
pub fn createTestUint8Array(allocator: std.mem.Allocator, size: usize) !ViewMetadata {
    const buffer = try allocator.create(ArrayBuffer);
    errdefer allocator.destroy(buffer);

    buffer.* = try ArrayBuffer.init(allocator, size);

    return ViewMetadata{
        .buffer = buffer,
        .byte_offset = 0,
        .byte_length = size,
        .view_type = .uint8_array,
        .detached = false,
    };
}

/// Create a test view with specific offset and length
pub fn createTestView(
    allocator: std.mem.Allocator,
    view_type: ViewType,
    buffer_size: usize,
    byte_offset: u64,
    byte_length: u64,
) !ViewMetadata {
    const buffer = try allocator.create(ArrayBuffer);
    errdefer allocator.destroy(buffer);

    buffer.* = try ArrayBuffer.init(allocator, buffer_size);

    return ViewMetadata{
        .buffer = buffer,
        .byte_offset = byte_offset,
        .byte_length = byte_length,
        .view_type = view_type,
        .detached = false,
    };
}

test "ViewType element sizes" {
    const testing = std.testing;

    try testing.expectEqual(@as(u64, 1), ViewType.uint8_array.elementSize());
    try testing.expectEqual(@as(u64, 1), ViewType.int8_array.elementSize());
    try testing.expectEqual(@as(u64, 2), ViewType.uint16_array.elementSize());
    try testing.expectEqual(@as(u64, 2), ViewType.int16_array.elementSize());
    try testing.expectEqual(@as(u64, 4), ViewType.uint32_array.elementSize());
    try testing.expectEqual(@as(u64, 4), ViewType.int32_array.elementSize());
    try testing.expectEqual(@as(u64, 4), ViewType.float32_array.elementSize());
    try testing.expectEqual(@as(u64, 8), ViewType.float64_array.elementSize());
    try testing.expectEqual(@as(u64, 8), ViewType.bigint64_array.elementSize());
    try testing.expectEqual(@as(u64, 8), ViewType.biguint64_array.elementSize());
}

test "Create test view" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const metadata = try createTestUint8Array(allocator, 256);
    defer {
        metadata.buffer.deinit(allocator);
        allocator.destroy(metadata.buffer);
    }

    try testing.expectEqual(@as(u64, 0), metadata.byte_offset);
    try testing.expectEqual(@as(u64, 256), metadata.byte_length);
    try testing.expectEqual(ViewType.uint8_array, metadata.view_type);
    try testing.expect(!metadata.detached);
}
