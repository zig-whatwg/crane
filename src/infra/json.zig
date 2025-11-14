//! WHATWG Infra JSON Operations
//!
//! Spec: https://infra.spec.whatwg.org/#json
//!
//! Parse JSON strings into Infra values and serialize Infra values to JSON.
//!
//! # JavaScript Value Conversions (§6 lines 1068-1096)
//!
//! The WHATWG Infra spec defines 4 JavaScript interop functions:
//! - parseJsonStringToJavaScriptValue
//! - parseJsonBytesToJavaScriptValue
//! - serializeJavaScriptValueToJsonString
//! - serializeJavaScriptValueToJsonBytes
//!
//! These functions are NOT implemented in this library because:
//!
//! 1. **Separation of Concerns**: This library provides Infra primitives (data structures
//!    and algorithms), not JavaScript engine bindings.
//!
//! 2. **Browser Architecture**: Chrome, Firefox, and Safari do not maintain separate
//!    "Infra value" and "JavaScript value" type hierarchies. They use unified
//!    representations (JSValue, JS::Value) to avoid marshaling overhead.
//!
//! 3. **Flexible JS Engine Support**: By not coupling to a specific JavaScript runtime,
//!    this library remains portable across V8, JavaScriptCore, SpiderMonkey, and other
//!    engines.
//!
//! 4. **Consumer Libraries Handle Binding**: Consumers (like zig-whatwg/dom) integrate
//!    with their chosen JS runtime library (e.g., zig-js-runtime) to bridge Zig and
//!    JavaScript.
//!
//! ## Example: Using with zig-js-runtime
//!
//! If you need JavaScript interop, use a JS runtime library like zig-js-runtime:
//!
//! ```zig
//! const jsruntime = @import("jsruntime");
//! const infra = @import("infra");
//!
//! // Parse JSON directly to JavaScript value using engine's native JSON.parse
//! const js_value = try env.execJS(
//!     \\JSON.parse(arguments[0])
//!     , .{json_string}
//! );
//!
//! // Serialize JavaScript value to JSON using engine's native JSON.stringify
//! const json_result = try env.execJS(
//!     \\JSON.stringify(arguments[0])
//!     , .{js_value}
//! );
//!
//! // Or use Infra values and let zig-js-runtime's reflection system handle conversion
//! const infra_value = try infra.parseJsonString(allocator, json_string);
//! // zig-js-runtime automatically converts Infra types to JS types
//! ```
//!
//! See: https://github.com/lightpanda-io/zig-js-runtime
//!
//! ## Architectural Rationale
//!
//! The WHATWG Infra spec is a **conceptual model** for web platform specifications.
//! Browser implementations optimize by merging Infra concepts directly into their JS
//! engine's type system:
//!
//! - Infra "list" → JS Array (same runtime type)
//! - Infra "ordered map" → JS Object (same runtime type)
//! - Infra "string" → JS String (same runtime type)
//!
//! This Zig implementation follows the same pattern: Infra primitives (std.ArrayList,
//! OrderedMap, []const u16) are the foundation, and JS runtime libraries provide the
//! binding layer when JavaScript interop is needed.
//!
//! Other WHATWG spec implementations (URL, DOM, Fetch) that reference "parse JSON to
//! JavaScript value" in their algorithms should use their JS runtime directly rather
//! than expecting this library to provide the abstraction.

const std = @import("std");
const Allocator = std.mem.Allocator;
const String = @import("string.zig").String;
const OrderedMap = @import("map.zig").OrderedMap;
const List = @import("list.zig").List;

pub const InfraValue = union(enum) {
    null_value,
    boolean: bool,
    number: f64,
    string: String,
    list: *List(*InfraValue),
    map: *OrderedMap(String, *InfraValue),

    pub fn deinit(self: *InfraValue, allocator: Allocator) void {
        switch (self.*) {
            .null_value, .boolean, .number => {},
            .string => |s| allocator.free(s),
            .list => |l| {
                for (l.items()) |item| {
                    item.deinit(allocator);
                    allocator.destroy(item);
                }
                l.deinit();
                allocator.destroy(l);
            },
            .map => |m| {
                var it = m.iterator();
                while (it.next()) |entry| {
                    allocator.free(entry.key);
                    entry.value.deinit(allocator);
                    allocator.destroy(entry.value);
                }
                m.deinit();
                allocator.destroy(m);
            },
        }
    }
};

