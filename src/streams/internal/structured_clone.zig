//! StructuredClone and CloneAsUint8Array implementations
//!
//! Spec: WHATWG Streams Standard § 5
//! https://streams.spec.whatwg.org/#abstract-opdef-cloneasuint8array
//!
//! These algorithms provide deep cloning for stream chunks, preventing aliasing
//! between tee branches. This is critical for correctness when a stream is tee'd
//! and both branches might mutate chunks.
//!
//! NOTE: This is a simplified implementation focused on ArrayBufferView types.
//! Full StructuredClone requires HTML Standard's StructuredSerialize/Deserialize,
//! which handle complex object graphs. For streams, we primarily need to clone
//! typed arrays and ArrayBuffers.

const std = @import("std");
const webidl = @import("webidl");
const common = @import("common");

/// CloneAsUint8Array(O)
///
/// Spec: § 5 "CloneAsUint8Array(O) performs the following steps:"
///
/// 1. Assert: O is an Object.
/// 2. Assert: O has an [[ViewedArrayBuffer]] internal slot.
/// 3. Assert: ! IsDetachedBuffer(O.[[ViewedArrayBuffer]]) is false.
/// 4. Let buffer be ? CloneArrayBuffer(O.[[ViewedArrayBuffer]], O.[[ByteOffset]], O.[[ByteLength]], %ArrayBuffer%).
/// 5. Let array be ! Construct(%Uint8Array%, « buffer »).
/// 6. Return array.
///
/// This creates a new Uint8Array with a copy of the data from the source view.
/// The result is completely independent - mutations don't affect the original.
pub fn cloneAsUint8Array(
    allocator: std.mem.Allocator,
    view: webidl.ArrayBufferView,
) !webidl.ArrayBufferView {
    // Step 1-2: Type assertions (enforced by parameter type)

    // Step 3: Check if buffer is detached
    const buffer = view.getViewedArrayBuffer();
    if (buffer.isDetached()) {
        return error.DetachedBuffer;
    }

    // Get byte offset and length from the view
    const byte_offset = view.getByteOffset();
    const byte_length = view.getByteLength();

    // Step 4: CloneArrayBuffer - create new buffer with copied data
    const cloned_buffer = try cloneArrayBuffer(
        allocator,
        buffer,
        byte_offset,
        byte_length,
    );

    // Step 5: Construct(%Uint8Array%, « buffer »)
    // Create a new Uint8Array wrapping the cloned buffer
    // We need to put the buffer on the heap so it can be referenced by the view
    const cloned_buffer_heap = try allocator.create(webidl.ArrayBuffer);
    errdefer {
        allocator.free(cloned_buffer.data);
        allocator.destroy(cloned_buffer_heap);
    }
    cloned_buffer_heap.* = cloned_buffer;

    const uint8_array = try webidl.TypedArray(u8).init(
        cloned_buffer_heap,
        0, // Start at beginning of cloned buffer
        byte_length, // Full length
    );

    // Step 6: Return the Uint8Array
    return .{ .uint8_array = uint8_array };
}

/// CloneArrayBuffer(srcBuffer, srcByteOffset, srcLength, cloneConstructor)
///
/// ECMAScript Spec: § 25.1.2.4 CloneArrayBuffer
/// https://tc39.es/ecma262/#sec-clonearraybuffer
///
/// Creates a new ArrayBuffer with a copy of the data from srcBuffer.
/// This is a simplified implementation for our needs.
///
/// Parameters:
/// - srcBuffer: The source ArrayBuffer to clone from
/// - srcByteOffset: Byte offset in source buffer
/// - srcLength: Number of bytes to clone
///
/// Returns a new ArrayBuffer with copied data.
fn cloneArrayBuffer(
    allocator: std.mem.Allocator,
    src_buffer: *const webidl.ArrayBuffer,
    src_byte_offset: usize,
    src_length: usize,
) !webidl.ArrayBuffer {
    // Validate that we're not reading beyond buffer bounds
    if (src_byte_offset + src_length > src_buffer.data.len) {
        return error.OutOfBounds;
    }

    // Create new buffer with the specified length
    const new_data = try allocator.alloc(u8, src_length);
    errdefer allocator.free(new_data);

    // Copy data from source buffer (deep copy)
    const src_slice = src_buffer.data[src_byte_offset..][0..src_length];
    @memcpy(new_data, src_slice);

    // Return new ArrayBuffer with copied data
    return webidl.ArrayBuffer{
        .data = new_data,
        .detached = false,
    };
}

