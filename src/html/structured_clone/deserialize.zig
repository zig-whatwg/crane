//! StructuredDeserialize Algorithm Implementation
//!
//! Spec: HTML Standard §2.7.7 StructuredDeserialize
//! https://html.spec.whatwg.org/#structureddeserialize
//!
//! ## Overview
//!
//! This module implements the StructuredDeserialize algorithm which recreates
//! JavaScript values from their serialized form in a target realm.
//!
//! ## Algorithm
//!
//! The algorithm:
//! 1. Checks the memory map for already-deserialized objects (cycle handling)
//! 2. Creates the appropriate JavaScript value based on [[Type]]
//! 3. For compound types, recursively deserializes nested values
//! 4. Stores the result in memory before returning

const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const serialize = @import("serialize.zig");
const SerializedValue = types.SerializedValue;
const SerializationType = types.SerializationType;
const CloneError = types.CloneError;
const JSValue = serialize.JSValue;

/// Memory map for tracking deserialized objects (cycle detection)
pub const DeserializeMemory = std.AutoHashMap(usize, *JSValue);

/// StructuredDeserialize(serialized, targetRealm [, memory])
///
/// Per HTML Standard §2.7.7:
/// Takes a serialized Record and deserializes it into a new JavaScript value
/// in the target realm.
pub fn structuredDeserialize(
    allocator: Allocator,
    serialized: *const SerializedValue,
) CloneError!*JSValue {
    var memory = DeserializeMemory.init(allocator);
    defer memory.deinit();
    return structuredDeserializeInternal(allocator, serialized, &memory);
}