pub const JsonError = error{
    InvalidJson,
    OutOfMemory,
};

pub fn parseJsonString(allocator: Allocator, json_string: []const u8) !InfraValue {
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_string, .{});
    defer parsed.deinit();

    return try jsonValueToInfra(allocator, parsed.value);
}

pub fn parseJsonBytes(allocator: Allocator, bytes: []const u8) !InfraValue {
    return parseJsonString(allocator, bytes);
}

fn jsonValueToInfra(allocator: Allocator, value: std.json.Value) !InfraValue {
    return switch (value) {
        .null => .null_value,
        .bool => |b| .{ .boolean = b },
        .integer => |i| .{ .number = @floatFromInt(i) },
        .float => |f| .{ .number = f },
        .number_string => |_| JsonError.InvalidJson,
        .string => |s| blk: {
            const string_module = @import("string.zig");
            const utf16_string = try string_module.utf8ToUtf16(allocator, s);
            break :blk .{ .string = utf16_string };
        },
        .array => |arr| blk: {
            const list_ptr = try allocator.create(List(*InfraValue));
            list_ptr.* = List(*InfraValue).init(allocator);
            errdefer {
                for (list_ptr.items()) |item| {
                    item.deinit(allocator);
                    allocator.destroy(item);
                }
                list_ptr.deinit();
                allocator.destroy(list_ptr);
            }

            try list_ptr.ensureCapacity(arr.items.len);

            for (arr.items) |item| {
                const infra_item_ptr = try allocator.create(InfraValue);
                errdefer allocator.destroy(infra_item_ptr);
                infra_item_ptr.* = try jsonValueToInfra(allocator, item);
                errdefer infra_item_ptr.deinit(allocator);
                try list_ptr.append(infra_item_ptr);
            }

            break :blk .{ .list = list_ptr };
        },
        .object => |obj| blk: {
            const map_ptr = try allocator.create(OrderedMap(String, *InfraValue));
            map_ptr.* = OrderedMap(String, *InfraValue).init(allocator);
            errdefer {
                var it = map_ptr.iterator();
                while (it.next()) |entry| {
                    allocator.free(entry.key);
                    entry.value.deinit(allocator);
                    allocator.destroy(entry.value);
                }
                map_ptr.deinit();
                allocator.destroy(map_ptr);
            }

            var it = obj.iterator();
            while (it.next()) |entry| {
                const string_module = @import("string.zig");
                const key = try string_module.utf8ToUtf16(allocator, entry.key_ptr.*);
                errdefer allocator.free(key);
                const val_ptr = try allocator.create(InfraValue);
                errdefer allocator.destroy(val_ptr);
                val_ptr.* = try jsonValueToInfra(allocator, entry.value_ptr.*);
                errdefer val_ptr.deinit(allocator);
                try map_ptr.set(key, val_ptr);
            }

            break :blk .{ .map = map_ptr };
        },
    };
}

pub fn serializeInfraValue(allocator: Allocator, value: InfraValue) ![]const u8 {
    var result = List(u8).init(allocator);
    errdefer result.deinit();

    try serializeValue(allocator, &result, value);

    return result.toOwnedSlice();
}

/// Serialize InfraValue to pretty-printed JSON with indentation
pub fn serializeInfraValuePretty(allocator: Allocator, value: InfraValue) ![]const u8 {
    var result = List(u8).init(allocator);
    errdefer result.deinit();

    try serializeValuePretty(allocator, &result, value, 0);

    return result.toOwnedSlice();
}

pub fn serializeInfraValueToBytes(allocator: Allocator, value: InfraValue) ![]const u8 {
    return serializeInfraValue(allocator, value);
}