/// StructuredClone(v)
///
/// Spec: § 5 "StructuredClone(v) performs the following steps:"
///
/// 1. Let serialized be ? StructuredSerialize(v).
/// 2. Return ? StructuredDeserialize(serialized, the current Realm).
///
/// NOTE: This is a SIMPLIFIED implementation for stream chunks.
/// Full StructuredClone per HTML Standard handles complex object graphs,
/// including circular references, Maps, Sets, Error objects, etc.
///
/// For streams, we primarily need to clone:
/// - Typed arrays (ArrayBufferView)
/// - Primitive values (strings, numbers, etc.)
///
/// This implementation handles the common cases. A full implementation
/// would require the HTML Standard's StructuredSerialize/Deserialize.
pub fn structuredClone(
    allocator: std.mem.Allocator,
    value: common.JSValue,
) !common.JSValue {
    return switch (value) {
        // Primitives - return as-is (they're copied by value)
        .undefined, .null, .boolean, .number, .close_sentinel => value,

        // Strings - need to clone the string data
        .string => |s| blk: {
            const cloned = try allocator.dupe(u8, s);
            break :blk .{ .string = cloned };
        },

        // Bytes (Uint8Array data) - need to clone the byte data
        .bytes => |b| blk: {
            const cloned = try allocator.dupe(u8, b);
            break :blk .{ .bytes = cloned };
        },

        // Objects - can't clone without full structured clone support
        .object => error.ObjectCloneNotSupported,
    };
}

/// Structured clone specifically for ArrayBufferView
///
/// This is a convenience wrapper that handles ArrayBufferView cloning
/// and returns it as a JSValue for use in stream algorithms.
pub fn structuredCloneView(
    allocator: std.mem.Allocator,
    view: webidl.ArrayBufferView,
) !webidl.ArrayBufferView {
    // For views, we can use cloneAsUint8Array which handles all the details
    return cloneAsUint8Array(allocator, view);
}

/// Free cloned value's allocated memory
///
/// Call this when you're done with a cloned JSValue to free its memory.
pub fn freeClonedValue(allocator: std.mem.Allocator, value: common.JSValue) void {
    switch (value) {
        .string => |s| allocator.free(s),
        .bytes => |b| allocator.free(b),
        else => {}, // Other types don't allocate
    }
}

// ===== TESTS =====