/// Internal deserialization with memory for cycle detection
fn structuredDeserializeInternal(
    allocator: Allocator,
    serialized: *const SerializedValue,
    memory: *DeserializeMemory,
) CloneError!*JSValue {
    // Step 2: Check memory for existing deserialized value
    const identity = @intFromPtr(serialized);
    if (memory.get(identity)) |existing| {
        return existing;
    }

    // Create the value
    const value = try allocator.create(JSValue);
    errdefer allocator.destroy(value);

    // Steps 5-24: Handle each serialized type
    switch (serialized.type) {
        .primitive => {
            switch (serialized.data.primitive) {
                .undefined => value.* = .{ .undefined = {} },
                .null => value.* = .{ .null = {} },
                .boolean => |b| value.* = .{ .boolean = b },
                .number => |n| value.* = .{ .number = n },
                .bigint => |bi| value.* = .{ .bigint = bi },
                .string => |s| {
                    const duped = try allocator.dupe(u8, s);
                    value.* = .{ .string = duped };
                },
            }
        },

        .boolean_object => {
            value.* = .{ .boolean_object = serialized.data.boolean_object };
        },

        .number_object => {
            value.* = .{ .number_object = serialized.data.number_object };
        },

        .bigint_object => {
            value.* = .{ .bigint_object = serialized.data.bigint_object };
        },

        .string_object => {
            const duped = try allocator.dupe(u8, serialized.data.string_object);
            value.* = .{ .string_object = duped };
        },

        .date => {
            value.* = .{ .date = serialized.data.date };
        },

        .regexp => {
            const r = serialized.data.regexp;
            value.* = .{ .regexp = .{
                .source = try allocator.dupe(u8, r.source),
                .flags = try allocator.dupe(u8, r.flags),
            } };
        },

        .array_buffer => {
            const ab = serialized.data.array_buffer;
            const ab_value = try allocator.create(JSValue.ArrayBufferValue);
            ab_value.* = .{
                .data = try allocator.dupe(u8, ab.data),
                .detached = false,
            };
            value.* = .{ .array_buffer = ab_value.* };
        },

        .resizable_array_buffer => {
            const rab = serialized.data.resizable_array_buffer;
            const ab_value = try allocator.create(JSValue.ArrayBufferValue);
            ab_value.* = .{
                .data = try allocator.dupe(u8, rab.data),
                .detached = false,
                .max_byte_length = rab.max_byte_length,
            };
            value.* = .{ .array_buffer = ab_value.* };
        },

        .shared_array_buffer => {
            const sab = serialized.data.shared_array_buffer;
            const ab_value = try allocator.create(JSValue.ArrayBufferValue);
            // For SharedArrayBuffer, we share the same data (not copy)
            // In real implementation, this would use shared memory
            ab_value.* = .{
                .data = try allocator.dupe(u8, sab.data),
                .detached = false,
                .shared = true,
            };
            value.* = .{ .array_buffer = ab_value.* };
        },

        .growable_shared_array_buffer => {
            const gsab = serialized.data.growable_shared_array_buffer;
            const ab_value = try allocator.create(JSValue.ArrayBufferValue);
            ab_value.* = .{
                .data = try allocator.dupe(u8, gsab.data),
                .detached = false,
                .max_byte_length = gsab.max_byte_length,
                .shared = true,
            };
            value.* = .{ .array_buffer = ab_value.* };
        },

        .array_buffer_view => {
            const view = serialized.data.array_buffer_view;

            // First deserialize the underlying buffer
            if (view.buffer_serialized) |buffer_ser| {
                const buffer_value = try structuredDeserializeInternal(
                    allocator,
                    buffer_ser,
                    memory,
                );

                if (view.constructor == .DataView) {
                    const dv = try allocator.create(JSValue.DataViewValue);
                    dv.* = .{
                        .buffer = &buffer_value.array_buffer,
                        .byte_offset = view.byte_offset,
                        .byte_length = view.byte_length,
                    };
                    value.* = .{ .data_view = dv.* };
                } else {
                    const ta = try allocator.create(JSValue.TypedArrayValue);
                    ta.* = .{
                        .buffer = &buffer_value.array_buffer,
                        .constructor = view.constructor,
                        .byte_offset = view.byte_offset,
                        .byte_length = view.byte_length,
                        .array_length = view.array_length orelse 0,
                    };
                    value.* = .{ .typed_array = ta.* };
                }
            } else {
                allocator.destroy(value);
                return CloneError.DeserializeError;
            }
        },

        .map => {
            // Store in memory before recursing (for cycles)
            try memory.put(identity, value);

            const m = serialized.data.map;
            var entries = try allocator.alloc(JSValue.MapValue.MapEntry, m.entries.size());
            errdefer allocator.free(entries);

            for (m.entries.toSlice(), 0..) |entry, i| {
                const key_value = try structuredDeserializeInternal(
                    allocator,
                    entry.key,
                    memory,
                );
                const val_value = try structuredDeserializeInternal(
                    allocator,
                    entry.value,
                    memory,
                );
                entries[i] = .{
                    .key = key_value,
                    .value = val_value,
                };
            }

            value.* = .{ .map = .{ .entries = entries } };
            return value;
        },

        .set => {
            try memory.put(identity, value);

            const s = serialized.data.set;
            var entries = try allocator.alloc(*const JSValue, s.entries.size());
            errdefer allocator.free(entries);

            for (s.entries.toSlice(), 0..) |entry, i| {
                entries[i] = try structuredDeserializeInternal(
                    allocator,
                    entry,
                    memory,
                );
            }

            value.* = .{ .set = .{ .entries = entries } };
            return value;
        },

        .error_object => {
            const e = serialized.data.error_object;
            value.* = .{ .error_obj = .{
                .name = e.name.toString(),
                .message = if (e.message) |msg| try allocator.dupe(u8, msg) else null,
                .stack = if (e.stack) |stack| try allocator.dupe(u8, stack) else null,
            } };
        },

        .array => {
            try memory.put(identity, value);

            const a = serialized.data.array;
            var elements = try allocator.alloc(?*const JSValue, a.length);
            errdefer allocator.free(elements);

            // Initialize all to null
            @memset(elements, null);

            // Fill in the serialized properties
            for (a.properties.toSlice()) |prop| {
                const index = std.fmt.parseInt(usize, prop.key, 10) catch continue;
                if (index < a.length) {
                    elements[index] = try structuredDeserializeInternal(
                        allocator,
                        prop.value,
                        memory,
                    );
                }
            }

            value.* = .{ .array = .{
                .length = a.length,
                .elements = elements,
            } };
            return value;
        },

        .object => {
            try memory.put(identity, value);

            const o = serialized.data.object;
            var properties = try allocator.alloc(JSValue.ObjectValue.ObjectProperty, o.properties.size());
            errdefer allocator.free(properties);

            for (o.properties.toSlice(), 0..) |prop, i| {
                const val_value = try structuredDeserializeInternal(
                    allocator,
                    prop.value,
                    memory,
                );
                properties[i] = .{
                    .key = try allocator.dupe(u8, prop.key),
                    .value = val_value,
                };
            }

            value.* = .{ .object = .{ .properties = properties } };
            return value;
        },

        .blob => {
            const b = serialized.data.blob;
            value.* = .{ .blob = .{
                .data = try allocator.dupe(u8, b.data),
                .content_type = try allocator.dupe(u8, b.content_type),
            } };
        },

        .file => {
            const f = serialized.data.file;
            value.* = .{ .file = .{
                .data = try allocator.dupe(u8, f.data),
                .name = try allocator.dupe(u8, f.name),
                .content_type = try allocator.dupe(u8, f.content_type),
                .last_modified = f.last_modified,
            } };
        },

        .image_data => {
            const id = serialized.data.image_data;
            value.* = .{ .image_data = .{
                .width = id.width,
                .height = id.height,
                .data = try allocator.dupe(u8, id.data),
                .color_space = try allocator.dupe(u8, id.color_space),
            } };
        },

        .dom_exception => {
            const de = serialized.data.dom_exception;
            value.* = .{ .dom_exception = .{
                .name = try allocator.dupe(u8, de.name),
                .message = try allocator.dupe(u8, de.message),
            } };
        },

        .dom_point, .dom_point_readonly => {
            const dp = serialized.data.dom_point;
            value.* = .{ .dom_point = .{
                .x = dp.x,
                .y = dp.y,
                .z = dp.z,
                .w = dp.w,
            } };
        },

        .dom_rect, .dom_rect_readonly => {
            const dr = serialized.data.dom_rect;
            value.* = .{ .dom_rect = .{
                .x = dr.x,
                .y = dr.y,
                .width = dr.width,
                .height = dr.height,
            } };
        },

        // Transferable-only types - should not appear in regular deserialization
        .message_port,
        .readable_stream,
        .writable_stream,
        .transform_stream,
        .offscreen_canvas,
        .audio_data,
        .video_frame,
        => {
            allocator.destroy(value);
            return CloneError.DeserializeError;
        },

        // Types requiring special handling
        .file_list,
        .image_bitmap,
        .dom_matrix,
        .dom_matrix_readonly,
        .dom_quad,
        .crypto_key,
        => {
            // These would need more complex deserialization
            allocator.destroy(value);
            return CloneError.DeserializeError;
        },
    }

    // Step 23: Store in memory
    try memory.put(identity, value);

    return value;
}

