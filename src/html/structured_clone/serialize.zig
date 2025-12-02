//! StructuredSerialize Algorithm Implementation
//!
//! Spec: HTML Standard §2.7.3-5 StructuredSerialize
//! https://html.spec.whatwg.org/#structuredserialize
//!
//! ## Overview
//!
//! This module implements the StructuredSerialize algorithm which converts
//! JavaScript values into a realm-independent serialized form. The serialized
//! form can be stored or transmitted and later deserialized in a different realm.
//!
//! ## Algorithm
//!
//! The algorithm handles:
//! - Primitives (undefined, null, boolean, number, bigint, string)
//! - Boxed primitives (Boolean, Number, BigInt, String objects)
//! - Date, RegExp
//! - ArrayBuffer and TypedArrays
//! - Map, Set
//! - Error objects
//! - Plain objects and arrays
//! - Platform objects with [Serializable]
//!
//! Circular references are handled via a memory map that tracks already-serialized objects.

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");
const types = @import("types.zig");
const SerializedValue = types.SerializedValue;
const SerializationType = types.SerializationType;
const CloneError = types.CloneError;
const PrimitiveValue = types.PrimitiveValue;

/// Value type abstraction for serialization
///
/// This represents a JavaScript value that can be serialized.
/// In a real implementation, this would interface with the JS engine.
pub const JSValue = union(enum) {
    undefined: void,
    null: void,
    boolean: bool,
    number: f64,
    bigint: i128,
    string: []const u8,
    symbol: void, // Symbols are not cloneable
    boolean_object: bool,
    number_object: f64,
    bigint_object: i128,
    string_object: []const u8,
    date: f64,
    regexp: RegExpValue,
    array_buffer: ArrayBufferValue,
    typed_array: TypedArrayValue,
    data_view: DataViewValue,
    map: MapValue,
    set: SetValue,
    error_obj: ErrorValue,
    array: ArrayValue,
    object: ObjectValue,
    function: void, // Functions are not cloneable
    // Platform objects
    blob: BlobValue,
    file: FileValue,
    image_data: ImageDataValue,
    dom_exception: DOMExceptionValue,
    dom_point: DOMPointValue,
    dom_rect: DOMRectValue,

    pub const RegExpValue = struct {
        source: []const u8,
        flags: []const u8,
    };

    pub const ArrayBufferValue = struct {
        data: []const u8,
        detached: bool = false,
        max_byte_length: ?usize = null, // For resizable buffers
        shared: bool = false,
    };

    pub const TypedArrayValue = struct {
        buffer: *const ArrayBufferValue,
        constructor: types.TypedArrayConstructor,
        byte_offset: usize,
        byte_length: usize,
        array_length: usize,
    };

    pub const DataViewValue = struct {
        buffer: *const ArrayBufferValue,
        byte_offset: usize,
        byte_length: usize,
    };

    pub const MapValue = struct {
        entries: []const MapEntry,

        pub const MapEntry = struct {
            key: *const JSValue,
            value: *const JSValue,
        };
    };

    pub const SetValue = struct {
        entries: []const *const JSValue,
    };

    pub const ErrorValue = struct {
        name: []const u8,
        message: ?[]const u8,
        stack: ?[]const u8,
    };

    pub const ArrayValue = struct {
        length: usize,
        elements: []const ?*const JSValue,
    };

    pub const ObjectValue = struct {
        properties: []const ObjectProperty,

        pub const ObjectProperty = struct {
            key: []const u8,
            value: *const JSValue,
        };
    };

    pub const BlobValue = struct {
        data: []const u8,
        content_type: []const u8,
    };

    pub const FileValue = struct {
        data: []const u8,
        name: []const u8,
        content_type: []const u8,
        last_modified: i64,
    };

    pub const ImageDataValue = struct {
        width: u32,
        height: u32,
        data: []const u8,
        color_space: []const u8,
    };

    pub const DOMExceptionValue = struct {
        name: []const u8,
        message: []const u8,
    };

    pub const DOMPointValue = struct {
        x: f64,
        y: f64,
        z: f64,
        w: f64,
    };

    pub const DOMRectValue = struct {
        x: f64,
        y: f64,
        width: f64,
        height: f64,
    };

    /// Get a unique identifier for this value (for cycle detection)
    pub fn getIdentity(self: *const JSValue) usize {
        return @intFromPtr(self);
    }
};

