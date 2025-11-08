//! View Construction Helpers
//!
//! Provides utilities for constructing WebIDL typed array views from
//! ArrayBuffer data, bridging our internal ArrayBuffer type with the
//! webidl library's ArrayBufferView types.
//!
//! Spec: https://webidl.spec.whatwg.org/#ArrayBufferView

const std = @import("std");
const webidl = @import("webidl");
const PullIntoDescriptorModule = @import("pull_into_descriptor");
const ArrayBuffer = PullIntoDescriptorModule.ArrayBuffer;
const ViewConstructor = PullIntoDescriptorModule.ViewConstructor;

/// Convert our internal ArrayBuffer to webidl's ArrayBuffer
///
/// Note: This creates a reference to the same underlying data.
/// The webidl ArrayBuffer must not outlive our ArrayBuffer.
pub fn toWebIDLArrayBuffer(buffer: *ArrayBuffer) webidl.ArrayBuffer {
    return .{
        .data = buffer.data,
        .detached = buffer.detached,
    };
}

/// Construct a typed array view from buffer + offset + length
///
/// Spec: Construct(viewConstructor, « buffer, byteOffset, length »)
/// https://tc39.es/ecma262/#sec-construct
///
/// This implements the JavaScript "new Uint8Array(buffer, offset, length)" pattern.
pub fn constructView(
    view_constructor: ViewConstructor,
    buffer: *ArrayBuffer,
    byte_offset: u64,
    length: u64,
) !webidl.ArrayBufferView {
    // Convert to webidl ArrayBuffer (reference to same data)
    var webidl_buffer = toWebIDLArrayBuffer(buffer);

    return switch (view_constructor) {
        .uint8_array => blk: {
            const typed = try webidl.TypedArray(u8).init(
                &webidl_buffer,
                @intCast(byte_offset),
                @intCast(length),
            );
            break :blk .{ .uint8_array = typed };
        },

        .int8_array => blk: {
            const typed = try webidl.TypedArray(i8).init(
                &webidl_buffer,
                @intCast(byte_offset),
                @intCast(length),
            );
            break :blk .{ .int8_array = typed };
        },

        .uint16_array => blk: {
            const typed = try webidl.TypedArray(u16).init(
                &webidl_buffer,
                @intCast(byte_offset),
                @intCast(length),
            );
            break :blk .{ .uint16_array = typed };
        },

        .int16_array => blk: {
            const typed = try webidl.TypedArray(i16).init(
                &webidl_buffer,
                @intCast(byte_offset),
                @intCast(length),
            );
            break :blk .{ .int16_array = typed };
        },

        .uint32_array => blk: {
            const typed = try webidl.TypedArray(u32).init(
                &webidl_buffer,
                @intCast(byte_offset),
                @intCast(length),
            );
            break :blk .{ .uint32_array = typed };
        },

        .int32_array => blk: {
            const typed = try webidl.TypedArray(i32).init(
                &webidl_buffer,
                @intCast(byte_offset),
                @intCast(length),
            );
            break :blk .{ .int32_array = typed };
        },

        .uint8_clamped_array => blk: {
            const typed = try webidl.TypedArray(u8).init(
                &webidl_buffer,
                @intCast(byte_offset),
                @intCast(length),
            );
            break :blk .{ .uint8_clamped_array = typed };
        },

        .float32_array => blk: {
            const typed = try webidl.TypedArray(f32).init(
                &webidl_buffer,
                @intCast(byte_offset),
                @intCast(length),
            );
            break :blk .{ .float32_array = typed };
        },

        .float64_array => blk: {
            const typed = try webidl.TypedArray(f64).init(
                &webidl_buffer,
                @intCast(byte_offset),
                @intCast(length),
            );
            break :blk .{ .float64_array = typed };
        },

        .data_view => blk: {
            const view = try webidl.DataView.init(
                &webidl_buffer,
                @intCast(byte_offset),
                @intCast(length),
            );
            break :blk .{ .data_view = view };
        },

        // BigInt arrays - note these use special types in webidl
        .bigint64_array => {
            // TODO: Implement when webidl provides BigInt64Array type
            return error.NotImplemented;
        },

        .biguint64_array => {
            // TODO: Implement when webidl provides BigUint64Array type
            return error.NotImplemented;
        },
    };
}

