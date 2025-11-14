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
        .bigint64_array => blk: {
            const typed = try webidl.BigInt64Array.init(
                &webidl_buffer,
                @intCast(byte_offset),
                @intCast(length),
            );
            break :blk .{ .bigint64_array = typed };
        },

        .biguint64_array => blk: {
            const typed = try webidl.BigUint64Array.init(
                &webidl_buffer,
                @intCast(byte_offset),
                @intCast(length),
            );
            break :blk .{ .biguint64_array = typed };
        },
    };
}

// ===== TESTS =====







