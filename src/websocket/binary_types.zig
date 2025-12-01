//! WebSocket Binary Type Handling
//!
//! Handles conversion between WebSocket binary data and DOM types
//! (Blob, ArrayBuffer) based on the binaryType attribute.
//!
//! ## binaryType Attribute
//!
//! Per WHATWG WebSockets spec, the binaryType attribute controls how
//! incoming binary data is exposed to JavaScript:
//!
//! - "blob": Data is exposed as a Blob object (can be spooled to disk)
//! - "arraybuffer": Data is exposed as an ArrayBuffer (kept in memory)
//!
//! ## send() Data Types
//!
//! The send() method accepts:
//! - DOMString (text message)
//! - Blob
//! - ArrayBuffer
//! - ArrayBufferView (TypedArray or DataView)
//!
//! ## References
//!
//! - WHATWG WebSockets: https://websockets.spec.whatwg.org/#dom-websocket-binarytype
//! - W3C File API (Blob): https://www.w3.org/TR/FileAPI/#blob-section

const std = @import("std");

/// Binary data types that can be sent via WebSocket.send()
pub const BinaryDataType = enum {
    /// UTF-8 encoded text string
    string,
    /// Blob object (binary large object)
    blob,
    /// ArrayBuffer
    array_buffer,
    /// TypedArray (Uint8Array, Int32Array, etc.)
    typed_array,
    /// DataView
    data_view,
};

/// Result of creating binary data for a MessageEvent
pub const MessageBinaryData = union(enum) {
    /// Text data (DOMString)
    text: []const u8,
    /// Binary data as raw bytes (for Blob or ArrayBuffer creation)
    binary: BinaryBytes,
};

/// Binary bytes with ownership information
pub const BinaryBytes = struct {
    /// The raw binary data
    bytes: []const u8,
    /// Whether this struct owns the bytes
    is_owned: bool,
    /// Allocator used if owned
    allocator: ?std.mem.Allocator,

    /// Create borrowed bytes (caller retains ownership)
    pub fn borrowed(bytes: []const u8) BinaryBytes {
        return .{
            .bytes = bytes,
            .is_owned = false,
            .allocator = null,
        };
    }

    /// Create owned bytes (copy the data)
    pub fn createOwned(allocator: std.mem.Allocator, bytes: []const u8) !BinaryBytes {
        const copy = try allocator.dupe(u8, bytes);
        return .{
            .bytes = copy,
            .is_owned = true,
            .allocator = allocator,
        };
    }

    /// Free the bytes if owned
    pub fn deinit(self: *BinaryBytes) void {
        if (self.is_owned) {
            if (self.allocator) |alloc| {
                alloc.free(@constCast(self.bytes));
            }
        }
        self.* = undefined;
    }

    /// Get the byte length
    pub fn len(self: *const BinaryBytes) usize {
        return self.bytes.len;
    }
};

/// Options for creating Blob from binary data
pub const BlobOptions = struct {
    /// MIME type for the Blob (default: empty string)
    mime_type: []const u8 = "",
};

/// Create binary bytes for a MessageEvent from incoming WebSocket data.
///
/// This creates a copy of the data that can be used to construct
/// either a Blob or ArrayBuffer based on binaryType.
pub fn createMessageBinaryData(
    allocator: std.mem.Allocator,
    data: []const u8,
    is_text: bool,
) !MessageBinaryData {
    if (is_text) {
        // Text data - just reference the bytes
        return .{ .text = data };
    } else {
        // Binary data - create owned copy
        return .{ .binary = try BinaryBytes.createOwned(allocator, data) };
    }
}

/// Simple bufferedAmount calculation from byte slice
pub fn byteLength(data: []const u8) u64 {
    return data.len;
}

// =============================================================================
// Tests
// =============================================================================

test "BinaryBytes - borrowed" {
    const data = "Hello, World!";
    var bytes = BinaryBytes.borrowed(data);

    try std.testing.expectEqualStrings(data, bytes.bytes);
    try std.testing.expect(!bytes.is_owned);
    try std.testing.expectEqual(@as(usize, 13), bytes.len());

    // deinit on borrowed should not crash
    bytes.deinit();
}

test "BinaryBytes - owned" {
    const allocator = std.testing.allocator;
    const data = "Hello, World!";

    var bytes = try BinaryBytes.createOwned(allocator, data);
    defer bytes.deinit();

    try std.testing.expectEqualStrings(data, bytes.bytes);
    try std.testing.expect(bytes.is_owned);
    try std.testing.expectEqual(@as(usize, 13), bytes.len());
}

test "createMessageBinaryData - text" {
    const allocator = std.testing.allocator;
    const data = "Hello";

    const result = try createMessageBinaryData(allocator, data, true);

    try std.testing.expect(result == .text);
    try std.testing.expectEqualStrings("Hello", result.text);
}

test "createMessageBinaryData - binary" {
    const allocator = std.testing.allocator;
    const data = [_]u8{ 0x01, 0x02, 0x03 };

    var result = try createMessageBinaryData(allocator, &data, false);
    defer result.binary.deinit();

    try std.testing.expect(result == .binary);
    try std.testing.expectEqualSlices(u8, &data, result.binary.bytes);
    try std.testing.expect(result.binary.is_owned);
}

test "byteLength" {
    try std.testing.expectEqual(@as(u64, 0), byteLength(""));
    try std.testing.expectEqual(@as(u64, 5), byteLength("Hello"));
    try std.testing.expectEqual(@as(u64, 4), byteLength(&[_]u8{ 0x01, 0x02, 0x03, 0x04 }));
}