// ===== TESTS =====

test "constructView - Uint8Array" {
    const allocator = std.testing.allocator;

    var buffer = try ArrayBuffer.init(allocator, 16);
    defer buffer.deinit(allocator);

    // Fill with test data
    for (buffer.data, 0..) |*byte, i| {
        byte.* = @intCast(i);
    }

    // Construct Uint8Array view
    const view = try constructView(.uint8_array, &buffer, 4, 8);

    // Verify it's the correct type
    try std.testing.expect(view == .uint8_array);

    // Verify the view references the correct data
    const typed = view.uint8_array;
    try std.testing.expectEqual(@as(usize, 4), typed.byte_offset);
    try std.testing.expectEqual(@as(usize, 8), typed.length);

    // Verify we can read through the view
    const first_value = try typed.get(0);
    try std.testing.expectEqual(@as(u8, 4), first_value); // offset 4 in buffer
}

test "constructView - Uint16Array with alignment" {
    const allocator = std.testing.allocator;

    var buffer = try ArrayBuffer.init(allocator, 16);
    defer buffer.deinit(allocator);

    // Construct Uint16Array view (2-byte elements)
    // offset must be 2-byte aligned, length is in elements
    const view = try constructView(.uint16_array, &buffer, 0, 4);

    try std.testing.expect(view == .uint16_array);
    try std.testing.expectEqual(@as(usize, 4), view.uint16_array.length);
}

test "constructView - Float32Array" {
    const allocator = std.testing.allocator;

    var buffer = try ArrayBuffer.init(allocator, 16);
    defer buffer.deinit(allocator);

    // Construct Float32Array view (4-byte elements)
    const view = try constructView(.float32_array, &buffer, 0, 4);

    try std.testing.expect(view == .float32_array);
    try std.testing.expectEqual(@as(usize, 4), view.float32_array.length);
}

test "constructView - DataView" {
    const allocator = std.testing.allocator;

    var buffer = try ArrayBuffer.init(allocator, 16);
    defer buffer.deinit(allocator);

    const view = try constructView(.data_view, &buffer, 2, 10);

    try std.testing.expect(view == .data_view);
    try std.testing.expectEqual(@as(usize, 2), view.data_view.byte_offset);
    try std.testing.expectEqual(@as(usize, 10), view.data_view.byte_length);
}

test "constructView - detached buffer error" {
    const allocator = std.testing.allocator;

    var buffer = try ArrayBuffer.init(allocator, 16);
    defer buffer.deinit(allocator);

    buffer.detached = true;

    // Should fail because buffer is detached
    try std.testing.expectError(
        error.DetachedBuffer,
        constructView(.uint8_array, &buffer, 0, 8),
    );
}

test "constructView - invalid alignment error" {
    const allocator = std.testing.allocator;

    var buffer = try ArrayBuffer.init(allocator, 16);
    defer buffer.deinit(allocator);

    // Uint16Array requires 2-byte alignment
    // offset 1 is not aligned
    try std.testing.expectError(
        error.InvalidOffset,
        constructView(.uint16_array, &buffer, 1, 4),
    );
}

test "constructView - out of bounds error" {
    const allocator = std.testing.allocator;

    var buffer = try ArrayBuffer.init(allocator, 16);
    defer buffer.deinit(allocator);

    // Try to create view that extends beyond buffer
    try std.testing.expectError(
        error.OutOfBounds,
        constructView(.uint8_array, &buffer, 10, 20),
    );
}