/// Free a deserialized JSValue and all its nested allocations
pub fn freeJSValue(allocator: Allocator, value: *JSValue) void {
    switch (value.*) {
        .string => |s| allocator.free(s),
        .string_object => |s| allocator.free(s),
        .regexp => |r| {
            allocator.free(r.source);
            allocator.free(r.flags);
        },
        .array_buffer => |ab| allocator.free(ab.data),
        .error_obj => |e| {
            if (e.message) |msg| allocator.free(msg);
            if (e.stack) |stack| allocator.free(stack);
        },
        .map => |m| {
            for (m.entries) |entry| {
                freeJSValue(allocator, @constCast(entry.key));
                allocator.destroy(@constCast(entry.key));
                freeJSValue(allocator, @constCast(entry.value));
                allocator.destroy(@constCast(entry.value));
            }
            allocator.free(m.entries);
        },
        .set => |s| {
            for (s.entries) |entry| {
                freeJSValue(allocator, @constCast(entry));
                allocator.destroy(@constCast(entry));
            }
            allocator.free(s.entries);
        },
        .array => |a| {
            for (a.elements) |elem_opt| {
                if (elem_opt) |elem| {
                    freeJSValue(allocator, @constCast(elem));
                    allocator.destroy(@constCast(elem));
                }
            }
            allocator.free(a.elements);
        },
        .object => |o| {
            for (o.properties) |prop| {
                allocator.free(prop.key);
                freeJSValue(allocator, @constCast(prop.value));
                allocator.destroy(@constCast(prop.value));
            }
            allocator.free(o.properties);
        },
        .blob => |b| {
            allocator.free(b.data);
            allocator.free(b.content_type);
        },
        .file => |f| {
            allocator.free(f.data);
            allocator.free(f.name);
            allocator.free(f.content_type);
        },
        .image_data => |id| {
            allocator.free(id.data);
            allocator.free(id.color_space);
        },
        .dom_exception => |de| {
            allocator.free(de.name);
            allocator.free(de.message);
        },
        else => {},
    }
    allocator.destroy(value);
}