/// Memory map for tracking serialized objects (cycle detection)
pub const SerializeMemory = std.AutoHashMap(usize, *SerializedValue);

/// StructuredSerialize(value)
///
/// Per HTML Standard §2.7.4:
/// 1. Return ? StructuredSerializeInternal(value, false).
pub fn structuredSerialize(
    allocator: Allocator,
    value: *const JSValue,
) CloneError!*SerializedValue {
    var memory = SerializeMemory.init(allocator);
    defer memory.deinit();
    return structuredSerializeInternal(allocator, value, false, &memory);
}

/// StructuredSerializeForStorage(value)
///
/// Per HTML Standard §2.7.5:
/// 1. Return ? StructuredSerializeInternal(value, true).
pub fn structuredSerializeForStorage(
    allocator: Allocator,
    value: *const JSValue,
) CloneError!*SerializedValue {
    var memory = SerializeMemory.init(allocator);
    defer memory.deinit();
    return structuredSerializeInternal(allocator, value, true, &memory);
}

/// StructuredSerializeInternal(value, forStorage [, memory])
///
/// Per HTML Standard §2.7.3, this serializes a value to realm-independent form.
pub fn structuredSerializeInternal(
    allocator: Allocator,
    value: *const JSValue,
    for_storage: bool,
    memory: *SerializeMemory,
) CloneError!*SerializedValue {
    // Step 2: If memory[value] exists, return it (cycle detection)
    const identity = value.getIdentity();
    if (memory.get(identity)) |existing| {
        return existing;
    }

    // Create the serialized value
    const serialized = try allocator.create(SerializedValue);
    errdefer allocator.destroy(serialized);

    serialized.allocator = allocator;

    // Step 4-24: Handle each value type
    switch (value.*) {
        // Step 4: Primitives
        .undefined => {
            serialized.type = .primitive;
            serialized.data = .{ .primitive = .{ .undefined = {} } };
        },
        .null => {
            serialized.type = .primitive;
            serialized.data = .{ .primitive = .{ .null = {} } };
        },
        .boolean => |b| {
            serialized.type = .primitive;
            serialized.data = .{ .primitive = .{ .boolean = b } };
        },
        .number => |n| {
            serialized.type = .primitive;
            serialized.data = .{ .primitive = .{ .number = n } };
        },
        .bigint => |bi| {
            serialized.type = .primitive;
            serialized.data = .{ .primitive = .{ .bigint = bi } };
        },
        .string => |s| {
            serialized.type = .primitive;
            const duped = try allocator.dupe(u8, s);
            serialized.data = .{ .primitive = .{ .string = duped } };
        },

        // Step 5: Symbol - throw DataCloneError
        .symbol => {
            allocator.destroy(serialized);
            return CloneError.DataCloneError;
        },

        // Steps 7-10: Boxed primitives
        .boolean_object => |b| {
            serialized.type = .boolean_object;
            serialized.data = .{ .boolean_object = b };
        },
        .number_object => |n| {
            serialized.type = .number_object;
            serialized.data = .{ .number_object = n };
        },
        .bigint_object => |bi| {
            serialized.type = .bigint_object;
            serialized.data = .{ .bigint_object = bi };
        },
        .string_object => |s| {
            serialized.type = .string_object;
            serialized.data = .{ .string_object = try allocator.dupe(u8, s) };
        },

        // Step 11: Date
        .date => |d| {
            serialized.type = .date;
            serialized.data = .{ .date = d };
        },

        // Step 12: RegExp
        .regexp => |r| {
            serialized.type = .regexp;
            serialized.data = .{ .regexp = .{
                .source = try allocator.dupe(u8, r.source),
                .flags = try allocator.dupe(u8, r.flags),
            } };
        },

        // Step 13: ArrayBuffer
        .array_buffer => |ab| {
            if (ab.detached) {
                allocator.destroy(serialized);
                return CloneError.DetachedBuffer;
            }
            if (ab.shared) {
                if (for_storage) {
                    allocator.destroy(serialized);
                    return CloneError.DataCloneError;
                }
                // SharedArrayBuffer handling
                if (ab.max_byte_length) |max_len| {
                    serialized.type = .growable_shared_array_buffer;
                    serialized.data = .{
                        .growable_shared_array_buffer = .{
                            .data = try allocator.dupe(u8, ab.data),
                            .byte_length_data = undefined, // Would need real shared state
                            .max_byte_length = max_len,
                            .agent_cluster = 0, // Would need real agent cluster ID
                        },
                    };
                } else {
                    serialized.type = .shared_array_buffer;
                    serialized.data = .{ .shared_array_buffer = .{
                        .data = try allocator.dupe(u8, ab.data),
                        .byte_length = ab.data.len,
                        .agent_cluster = 0,
                    } };
                }
            } else {
                // Regular ArrayBuffer - deep copy
                if (ab.max_byte_length) |max_len| {
                    serialized.type = .resizable_array_buffer;
                    serialized.data = .{ .resizable_array_buffer = .{
                        .data = try allocator.dupe(u8, ab.data),
                        .byte_length = ab.data.len,
                        .max_byte_length = max_len,
                    } };
                } else {
                    serialized.type = .array_buffer;
                    serialized.data = .{ .array_buffer = .{
                        .data = try allocator.dupe(u8, ab.data),
                        .byte_length = ab.data.len,
                    } };
                }
            }
        },

        // Step 14: TypedArray
        .typed_array => |ta| {
            // First serialize the underlying buffer
            const buffer_value = JSValue{ .array_buffer = ta.buffer.* };
            const buffer_serialized = try structuredSerializeInternal(
                allocator,
                &buffer_value,
                for_storage,
                memory,
            );

            serialized.type = .array_buffer_view;
            serialized.data = .{ .array_buffer_view = .{
                .constructor = ta.constructor,
                .buffer_serialized = buffer_serialized,
                .byte_length = ta.byte_length,
                .byte_offset = ta.byte_offset,
                .array_length = ta.array_length,
            } };
        },

        // Step 14 (DataView variant)
        .data_view => |dv| {
            const buffer_value = JSValue{ .array_buffer = dv.buffer.* };
            const buffer_serialized = try structuredSerializeInternal(
                allocator,
                &buffer_value,
                for_storage,
                memory,
            );

            serialized.type = .array_buffer_view;
            serialized.data = .{ .array_buffer_view = .{
                .constructor = .DataView,
                .buffer_serialized = buffer_serialized,
                .byte_length = dv.byte_length,
                .byte_offset = dv.byte_offset,
                .array_length = null,
            } };
        },

        // Step 15: Map
        .map => |m| {
            serialized.type = .map;
            var entries = infra.List(types.MapData.MapEntry).init(allocator);
            errdefer entries.deinit();

            // Store in memory before recursing (for cycles)
            try memory.put(identity, serialized);

            for (m.entries) |entry| {
                const key_serialized = try structuredSerializeInternal(
                    allocator,
                    entry.key,
                    for_storage,
                    memory,
                );
                const value_serialized = try structuredSerializeInternal(
                    allocator,
                    entry.value,
                    for_storage,
                    memory,
                );
                try entries.append(.{
                    .key = key_serialized,
                    .value = value_serialized,
                });
            }

            serialized.data = .{ .map = .{ .entries = entries } };
            return serialized;
        },

        // Step 16: Set
        .set => |s| {
            serialized.type = .set;
            var entries = infra.List(*const SerializedValue).init(allocator);
            errdefer entries.deinit();

            try memory.put(identity, serialized);

            for (s.entries) |entry| {
                const entry_serialized = try structuredSerializeInternal(
                    allocator,
                    entry,
                    for_storage,
                    memory,
                );
                try entries.append(entry_serialized);
            }

            serialized.data = .{ .set = .{ .entries = entries } };
            return serialized;
        },

        // Step 17: Error
        .error_obj => |e| {
            serialized.type = .error_object;
            serialized.data = .{ .error_object = .{
                .name = types.ErrorName.fromString(e.name),
                .message = if (e.message) |msg| try allocator.dupe(u8, msg) else null,
                .stack = if (e.stack) |stack| try allocator.dupe(u8, stack) else null,
            } };
        },

        // Step 18: Array
        .array => |a| {
            serialized.type = .array;
            var properties = infra.List(types.PropertyEntry).init(allocator);
            errdefer properties.deinit();

            try memory.put(identity, serialized);

            for (a.elements, 0..) |elem_opt, i| {
                if (elem_opt) |elem| {
                    const elem_serialized = try structuredSerializeInternal(
                        allocator,
                        elem,
                        for_storage,
                        memory,
                    );
                    var key_buf: [20]u8 = undefined;
                    const key = std.fmt.bufPrint(&key_buf, "{d}", .{i}) catch unreachable;
                    try properties.append(.{
                        .key = try allocator.dupe(u8, key),
                        .value = elem_serialized,
                    });
                }
            }

            serialized.data = .{ .array = .{
                .length = a.length,
                .properties = properties,
            } };
            return serialized;
        },

        // Step 24: Object
        .object => |o| {
            serialized.type = .object;
            var properties = infra.List(types.PropertyEntry).init(allocator);
            errdefer properties.deinit();

            try memory.put(identity, serialized);

            for (o.properties) |prop| {
                const value_serialized = try structuredSerializeInternal(
                    allocator,
                    prop.value,
                    for_storage,
                    memory,
                );
                try properties.append(.{
                    .key = try allocator.dupe(u8, prop.key),
                    .value = value_serialized,
                });
            }

            serialized.data = .{ .object = .{ .properties = properties } };
            return serialized;
        },

        // Step 21: Function - throw DataCloneError
        .function => {
            allocator.destroy(serialized);
            return CloneError.DataCloneError;
        },

        // Platform objects with [Serializable]
        .blob => |b| {
            serialized.type = .blob;
            serialized.data = .{ .blob = .{
                .data = try allocator.dupe(u8, b.data),
                .content_type = try allocator.dupe(u8, b.content_type),
            } };
        },

        .file => |f| {
            serialized.type = .file;
            serialized.data = .{ .file = .{
                .data = try allocator.dupe(u8, f.data),
                .name = try allocator.dupe(u8, f.name),
                .content_type = try allocator.dupe(u8, f.content_type),
                .last_modified = f.last_modified,
            } };
        },

        .image_data => |id| {
            serialized.type = .image_data;
            serialized.data = .{ .image_data = .{
                .width = id.width,
                .height = id.height,
                .data = try allocator.dupe(u8, id.data),
                .color_space = try allocator.dupe(u8, id.color_space),
            } };
        },

        .dom_exception => |de| {
            serialized.type = .dom_exception;
            serialized.data = .{ .dom_exception = .{
                .name = try allocator.dupe(u8, de.name),
                .message = try allocator.dupe(u8, de.message),
            } };
        },

        .dom_point => |dp| {
            serialized.type = .dom_point;
            serialized.data = .{ .dom_point = .{
                .x = dp.x,
                .y = dp.y,
                .z = dp.z,
                .w = dp.w,
            } };
        },

        .dom_rect => |dr| {
            serialized.type = .dom_rect;
            serialized.data = .{ .dom_rect = .{
                .x = dr.x,
                .y = dr.y,
                .width = dr.width,
                .height = dr.height,
            } };
        },
    }

    // Step 25: Store in memory
    try memory.put(identity, serialized);

    return serialized;
}

