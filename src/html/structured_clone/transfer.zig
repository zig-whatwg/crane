//! StructuredSerializeWithTransfer and StructuredDeserializeWithTransfer
//!
//! Spec: HTML Standard §2.7.6-7
//! https://html.spec.whatwg.org/#structuredserializewithtransfer
//!
//! ## Overview
//!
//! These algorithms handle transferable objects, which are moved (not copied)
//! between realms. After transfer, the original object becomes unusable (detached).
//!
//! ## Transferable Objects
//!
//! Per HTML Standard, the following are transferable:
//! - ArrayBuffer
//! - MessagePort
//! - ReadableStream, WritableStream, TransformStream
//! - ImageBitmap
//! - OffscreenCanvas
//! - AudioData, VideoFrame (WebCodecs)
//!
//! ## Algorithm
//!
//! StructuredSerializeWithTransfer:
//! 1. Validate transfer list (no duplicates, all transferable)
//! 2. Serialize the value (with transfer list items in memory)
//! 3. Transfer each item (detach original, create data holder)
//!
//! StructuredDeserializeWithTransfer:
//! 1. Recreate transferred objects in target realm
//! 2. Deserialize the value (with transferred objects in memory)

const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const serialize = @import("serialize.zig");
const deserialize = @import("deserialize.zig");
const SerializedValue = types.SerializedValue;
const SerializationType = types.SerializationType;
const CloneError = types.CloneError;
const TransferDataHolder = types.TransferDataHolder;
const SerializeWithTransferResult = types.SerializeWithTransferResult;
const JSValue = serialize.JSValue;

/// Transferable object wrapper
pub const Transferable = union(enum) {
    array_buffer: *TransferableArrayBuffer,
    message_port: *TransferableMessagePort,
    readable_stream: *TransferableReadableStream,
    writable_stream: *TransferableWritableStream,
    transform_stream: *TransferableTransformStream,
    image_bitmap: *TransferableImageBitmap,
    offscreen_canvas: *TransferableOffscreenCanvas,

    /// Check if the transferable is already detached
    pub fn isDetached(self: Transferable) bool {
        return switch (self) {
            .array_buffer => |ab| ab.detached,
            .message_port => |mp| mp.detached,
            .readable_stream => |rs| rs.detached,
            .writable_stream => |ws| ws.detached,
            .transform_stream => |ts| ts.detached,
            .image_bitmap => |ib| ib.detached,
            .offscreen_canvas => |oc| oc.detached,
        };
    }

    /// Mark as detached
    pub fn detach(self: Transferable) void {
        switch (self) {
            .array_buffer => |ab| ab.detached = true,
            .message_port => |mp| mp.detached = true,
            .readable_stream => |rs| rs.detached = true,
            .writable_stream => |ws| ws.detached = true,
            .transform_stream => |ts| ts.detached = true,
            .image_bitmap => |ib| ib.detached = true,
            .offscreen_canvas => |oc| oc.detached = true,
        }
    }

    /// Get unique identity for duplicate detection
    pub fn getIdentity(self: Transferable) usize {
        return switch (self) {
            .array_buffer => |ab| @intFromPtr(ab),
            .message_port => |mp| @intFromPtr(mp),
            .readable_stream => |rs| @intFromPtr(rs),
            .writable_stream => |ws| @intFromPtr(ws),
            .transform_stream => |ts| @intFromPtr(ts),
            .image_bitmap => |ib| @intFromPtr(ib),
            .offscreen_canvas => |oc| @intFromPtr(oc),
        };
    }
};

/// Transferable ArrayBuffer
pub const TransferableArrayBuffer = struct {
    data: []u8,
    detached: bool = false,
    max_byte_length: ?usize = null,
    shared: bool = false,

    /// Transfer steps: detach and return data
    pub fn transfer(self: *TransferableArrayBuffer) types.ArrayBufferData {
        const result = types.ArrayBufferData{
            .data = self.data,
            .byte_length = self.data.len,
        };
        self.data = &[_]u8{};
        self.detached = true;
        return result;
    }
};