// ============================================================================
// Tests
// ============================================================================

test "structuredDeserialize - primitives" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Test boolean
    {
        const value = JSValue{ .boolean = true };
        const serialized = try serialize.structuredSerialize(allocator, &value);
        defer {
            serialized.deinit();
            allocator.destroy(serialized);
        }

        const deserialized = try structuredDeserialize(allocator, serialized);
        defer freeJSValue(allocator, deserialized);

        try testing.expectEqual(true, deserialized.boolean);
    }

    // Test number
    {
        const value = JSValue{ .number = 42.5 };
        const serialized = try serialize.structuredSerialize(allocator, &value);
        defer {
            serialized.deinit();
            allocator.destroy(serialized);
        }

        const deserialized = try structuredDeserialize(allocator, serialized);
        defer freeJSValue(allocator, deserialized);

        try testing.expectEqual(@as(f64, 42.5), deserialized.number);
    }

    // Test string
    {
        const value = JSValue{ .string = "hello world" };
        const serialized = try serialize.structuredSerialize(allocator, &value);
        defer {
            serialized.deinit();
            allocator.destroy(serialized);
        }

        const deserialized = try structuredDeserialize(allocator, serialized);
        defer freeJSValue(allocator, deserialized);

        try testing.expectEqualStrings("hello world", deserialized.string);
    }
}

test "structuredDeserialize - Date" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const timestamp: f64 = 1700000000000;
    const value = JSValue{ .date = timestamp };
    const serialized = try serialize.structuredSerialize(allocator, &value);
    defer {
        serialized.deinit();
        allocator.destroy(serialized);
    }

    const deserialized = try structuredDeserialize(allocator, serialized);
    defer freeJSValue(allocator, deserialized);

    try testing.expectEqual(timestamp, deserialized.date);
}

test "structuredDeserialize - Error" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const value = JSValue{ .error_obj = .{
        .name = "TypeError",
        .message = "test error",
        .stack = null,
    } };
    const serialized = try serialize.structuredSerialize(allocator, &value);
    defer {
        serialized.deinit();
        allocator.destroy(serialized);
    }

    const deserialized = try structuredDeserialize(allocator, serialized);
    defer freeJSValue(allocator, deserialized);

    try testing.expectEqualStrings("TypeError", deserialized.error_obj.name);
    try testing.expectEqualStrings("test error", deserialized.error_obj.message.?);
}

test "structuredDeserialize - ArrayBuffer roundtrip" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const data = [_]u8{ 1, 2, 3, 4, 5 };
    const value = JSValue{ .array_buffer = .{
        .data = &data,
        .detached = false,
    } };
    const serialized = try serialize.structuredSerialize(allocator, &value);
    defer {
        serialized.deinit();
        allocator.destroy(serialized);
    }

    const deserialized = try structuredDeserialize(allocator, serialized);
    defer freeJSValue(allocator, deserialized);

    try testing.expectEqualSlices(u8, &data, deserialized.array_buffer.data);
    try testing.expectEqual(false, deserialized.array_buffer.detached);
}