// ============================================================================
// Tests
// ============================================================================

test "structuredSerialize - primitives" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Test undefined
    {
        const value = JSValue{ .undefined = {} };
        const serialized = try structuredSerialize(allocator, &value);
        defer {
            serialized.deinit();
            allocator.destroy(serialized);
        }
        try testing.expectEqual(SerializationType.primitive, serialized.type);
    }

    // Test boolean
    {
        const value = JSValue{ .boolean = true };
        const serialized = try structuredSerialize(allocator, &value);
        defer {
            serialized.deinit();
            allocator.destroy(serialized);
        }
        try testing.expectEqual(SerializationType.primitive, serialized.type);
        try testing.expectEqual(true, serialized.data.primitive.boolean);
    }

    // Test number
    {
        const value = JSValue{ .number = 42.5 };
        const serialized = try structuredSerialize(allocator, &value);
        defer {
            serialized.deinit();
            allocator.destroy(serialized);
        }
        try testing.expectEqual(SerializationType.primitive, serialized.type);
        try testing.expectEqual(@as(f64, 42.5), serialized.data.primitive.number);
    }

    // Test string
    {
        const value = JSValue{ .string = "hello" };
        const serialized = try structuredSerialize(allocator, &value);
        defer {
            serialized.deinit();
            allocator.destroy(serialized);
        }
        try testing.expectEqual(SerializationType.primitive, serialized.type);
        try testing.expectEqualStrings("hello", serialized.data.primitive.string);
    }
}