/// Transferable MessagePort
pub const TransferableMessagePort = struct {
    id: u64,
    detached: bool = false,
    entangled_port_id: ?u64 = null,

    /// Transfer steps: disentangle and return ID
    pub fn transfer(self: *TransferableMessagePort) types.MessagePortTransfer {
        const result = types.MessagePortTransfer{
            .port_id = self.id,
        };
        self.detached = true;
        return result;
    }
};

/// Transferable ReadableStream
pub const TransferableReadableStream = struct {
    detached: bool = false,
    locked: bool = false,

    pub fn transfer(self: *TransferableReadableStream) CloneError!types.StreamTransfer {
        if (self.locked) return CloneError.DataCloneError;
        self.detached = true;
        return types.StreamTransfer{
            .port = .{ .port_id = 0 }, // Would be a real port
        };
    }
};

/// Transferable WritableStream
pub const TransferableWritableStream = struct {
    detached: bool = false,
    locked: bool = false,

    pub fn transfer(self: *TransferableWritableStream) CloneError!types.StreamTransfer {
        if (self.locked) return CloneError.DataCloneError;
        self.detached = true;
        return types.StreamTransfer{
            .port = .{ .port_id = 0 },
        };
    }
};

/// Transferable TransformStream
pub const TransferableTransformStream = struct {
    detached: bool = false,

    pub fn transfer(self: *TransferableTransformStream) types.TransformStreamTransfer {
        self.detached = true;
        return types.TransformStreamTransfer{
            .readable = .{ .port = .{ .port_id = 0 } },
            .writable = .{ .port = .{ .port_id = 0 } },
        };
    }
};

/// Transferable ImageBitmap
pub const TransferableImageBitmap = struct {
    width: u32,
    height: u32,
    detached: bool = false,

    pub fn transfer(self: *TransferableImageBitmap) types.ImageBitmapTransfer {
        const result = types.ImageBitmapTransfer{
            .width = self.width,
            .height = self.height,
        };
        self.width = 0;
        self.height = 0;
        self.detached = true;
        return result;
    }
};

/// Transferable OffscreenCanvas
pub const TransferableOffscreenCanvas = struct {
    width: u32,
    height: u32,
    detached: bool = false,

    pub fn transfer(self: *TransferableOffscreenCanvas) types.OffscreenCanvasTransfer {
        const result = types.OffscreenCanvasTransfer{
            .width = self.width,
            .height = self.height,
        };
        self.detached = true;
        return result;
    }
};

