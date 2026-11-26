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
    // The one destroy of `value` on every throwing path below: a path that
    // destroyed it itself as well freed it twice (lane core1).
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
            value.* = .{ .array_buffer = .{
                .data = try allocator.dupe(u8, ab.data),
                .detached = false,
            } };
        },

        .resizable_array_buffer => {
            const rab = serialized.data.resizable_array_buffer;
            value.* = .{ .array_buffer = .{
                .data = try allocator.dupe(u8, rab.data),
                .detached = false,
                .max_byte_length = rab.max_byte_length,
            } };
        },

        .shared_array_buffer => {
            const sab = serialized.data.shared_array_buffer;
            // For SharedArrayBuffer, we share the same data (not copy)
            // In real implementation, this would use shared memory
            value.* = .{ .array_buffer = .{
                .data = try allocator.dupe(u8, sab.data),
                .detached = false,
                .shared = true,
            } };
        },

        .growable_shared_array_buffer => {
            const gsab = serialized.data.growable_shared_array_buffer;
            value.* = .{ .array_buffer = .{
                .data = try allocator.dupe(u8, gsab.data),
                .detached = false,
                .max_byte_length = gsab.max_byte_length,
                .shared = true,
            } };
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
                // The errdefer at the allocation destroys `value`.
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
            const ct = if (b.content_type.len > 0) try allocator.dupe(u8, b.content_type) else "";
            errdefer if (ct.len > 0) allocator.free(ct);
            if (b.file_ref) |ref| {
                value.* = .{ .blob = .{
                    .data = "",
                    .content_type = ct,
                    .file_ref = ref.retain(),
                } };
            } else {
                const copy = if (b.data.len > 0) try allocator.dupe(u8, b.data) else "";
                value.* = .{ .blob = .{
                    .data = copy,
                    .content_type = ct,
                    .file_ref = null,
                } };
            }
        },

        .file => {
            const f = serialized.data.file;
            const name = if (f.name.len > 0) try allocator.dupe(u8, f.name) else "";
            errdefer if (name.len > 0) allocator.free(name);
            const ct = if (f.content_type.len > 0) try allocator.dupe(u8, f.content_type) else "";
            errdefer if (ct.len > 0) allocator.free(ct);
            const rel = if (f.webkit_relative_path.len > 0) try allocator.dupe(u8, f.webkit_relative_path) else "";
            errdefer if (rel.len > 0) allocator.free(rel);
            if (f.file_ref) |ref| {
                value.* = .{ .file = .{
                    .data = "",
                    .name = name,
                    .content_type = ct,
                    .last_modified = f.last_modified,
                    .webkit_relative_path = rel,
                    .file_ref = ref.retain(),
                } };
            } else {
                const copy = if (f.data.len > 0) try allocator.dupe(u8, f.data) else "";
                value.* = .{ .file = .{
                    .data = copy,
                    .name = name,
                    .content_type = ct,
                    .last_modified = f.last_modified,
                    .webkit_relative_path = rel,
                    .file_ref = null,
                } };
            }
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

        // The engine's own serialization - the engine deserializes it
        // (structuredDeserializeWithTransfer), not this walker
        .engine_serialized => return CloneError.DeserializeError,

        // Transferable-only types - should not appear in regular deserialization
        .message_port,
        .readable_stream,
        .writable_stream,
        .transform_stream,
        .offscreen_canvas,
        .audio_data,
        .video_frame,
        => return CloneError.DeserializeError,

        // Types requiring special handling
        .file_list,
        .image_bitmap,
        .dom_matrix,
        .dom_matrix_readonly,
        .dom_quad,
        .crypto_key,
        // These would need more complex deserialization
        => return CloneError.DeserializeError,
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
            if (b.file_ref) |ref| ref.release();
            if (b.data.len > 0) allocator.free(b.data);
            if (b.content_type.len > 0) allocator.free(b.content_type);
        },
        .file => |f| {
            if (f.file_ref) |ref| ref.release();
            if (f.data.len > 0) allocator.free(f.data);
            if (f.name.len > 0) allocator.free(f.name);
            if (f.content_type.len > 0) allocator.free(f.content_type);
            if (f.webkit_relative_path.len > 0) allocator.free(f.webkit_relative_path);
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

test "a record the walker cannot deserialize is a DeserializeError, its value freed once" {
    // Each of these paths destroyed the value it had made and then returned
    // into the errdefer that destroys it again: a double free (lane core1,
    // the pattern fc5b7d6cc fixed in serialize.zig).
    const testing = std.testing;
    const allocator = testing.allocator;
    const records = [_]SerializedValue{
        // A view with no buffer.
        .{ .type = .array_buffer_view, .allocator = allocator, .data = .{ .array_buffer_view = .{
            .constructor = .Uint8Array,
            .buffer_serialized = null,
            .byte_length = 0,
            .byte_offset = 0,
            .array_length = 0,
        } } },
        // The engine's own serialization (structuredDeserializeWithTransfer's).
        .{ .type = .engine_serialized, .allocator = allocator, .data = .{ .engine_serialized = .{
            .serialized_bytes = &.{},
            .transferred_arraybuffers = &.{},
        } } },
        // A transferable-only type.
        .{ .type = .message_port, .allocator = allocator, .data = .{ .message_port = {} } },
        // A type the walker does not deserialize yet.
        .{ .type = .crypto_key, .allocator = allocator, .data = .{ .crypto_key = {} } },
    };
    for (&records) |*record| try testing.expectError(CloneError.DeserializeError, structuredDeserialize(allocator, record));
}

/// Whether the walker frees the graphs it makes once per value - the JSC
/// adapter lane's to land: the ownership of the JSValues the walk makes
/// depends on how that adapter represents and roots them (the integrator,
/// 2026-11-24, lane core1's B9). Flip it with the fix; the test below then
/// runs, and must pass.
const graph_ownership_landed = false;

test "a deserialized graph frees each value once: a shared reference, a cycle, a view's buffer (known red until the JSC adapter lane)" {
    // TODO(JSC adapter lane): B9, found by lane core1 (2026-11-24). Every
    // case crashes or leaks today, so the test is skipped until
    // `graph_ownership_landed` flips:
    // - freeJSValue frees a graph as a tree. A value reached twice
    //   deserializes to one *JSValue (the walk's memory), which freeJSValue
    //   frees once per reference: a double free. A cycle recurses without end.
    //   A view's buffer JSValue (the array_buffer_view arm's buffer_value) is
    //   never freed.
    // - Its serialize-side twin: SerializedValue.deinit (types.zig) frees a
    //   record reached twice, twice, and recurses on a cycle.
    // - HTML §2.7.8 step 5.3: "Let dataHolder be memory[transferable]" - the
    //   step-2.4 record IS the data holder, owned by the result. transfer.zig
    //   builds a TransferDataHolder of its own instead (lane core1's B5 point
    //   5, and B10: a serialized graph that references a transferred buffer
    //   would point at a destroyed record). Unreachable until a JSValue's
    //   memory identity can be a transferable's - the adapter defines that.
    if (!graph_ownership_landed) return error.SkipZigTest;
    const testing = std.testing;
    const allocator = testing.allocator;
    // A value reached twice: one string, two properties.
    {
        const inner = JSValue{ .string = "shared" };
        const properties = [_]JSValue.ObjectValue.ObjectProperty{ .{ .key = "a", .value = &inner }, .{ .key = "b", .value = &inner } };
        const outer = JSValue{ .object = .{ .properties = &properties } };
        const serialized = try serialize.structuredSerialize(allocator, &outer);
        defer {
            serialized.deinit();
            allocator.destroy(serialized);
        }
        const copy = try structuredDeserialize(allocator, serialized);
        defer freeJSValue(allocator, copy);
        try testing.expectEqual(copy.object.properties[0].value, copy.object.properties[1].value);
    }
    // A cycle: an object that holds itself.
    {
        var self_holding: JSValue = undefined;
        const properties = [_]JSValue.ObjectValue.ObjectProperty{.{ .key = "self", .value = &self_holding }};
        self_holding = .{ .object = .{ .properties = &properties } };
        const serialized = try serialize.structuredSerialize(allocator, &self_holding);
        defer {
            serialized.deinit();
            allocator.destroy(serialized);
        }
        const copy = try structuredDeserialize(allocator, serialized);
        defer freeJSValue(allocator, copy);
        try testing.expectEqual(@as(*const JSValue, copy), copy.object.properties[0].value);
    }
    // A view: its buffer goes with it.
    {
        const bytes = [_]u8{ 1, 2, 3, 4 };
        const buffer = JSValue.ArrayBufferValue{ .data = &bytes };
        const view = JSValue{ .typed_array = .{ .buffer = &buffer, .constructor = .Uint8Array, .byte_offset = 0, .byte_length = 4, .array_length = 4 } };
        const serialized = try serialize.structuredSerialize(allocator, &view);
        defer {
            serialized.deinit();
            allocator.destroy(serialized);
        }
        const copy = try structuredDeserialize(allocator, serialized);
        defer freeJSValue(allocator, copy);
        try testing.expectEqualSlices(u8, &bytes, copy.typed_array.buffer.data);
    }
}