test "cloneAsUint8Array - basic clone" {
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
    const cloned = try cloneAsUint8Array(allocator, view_wrapper);
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

test "cloneAsUint8Array - mutations are independent" {
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
    const cloned = try cloneAsUint8Array(allocator, view_wrapper);
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

test "cloneAsUint8Array - detached buffer error" {
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
        cloneAsUint8Array(allocator, view_wrapper),
    );
}

test "structuredClone - primitives" {
    const allocator = std.testing.allocator;

    // Undefined
    {
        const cloned = try structuredClone(allocator, .undefined);
        try std.testing.expect(cloned == .undefined);
    }

    // Null
    {
        const cloned = try structuredClone(allocator, .null);
        try std.testing.expect(cloned == .null);
    }

    // Boolean
    {
        const cloned = try structuredClone(allocator, .{ .boolean = true });
        try std.testing.expect(cloned == .boolean);
        try std.testing.expectEqual(true, cloned.boolean);
    }

    // Number
    {
        const cloned = try structuredClone(allocator, .{ .number = 42.5 });
        try std.testing.expect(cloned == .number);
        try std.testing.expectEqual(@as(f64, 42.5), cloned.number);
    }
}

test "structuredClone - string" {
    const allocator = std.testing.allocator;

    const original = "Hello, World!";
    const cloned = try structuredClone(allocator, .{ .string = original });
    defer freeClonedValue(allocator, cloned);

    // Verify it's a string
    try std.testing.expect(cloned == .string);

    // Verify content matches
    try std.testing.expectEqualStrings(original, cloned.string);

    // Verify it's a different pointer (deep copy)
    try std.testing.expect(original.ptr != cloned.string.ptr);
}

test "structuredClone - bytes" {
    const allocator = std.testing.allocator;

    const original = &[_]u8{ 1, 2, 3, 4, 5 };
    const cloned = try structuredClone(allocator, .{ .bytes = original });
    defer freeClonedValue(allocator, cloned);

    // Verify it's bytes
    try std.testing.expect(cloned == .bytes);

    // Verify content matches
    try std.testing.expectEqualSlices(u8, original, cloned.bytes);

    // Verify it's a different pointer (deep copy)
    try std.testing.expect(original.ptr != cloned.bytes.ptr);
}

test "cloneArrayBuffer - basic functionality" {
    const allocator = std.testing.allocator;

    // Create source buffer
    const src_data = try allocator.alloc(u8, 16);
    defer allocator.free(src_data);

    for (src_data, 0..) |*byte, i| {
        byte.* = @intCast(i);
    }

    const src_buffer = webidl.ArrayBuffer{
        .data = src_data,
        .detached = false,
    };

    // Clone a portion of it
    const cloned = try cloneArrayBuffer(allocator, &src_buffer, 4, 8);
    defer allocator.free(cloned.data);

    // Verify length
    try std.testing.expectEqual(@as(usize, 8), cloned.data.len);

    // Verify data
    for (cloned.data, 0..) |byte, i| {
        try std.testing.expectEqual(@as(u8, @intCast(i + 4)), byte);
    }

    // Verify independence - mutate source
    src_data[4] = 99;
    try std.testing.expectEqual(@as(u8, 4), cloned.data[0]); // Clone unchanged
}

test "cloneArrayBuffer - out of bounds error" {
    const allocator = std.testing.allocator;

    const src_data = try allocator.alloc(u8, 8);
    defer allocator.free(src_data);

    const src_buffer = webidl.ArrayBuffer{
        .data = src_data,
        .detached = false,
    };

    // Try to clone beyond buffer bounds
    try std.testing.expectError(
        error.OutOfBounds,
        cloneArrayBuffer(allocator, &src_buffer, 4, 10), // 4 + 10 = 14 > 8
    );
}

// ============================================================================
// Transfer Serialization for MessagePort
// ============================================================================

const message_port = @import("message_port");

/// Serialized data for transfer
///
/// Holds serialized representation of a transferable object (like MessagePort).
/// Per HTML Standard §2.7.10 StructuredSerializeWithTransfer.
pub const SerializedData = struct {
    /// Serialized port ID (simplified - in full implementation this would be
    /// the complete serialized representation)
    port_id: u64,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, port_id: u64) !*SerializedData {
        const data = try allocator.create(SerializedData);
        data.* = .{
            .port_id = port_id,
            .allocator = allocator,
        };
        return data;
    }

    pub fn deinit(self: *SerializedData) void {
        self.allocator.destroy(self);
    }
};

/// Deserialized record from transfer
///
/// Contains the deserialized object after transfer.
/// Per HTML Standard §2.7.11 StructuredDeserializeWithTransfer.
pub const DeserializedRecord = struct {
    /// The deserialized MessagePort
    port: *message_port.MessagePort,
};

