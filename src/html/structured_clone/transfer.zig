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
const infra = @import("infra");
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
/// Per HTML Standard §2.7.8:
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

    // The records step 2.4 makes, each destroyed once, when this returns -
    // a throw at step 2.3 or 5.1 used to leak every one made so far (lane
    // core1).
    var placeholders: std.ArrayList(*SerializedValue) = .empty;
    defer {
        for (placeholders.items) |placeholder| allocator.destroy(placeholder);
        placeholders.deinit(allocator);
    }

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
        placeholders.append(allocator, placeholder) catch |err| {
            allocator.destroy(placeholder);
            return err;
        };
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
    var transfer_data_holders = infra.List(TransferDataHolder).init(allocator);
    // A throw after some buffers moved into their holders (step 5.1-5.2 for
    // a later transferable, or its transfer steps) frees what they took.
    errdefer {
        for (transfer_data_holders.toSlice()) |holder| holder.deinit(allocator);
        transfer_data_holders.deinit();
    }

    for (transfer_list) |transferable| {
        // Step 5.1-2: Check not already detached
        if (transferable.isDetached()) {
            return CloneError.DataCloneError;
        }

        // Step 5.3: "Let dataHolder be memory[transferable]" - the step-2.4
        // record IS the holder. This walker builds a TransferDataHolder of its
        // own instead (below), and the records go when it returns: the JSC
        // adapter lane's, with the graph ownership it decides
        // (deserialize.zig's known-red test, `graph_ownership_landed`).

        // Step 5.4-5: Perform transfer
        const data_holder: TransferDataHolder = switch (transferable) {
            .array_buffer => |ab| blk: {
                // Step 5.4.1-2: the holder takes [[ArrayBufferData]] and
                // [[ArrayBufferByteLength]] - and, step 5.4.1.1, a resizable
                // one's [[ArrayBufferMaxByteLength]] with type
                // "ResizableArrayBuffer" (its data was the plain buffer's,
                // which §2.7.9 then read as resizable: lane core1). Step
                // 5.4.3: DetachArrayBuffer (`transfer`). The holder owns the
                // bytes from here (TransferDataHolder.deinit).
                const max_byte_length = ab.max_byte_length;
                const data = ab.transfer();
                if (max_byte_length) |max| break :blk .{
                    .type = .resizable_array_buffer,
                    .data = .{ .resizable_array_buffer = .{ .data = data.data, .byte_length = data.byte_length, .max_byte_length = max } },
                };
                break :blk .{ .type = .array_buffer, .data = .{ .array_buffer = data } };
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
/// Per HTML Standard §2.7.9:
/// Deserializes a value while receiving transferred objects.
pub fn structuredDeserializeWithTransfer(
    allocator: Allocator,
    result: *SerializeWithTransferResult,
) CloneError!DeserializeWithTransferResult {
    // Step 1: Create memory map
    var memory = deserialize.DeserializeMemory.init(allocator);
    defer memory.deinit();

    // Step 4: transferredValues, each owning what step 5 moves into it until
    // the result's deinit; a throw frees those made so far.
    var transferred_values = infra.List(Transferable).init(allocator);
    errdefer {
        for (transferred_values.toSlice()) |made| destroyTransferredValue(allocator, made);
        transferred_values.deinit();
    }

    // Step 5: one value per data holder.
    for (result.transfer_data_holders.toSliceMut()) |*data_holder| {
        const value: Transferable = switch (data_holder.data) {
            // Step 5.2: "a new ArrayBuffer object in targetRealm whose
            // [[ArrayBufferData]] internal slot value is
            // transferDataHolder.[[ArrayBufferData]]" - the bytes move into
            // it, and the holder is left empty.
            .array_buffer => |*holder| blk: {
                const ab = try allocator.create(TransferableArrayBuffer);
                ab.* = .{ .data = holder.data, .detached = false };
                holder.data = &.{};
                break :blk .{ .array_buffer = ab };
            },
            // Step 5.3: a resizable one, with its
            // [[ArrayBufferMaxByteLength]].
            .resizable_array_buffer => |*holder| blk: {
                const ab = try allocator.create(TransferableArrayBuffer);
                ab.* = .{ .data = holder.data, .detached = false, .max_byte_length = holder.max_byte_length };
                holder.data = &.{};
                break :blk .{ .array_buffer = ab };
            },
            .message_port => |port| blk: {
                const mp = try allocator.create(TransferableMessagePort);
                mp.* = .{ .id = port.port_id, .detached = false };
                break :blk .{ .message_port = mp };
            },
            .readable_stream => blk: {
                const rs = try allocator.create(TransferableReadableStream);
                rs.* = .{ .detached = false, .locked = false };
                break :blk .{ .readable_stream = rs };
            },
            .writable_stream => blk: {
                const ws = try allocator.create(TransferableWritableStream);
                ws.* = .{ .detached = false, .locked = false };
                break :blk .{ .writable_stream = ws };
            },
            .transform_stream => blk: {
                const ts = try allocator.create(TransferableTransformStream);
                ts.* = .{ .detached = false };
                break :blk .{ .transform_stream = ts };
            },
            .image_bitmap => |bitmap| blk: {
                const ib = try allocator.create(TransferableImageBitmap);
                ib.* = .{ .width = bitmap.width, .height = bitmap.height, .detached = false };
                break :blk .{ .image_bitmap = ib };
            },
            .offscreen_canvas => |canvas| blk: {
                const oc = try allocator.create(TransferableOffscreenCanvas);
                oc.* = .{ .width = canvas.width, .height = canvas.height, .detached = false };
                break :blk .{ .offscreen_canvas = oc };
            },
            else => return CloneError.DeserializeError,
        };
        transferred_values.append(value) catch |err| {
            destroyTransferredValue(allocator, value);
            return err;
        };
    }

    // Step 6: Deserialize the value
    const deserialized = try deserialize.structuredDeserialize(
        allocator,
        result.serialized,
    );

    // Step 7: Return result
    return .{
        .deserialized = deserialized,
        .transferred_values = transferred_values,
        .allocator = allocator,
    };
}

/// Result of StructuredDeserializeWithTransfer (§2.7.9 step 7:
/// { [[Deserialized]], [[TransferredValues]] }).
pub const DeserializeWithTransferResult = struct {
    /// [[Deserialized]]; deserialize.freeJSValue frees it.
    deserialized: *JSValue,
    /// [[TransferredValues]]: one per data holder, in order, each owning what
    /// §2.7.9 step 5 moved into it (a buffer, its bytes).
    transferred_values: infra.List(Transferable),
    allocator: Allocator,

    /// Frees the deserialized value and every transferred value, each once.
    pub fn deinit(self: *DeserializeWithTransferResult) void {
        deserialize.freeJSValue(self.allocator, self.deserialized);
        self.deinitTransferredValues();
    }

    /// Frees the transferred values only, for a caller that keeps
    /// `deserialized` (structuredClone returns it).
    pub fn deinitTransferredValues(self: *DeserializeWithTransferResult) void {
        for (self.transferred_values.toSlice()) |value| destroyTransferredValue(self.allocator, value);
        self.transferred_values.deinit();
    }
};

/// Frees a value StructuredDeserializeWithTransfer made, with what it owns.
fn destroyTransferredValue(allocator: Allocator, value: Transferable) void {
    switch (value) {
        .array_buffer => |ab| {
            allocator.free(ab.data);
            allocator.destroy(ab);
        },
        inline else => |object| allocator.destroy(object),
    }
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
    try testing.expectEqual(@as(usize, 1), result.transfer_data_holders.size());
    try testing.expectEqual(@as(usize, 10), result.transfer_data_holders.get(0).?.data.array_buffer.byte_length);
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

test "a resizable ArrayBuffer transfers as one, its maximum byte length kept" {
    // §2.7.8 step 5.4.1: a transferable with [[ArrayBufferMaxByteLength]]
    // makes a "ResizableArrayBuffer" holder with that maximum; §2.7.9 step
    // 5.3 makes a resizable buffer of it. The holder's type said resizable
    // while its data was the plain buffer's, and reading it back was a union
    // tag mismatch (lane core1).
    const testing = std.testing;
    const allocator = testing.allocator;
    const bytes = try allocator.alloc(u8, 4);
    @memset(bytes, 7);
    var ab = TransferableArrayBuffer{ .data = bytes, .max_byte_length = 16 };
    const value = JSValue{ .undefined = {} };
    var transfer_list = [_]Transferable{.{ .array_buffer = &ab }};
    var result = try structuredSerializeWithTransfer(allocator, &value, &transfer_list);
    defer result.deinit();
    try testing.expectEqual(SerializationType.resizable_array_buffer, result.transfer_data_holders.get(0).?.type);
    var received = try structuredDeserializeWithTransfer(allocator, &result);
    defer received.deinit();
    const buffer = received.transferred_values.get(0).?.array_buffer;
    try testing.expectEqual(@as(?usize, 16), buffer.max_byte_length);
    try testing.expectEqualSlices(u8, &.{ 7, 7, 7, 7 }, buffer.data);
}

test "transferred bytes are freed once: by the buffer they were delivered to, or by a result never delivered" {
    // §2.7.8 step 5.4: the holder takes a buffer's bytes; §2.7.9 step 5.2
    // moves them into the buffer it makes. Who frees them was nobody's: a
    // result's deinit freed no holder's bytes (lane core1).
    const testing = std.testing;
    const allocator = testing.allocator;
    const value = JSValue{ .undefined = {} };
    // Delivered: the new buffer owns them, and the holder is left empty.
    {
        const bytes = try allocator.alloc(u8, 3);
        @memset(bytes, 1);
        var ab = TransferableArrayBuffer{ .data = bytes };
        var transfer_list = [_]Transferable{.{ .array_buffer = &ab }};
        var result = try structuredSerializeWithTransfer(allocator, &value, &transfer_list);
        defer result.deinit();
        var received = try structuredDeserializeWithTransfer(allocator, &result);
        defer received.deinit();
        try testing.expectEqualSlices(u8, &.{ 1, 1, 1 }, received.transferred_values.get(0).?.array_buffer.data);
        try testing.expectEqual(@as(usize, 0), result.transfer_data_holders.get(0).?.data.array_buffer.data.len);
    }
    // Never delivered (a closed port, a failed postMessage): the result
    // frees them.
    {
        const bytes = try allocator.alloc(u8, 3);
        var ab = TransferableArrayBuffer{ .data = bytes };
        var transfer_list = [_]Transferable{.{ .array_buffer = &ab }};
        var result = try structuredSerializeWithTransfer(allocator, &value, &transfer_list);
        result.deinit();
    }
    // A throw at step 5.1 after an earlier buffer moved into its holder (the
    // second one is detached already): the holder's bytes are freed.
    {
        const bytes = try allocator.alloc(u8, 2);
        var first = TransferableArrayBuffer{ .data = bytes };
        var detached = TransferableArrayBuffer{ .data = &.{}, .detached = true };
        var transfer_list = [_]Transferable{ .{ .array_buffer = &first }, .{ .array_buffer = &detached } };
        try testing.expectError(CloneError.DataCloneError, structuredSerializeWithTransfer(allocator, &value, &transfer_list));
        // Step 5.4.3 detached the first before step 5.1 threw for the second.
        try testing.expect(first.detached);
    }
}