test "structuredSerialize - symbol throws DataCloneError" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const value = JSValue{ .symbol = {} };
    const result = structuredSerialize(allocator, &value);
    try testing.expectError(CloneError.DataCloneError, result);
}

test "structuredSerialize - function throws DataCloneError" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const value = JSValue{ .function = {} };
    const result = structuredSerialize(allocator, &value);
    try testing.expectError(CloneError.DataCloneError, result);
}

test "structuredSerialize - Date" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const timestamp: f64 = 1700000000000;
    const value = JSValue{ .date = timestamp };
    const serialized = try structuredSerialize(allocator, &value);
    defer {
        serialized.deinit();
        allocator.destroy(serialized);
    }

    try testing.expectEqual(SerializationType.date, serialized.type);
    try testing.expectEqual(timestamp, serialized.data.date);
}

test "structuredSerialize - Error" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const value = JSValue{ .error_obj = .{
        .name = "TypeError",
        .message = "test error",
        .stack = null,
    } };
    const serialized = try structuredSerialize(allocator, &value);
    defer {
        serialized.deinit();
        allocator.destroy(serialized);
    }

    try testing.expectEqual(SerializationType.error_object, serialized.type);
    try testing.expectEqual(types.ErrorName.TypeError, serialized.data.error_object.name);
    try testing.expectEqualStrings("test error", serialized.data.error_object.message.?);
}

test "structuredSerialize - ArrayBuffer" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const data = [_]u8{ 1, 2, 3, 4, 5 };
    const value = JSValue{ .array_buffer = .{
        .data = &data,
        .detached = false,
    } };
    const serialized = try structuredSerialize(allocator, &value);
    defer {
        serialized.deinit();
        allocator.destroy(serialized);
    }

    try testing.expectEqual(SerializationType.array_buffer, serialized.type);
    try testing.expectEqualSlices(u8, &data, serialized.data.array_buffer.data);
}

test "structuredSerialize - detached ArrayBuffer throws" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const data = [_]u8{ 1, 2, 3 };
    const value = JSValue{ .array_buffer = .{
        .data = &data,
        .detached = true,
    } };
    const result = structuredSerialize(allocator, &value);
    try testing.expectError(CloneError.DetachedBuffer, result);
}