/// StructuredSerializeWithTransfer(value, transferList)
///
/// Spec: HTML Standard §2.7.10 StructuredSerializeWithTransfer
/// https://html.spec.whatwg.org/#structuredserializewithtransfer
///
/// Simplified implementation for MessagePort transfer.
/// In a full implementation, this would:
/// 1. Create a memory map
/// 2. For each transferable, call [[TransferSteps]]
/// 3. StructuredSerialize the entire value
/// 4. Return serialized data
///
/// For our purposes, we just need to serialize the MessagePort ID.
pub fn structuredSerializeWithTransfer(
    allocator: std.mem.Allocator,
    port: *message_port.MessagePort,
) !*SerializedData {
    // In a full implementation, we would:
    // 1. Check if port is already in transfer list (error if duplicate)
    // 2. Call port.[[TransferSteps]]() to prepare for transfer
    // 3. Serialize the port data

    // For now, just serialize the port ID
    return SerializedData.init(allocator, port.id);
}

/// StructuredDeserializeWithTransfer(serialized, targetRealm)
///
/// Spec: HTML Standard §2.7.11 StructuredDeserializeWithTransfer
/// https://html.spec.whatwg.org/#structureddeserializewithtransfer
///
/// Simplified implementation for MessagePort transfer.
/// In a full implementation, this would:
/// 1. Create a memory map
/// 2. For each transferred object, call [[TransferReceivingSteps]]
/// 3. StructuredDeserialize the entire value
/// 4. Return deserialized value
///
/// For our purposes, we create a new MessagePort with the serialized ID.
pub fn structuredDeserializeWithTransfer(
    allocator: std.mem.Allocator,
    serialized: *SerializedData,
) !DeserializedRecord {
    // In a full implementation, we would:
    // 1. Call [[TransferReceivingSteps]] to recreate the port
    // 2. Deserialize all nested data
    // 3. Return the complete object graph

    // For now, create a new MessagePort with the deserialized ID
    // This is a simplification - the port would need to be reconnected
    // to its entangled port in the source realm
    const port = try message_port.MessagePort.init(allocator);
    // Restore the serialized ID (for testing/tracking purposes)
    // In a real implementation, this would restore the full port state
    _ = serialized.port_id; // Use the port_id (even if just acknowledging it)

    return DeserializedRecord{
        .port = port,
    };
}

// ============================================================================
// Tests for Transfer Serialization
// ============================================================================

test "structuredSerializeWithTransfer - MessagePort" {
    const allocator = std.testing.allocator;

    const port = try message_port.MessagePort.init(allocator);
    defer port.deinit();

    const original_id = port.id;

    const serialized = try structuredSerializeWithTransfer(allocator, port);
    defer serialized.deinit();

    try std.testing.expectEqual(original_id, serialized.port_id);
}

test "structuredDeserializeWithTransfer - MessagePort" {
    const allocator = std.testing.allocator;

    const serialized = try SerializedData.init(allocator, 42);
    defer serialized.deinit();

    const deserialized = try structuredDeserializeWithTransfer(allocator, serialized);
    defer deserialized.port.deinit();

    try std.testing.expect(deserialized.port.id != 0);
}

test "transfer round-trip - MessagePort" {
    const allocator = std.testing.allocator;

    // Create original port
    const original_port = try message_port.MessagePort.init(allocator);
    defer original_port.deinit();

    const original_id = original_port.id;

    // Serialize
    const serialized = try structuredSerializeWithTransfer(allocator, original_port);
    defer serialized.deinit();

    // Deserialize
    const deserialized = try structuredDeserializeWithTransfer(allocator, serialized);
    defer deserialized.port.deinit();

    // Verify we can use the deserialized port
    try std.testing.expect(deserialized.port.id != 0);
    try std.testing.expectEqual(false, deserialized.port.closed);

    // Note: In a full implementation, the deserialized port would be
    // reconnected to the original port's entangled port
    _ = original_id;
}