/// StructuredSerializeWithTransfer(value, transferList)
///
/// Per HTML Standard §2.7.6:
/// Serializes a value while transferring specified objects.
pub fn structuredSerializeWithTransfer(
    allocator: Allocator,
    value: *const JSValue,
    transfer_list: []Transferable,
) CloneError!SerializeWithTransferResult {
    // Step 1: Create memory map
    var memory = serialize.SerializeMemory.init(allocator);
    defer memory.deinit();

    // Step 2: Validate and pre-process transfer list
    var seen = std.AutoHashMap(usize, void).init(allocator);
    defer seen.deinit();

    for (transfer_list) |transferable| {
        // Step 2.1: Check if transferable
        // (Type checking is done by the union type)

        // Step 2.2: Check for SharedArrayBuffer (not transferable)
        if (transferable == .array_buffer) {
            if (transferable.array_buffer.shared) {
                return CloneError.DataCloneError;
            }
        }

        // Step 2.3: Check for duplicates
        const identity = transferable.getIdentity();
        if (seen.contains(identity)) {
            return CloneError.DataCloneError;
        }
        try seen.put(identity, {});

        // Step 2.4: Add placeholder to memory (prevents serialization)
        // We use the identity as a fake pointer
        const placeholder = try allocator.create(SerializedValue);
        placeholder.* = .{
            .type = .array_buffer, // Will be replaced
            .allocator = allocator,
            .data = undefined,
        };
        try memory.put(identity, placeholder);
    }

    // Step 3: Serialize the value
    const serialized = try serialize.structuredSerializeInternal(
        allocator,
        value,
        false,
        &memory,
    );
    errdefer {
        serialized.deinit();
        allocator.destroy(serialized);
    }

    // Step 4-5: Transfer each object
    var transfer_data_holders = std.ArrayList(TransferDataHolder).init(allocator);
    errdefer transfer_data_holders.deinit();

    for (transfer_list) |transferable| {
        // Step 5.1-2: Check not already detached
        if (transferable.isDetached()) {
            return CloneError.DataCloneError;
        }

        // Step 5.3: Get the placeholder from memory
        const identity = transferable.getIdentity();
        if (memory.get(identity)) |placeholder| {
            // Clean up placeholder
            allocator.destroy(placeholder);
        }

        // Step 5.4-5: Perform transfer
        const data_holder: TransferDataHolder = switch (transferable) {
            .array_buffer => |ab| blk: {
                const data = ab.transfer();
                break :blk .{
                    .type = if (ab.max_byte_length != null)
                        .resizable_array_buffer
                    else
                        .array_buffer,
                    .data = .{ .array_buffer = data },
                };
            },
            .message_port => |mp| blk: {
                const data = mp.transfer();
                break :blk .{
                    .type = .message_port,
                    .data = .{ .message_port = data },
                };
            },
            .readable_stream => |rs| blk: {
                const data = try rs.transfer();
                break :blk .{
                    .type = .readable_stream,
                    .data = .{ .readable_stream = data },
                };
            },
            .writable_stream => |ws| blk: {
                const data = try ws.transfer();
                break :blk .{
                    .type = .writable_stream,
                    .data = .{ .writable_stream = data },
                };
            },
            .transform_stream => |ts| blk: {
                const data = ts.transfer();
                break :blk .{
                    .type = .transform_stream,
                    .data = .{ .transform_stream = data },
                };
            },
            .image_bitmap => |ib| blk: {
                const data = ib.transfer();
                break :blk .{
                    .type = .image_bitmap,
                    .data = .{ .image_bitmap = data },
                };
            },
            .offscreen_canvas => |oc| blk: {
                const data = oc.transfer();
                break :blk .{
                    .type = .offscreen_canvas,
                    .data = .{ .offscreen_canvas = data },
                };
            },
        };

        try transfer_data_holders.append(data_holder);
    }

    // Step 6: Return result
    return SerializeWithTransferResult{
        .serialized = serialized,
        .transfer_data_holders = transfer_data_holders,
        .allocator = allocator,
    };
}