fn serializeValue(allocator: Allocator, writer: *List(u8), value: InfraValue) !void {
    switch (value) {
        .null_value => try writer.appendSlice( "null"),
        .boolean => |b| {
            if (b) {
                try writer.appendSlice( "true");
            } else {
                try writer.appendSlice( "false");
            }
        },
        .number => |n| {
            var buf: [64]u8 = undefined;
            const s = try std.fmt.bufPrint(&buf, "{d}", .{n});
            try writer.appendSlice( s);
        },
        .string => |s| {
            const string_module = @import("string.zig");
            const utf8_string = try string_module.utf16ToUtf8(allocator, s);
            defer allocator.free(utf8_string);

            try writer.append( '"');
            for (utf8_string) |c| {
                switch (c) {
                    '"' => try writer.appendSlice( "\\\""),
                    '\\' => try writer.appendSlice( "\\\\"),
                    '\n' => try writer.appendSlice( "\\n"),
                    '\r' => try writer.appendSlice( "\\r"),
                    '\t' => try writer.appendSlice( "\\t"),
                    else => try writer.append( c),
                }
            }
            try writer.append( '"');
        },
        .list => |l| {
            try writer.append( '[');
            const items_slice = l.items();
            for (items_slice, 0..) |item, i| {
                if (i > 0) try writer.append( ',');
                try serializeValue(allocator, writer, item.*);
            }
            try writer.append( ']');
        },
        .map => |m| {
            try writer.append( '{');
            var it = m.iterator();
            var first = true;
            while (it.next()) |entry| {
                if (!first) try writer.append( ',');
                first = false;

                try serializeValue(allocator, writer, .{ .string = entry.key });
                try writer.append( ':');
                try serializeValue(allocator, writer, entry.value.*);
            }
            try writer.append( '}');
        },
    }
}

fn serializeValuePretty(allocator: Allocator, writer: *List(u8), value: InfraValue, indent: usize) !void {
    switch (value) {
        .null_value => try writer.appendSlice( "null"),
        .boolean => |b| {
            if (b) {
                try writer.appendSlice( "true");
            } else {
                try writer.appendSlice( "false");
            }
        },
        .number => |n| {
            var buf: [64]u8 = undefined;
            const s = try std.fmt.bufPrint(&buf, "{d}", .{n});
            try writer.appendSlice( s);
        },
        .string => |s| {
            const string_module = @import("string.zig");
            const utf8_string = try string_module.utf16ToUtf8(allocator, s);
            defer allocator.free(utf8_string);

            try writer.append( '"');
            for (utf8_string) |c| {
                switch (c) {
                    '"' => try writer.appendSlice( "\\\""),
                    '\\' => try writer.appendSlice( "\\\\"),
                    '\n' => try writer.appendSlice( "\\n"),
                    '\r' => try writer.appendSlice( "\\r"),
                    '\t' => try writer.appendSlice( "\\t"),
                    else => try writer.append( c),
                }
            }
            try writer.append( '"');
        },
        .list => |l| {
            try writer.append( '[');
            const items_slice = l.items();
            if (items_slice.len > 0) {
                try writer.append( '\n');
                for (items_slice, 0..) |item, i| {
                    if (i > 0) {
                        try writer.appendSlice( ",\n");
                    }
                    // Indent
                    for (0..(indent + 1) * 2) |_| {
                        try writer.append( ' ');
                    }
                    try serializeValuePretty(allocator, writer, item.*, indent + 1);
                }
                try writer.append( '\n');
                // Close bracket indent
                for (0..indent * 2) |_| {
                    try writer.append( ' ');
                }
            }
            try writer.append( ']');
        },
        .map => |m| {
            try writer.append( '{');
            var it = m.iterator();
            var first = true;
            const has_items = m.size() > 0;
            if (has_items) {
                try writer.append( '\n');
            }
            while (it.next()) |entry| {
                if (!first) {
                    try writer.appendSlice( ",\n");
                }
                first = false;

                // Indent
                for (0..(indent + 1) * 2) |_| {
                    try writer.append( ' ');
                }

                try serializeValuePretty(allocator, writer, .{ .string = entry.key }, indent + 1);
                try writer.appendSlice( ": ");
                try serializeValuePretty(allocator, writer, entry.value.*, indent + 1);
            }
            if (has_items) {
                try writer.append( '\n');
                // Close brace indent
                for (0..indent * 2) |_| {
                    try writer.append( ' ');
                }
            }
            try writer.append( '}');
        },
    }
}



