/// StructuredDeserializeWithTransfer(serializeWithTransferResult, targetRealm)
///
/// Per HTML Standard §2.7.7:
/// Deserializes a value while receiving transferred objects.
pub fn structuredDeserializeWithTransfer(
    allocator: Allocator,
    result: *SerializeWithTransferResult,
) CloneError!types.DeserializeWithTransferResult {
    // Step 1: Create memory map
    var memory = deserialize.DeserializeMemory.init(allocator);
    defer memory.deinit();

    // Step 2-3: Recreate transferred objects
    var transferred_values = std.ArrayList(*anyopaque).init(allocator);
    errdefer transferred_values.deinit();

    for (result.transfer_data_holders.items) |data_holder| {
        const value: *anyopaque = switch (data_holder.type) {
            .array_buffer => blk: {
                const ab = try allocator.create(TransferableArrayBuffer);
                ab.* = .{
                    .data = data_holder.data.array_buffer.data,
                    .detached = false,
                };
                break :blk @ptrCast(ab);
            },
            .resizable_array_buffer => blk: {
                const ab = try allocator.create(TransferableArrayBuffer);
                ab.* = .{
                    .data = data_holder.data.resizable_array_buffer.data,
                    .detached = false,
                    .max_byte_length = data_holder.data.resizable_array_buffer.max_byte_length,
                };
                break :blk @ptrCast(ab);
            },
            .message_port => blk: {
                const mp = try allocator.create(TransferableMessagePort);
                mp.* = .{
                    .id = data_holder.data.message_port.port_id,
                    .detached = false,
                };
                break :blk @ptrCast(mp);
            },
            .readable_stream => blk: {
                const rs = try allocator.create(TransferableReadableStream);
                rs.* = .{
                    .detached = false,
                    .locked = false,
                };
                break :blk @ptrCast(rs);
            },
            .writable_stream => blk: {
                const ws = try allocator.create(TransferableWritableStream);
                ws.* = .{
                    .detached = false,
                    .locked = false,
                };
                break :blk @ptrCast(ws);
            },
            .transform_stream => blk: {
                const ts = try allocator.create(TransferableTransformStream);
                ts.* = .{
                    .detached = false,
                };
                break :blk @ptrCast(ts);
            },
            .image_bitmap => blk: {
                const ib = try allocator.create(TransferableImageBitmap);
                ib.* = .{
                    .width = data_holder.data.image_bitmap.width,
                    .height = data_holder.data.image_bitmap.height,
                    .detached = false,
                };
                break :blk @ptrCast(ib);
            },
            .offscreen_canvas => blk: {
                const oc = try allocator.create(TransferableOffscreenCanvas);
                oc.* = .{
                    .width = data_holder.data.offscreen_canvas.width,
                    .height = data_holder.data.offscreen_canvas.height,
                    .detached = false,
                };
                break :blk @ptrCast(oc);
            },
            else => return CloneError.DeserializeError,
        };

        try transferred_values.append(value);
    }

    // Step 4: Deserialize the value
    const deserialized = try deserialize.structuredDeserialize(
        allocator,
        result.serialized,
    );

    // Step 5: Return result
    return types.DeserializeWithTransferResult{
        .deserialized = deserialized,
        .transferred_values = transferred_values,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "structuredSerializeWithTransfer - ArrayBuffer" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Create an ArrayBuffer to transfer
    const buffer_data = try allocator.alloc(u8, 10);
    @memset(buffer_data, 42);

    var ab = TransferableArrayBuffer{
        .data = buffer_data,
        .detached = false,
    };

    // Create a simple value that references the buffer
    const value = JSValue{ .undefined = {} };

    // Transfer the buffer
    var transfer_list = [_]Transferable{.{ .array_buffer = &ab }};

    var result = try structuredSerializeWithTransfer(
        allocator,
        &value,
        &transfer_list,
    );
    defer result.deinit();

    // Original should be detached
    try testing.expect(ab.detached);
    try testing.expectEqual(@as(usize, 0), ab.data.len);

    // Transfer data should contain the data
    try testing.expectEqual(@as(usize, 1), result.transfer_data_holders.items.len);
    try testing.expectEqual(@as(usize, 10), result.transfer_data_holders.items[0].data.array_buffer.byte_length);
}

test "structuredSerializeWithTransfer - duplicate transfer throws" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const buffer_data = try allocator.alloc(u8, 5);
    defer allocator.free(buffer_data);

    var ab = TransferableArrayBuffer{
        .data = buffer_data,
        .detached = false,
    };

    const value = JSValue{ .undefined = {} };

    // Try to transfer same buffer twice
    var transfer_list = [_]Transferable{
        .{ .array_buffer = &ab },
        .{ .array_buffer = &ab }, // Duplicate!
    };

    const result = structuredSerializeWithTransfer(
        allocator,
        &value,
        &transfer_list,
    );
    try testing.expectError(CloneError.DataCloneError, result);
}

test "structuredSerializeWithTransfer - already detached throws" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var ab = TransferableArrayBuffer{
        .data = &[_]u8{},
        .detached = true, // Already detached
    };

    const value = JSValue{ .undefined = {} };
    var transfer_list = [_]Transferable{.{ .array_buffer = &ab }};

    const result = structuredSerializeWithTransfer(
        allocator,
        &value,
        &transfer_list,
    );
    try testing.expectError(CloneError.DataCloneError, result);
}
