//! A script value as the host API hands it out: WebDriver BiDi's
//! `script.RemoteValue` (webdriver-bidi.md, "script.RemoteValue", and its
//! "serialize as a remote value" algorithm), as JSON text - the instances
//! design's 0.1 subset (section 5.1, `evaluate`): primitives by value; arrays
//! and plain objects to a depth (`max_depth`, BiDi's maxObjectDepth); every
//! other object as its type alone (`{"type":"function"}`, `"node"`,
//! `"window"`, ...). No handles: a host that keeps objects across calls uses
//! a protocol that does (CDP's Runtime domain, through the engine's
//! inspector).
//!
//! Read on the Browser's thread, in `realm` (the value's), through the engine
//! protocol only. Reading an object's properties runs its getters, as BiDi's
//! serialization does ("Get"); nothing else of the page runs.

const std = @import("std");
const engine = @import("engine");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

pub const Options = struct {
    /// How deep arrays and objects are serialized: 0 gives every object as
    /// its type alone.
    max_depth: u32 = 1,
    /// At most this many items of one array or object.
    max_items: usize = 100,
};

/// `value`, read in `realm`, as a RemoteValue's JSON text. OWNED by
/// `allocator`.
pub fn serialize(allocator: std.mem.Allocator, realm: runtime.Context, value: runtime.JSValue, options: Options) ![]u8 {
    var out: std.Io.Writer.Allocating = .init(allocator);
    errdefer out.deinit();
    try write(&out.writer, allocator, realm, value, options, 0);
    return out.toOwnedSlice();
}

fn writeTyped(out: *std.Io.Writer, type_name: []const u8) !void {
    try out.print("{{\"type\":\"{s}\"}}", .{type_name});
}

/// A number's RemoteValue: BiDi's special numbers are strings.
pub fn writeNumber(out: *std.Io.Writer, number: f64) !void {
    if (std.math.isNan(number)) return out.writeAll("{\"type\":\"number\",\"value\":\"NaN\"}");
    if (std.math.isInf(number)) return out.writeAll(if (number > 0) "{\"type\":\"number\",\"value\":\"Infinity\"}" else "{\"type\":\"number\",\"value\":\"-Infinity\"}");
    if (number == 0 and std.math.signbit(number)) return out.writeAll("{\"type\":\"number\",\"value\":\"-0\"}");
    try out.writeAll("{\"type\":\"number\",\"value\":");
    if (number == @trunc(number) and @abs(number) < 9007199254740992.0) {
        try out.print("{d}", .{@as(i64, @intFromFloat(number))});
    } else {
        try out.print("{d}", .{number});
    }
    try out.writeByte('}');
}

fn writeString(out: *std.Io.Writer, text: []const u8) !void {
    try out.writeAll("{\"type\":\"string\",\"value\":");
    try std.json.Stringify.encodeJsonString(text, .{}, out);
    try out.writeByte('}');
}

fn write(out: *std.Io.Writer, allocator: std.mem.Allocator, realm: runtime.Context, value: runtime.JSValue, options: Options, depth: u32) anyerror!void {
    switch (value) {
        .undefined => return writeTyped(out, "undefined"),
        .null => return writeTyped(out, "null"),
        .boolean => |b| return out.print("{{\"type\":\"boolean\",\"value\":{}}}", .{b}),
        .number => |n| return writeNumber(out, n),
        .string => |s| return writeString(out, s.data),
        .instance => |instance| return writeInstance(out, instance),
        .handle => {},
    }
    switch (engine.typeOf(realm, value)) {
        .undefined => return writeTyped(out, "undefined"),
        .null => return writeTyped(out, "null"),
        .boolean => return out.print("{{\"type\":\"boolean\",\"value\":{}}}", .{engine.toBoolean(realm, value)}),
        .number => return writeNumber(out, engine.convertToUnrestrictedDouble(realm, value) catch std.math.nan(f64)),
        .string => {
            const text = try engine.convertToDOMString(realm, value, allocator);
            defer allocator.free(text);
            return writeString(out, text);
        },
        .bigint => {
            // ToString of a BigInt: its digits (BiDi: "value" is the
            // BigInt's ToString).
            const digits = engine.convertToDOMString(realm, value, allocator) catch return writeTyped(out, "bigint");
            defer allocator.free(digits);
            try out.writeAll("{\"type\":\"bigint\",\"value\":");
            try std.json.Stringify.encodeJsonString(digits, .{}, out);
            return out.writeByte('}');
        },
        .symbol => return writeTyped(out, "symbol"),
        .object => {},
    }
    // An object: a platform object by its kind, a function, an array or a
    // plain object to the depth asked for.
    if (engine.convertToPlatformObject(realm, value)) |instance| return writeInstance(out, instance);
    if (engine.isCallable(realm, value)) return writeTyped(out, "function");
    if (engine.thisTimeValue(realm, value)) |_| return writeTyped(out, "date");
    const is_array = engine.isArrayExoticObject(realm, value);
    if (depth >= options.max_depth) return writeTyped(out, if (is_array) "array" else "object");
    if (is_array) {
        const length_value = try engine.getProperty(realm, value, "length");
        defer length_value.release();
        const length_number = engine.convertToUnrestrictedDouble(realm, length_value.borrow()) catch 0;
        const length: usize = if (length_number > 0) @intFromFloat(@min(length_number, @as(f64, @floatFromInt(options.max_items)))) else 0;
        try out.writeAll("{\"type\":\"array\",\"value\":[");
        var index_buffer: [24]u8 = undefined;
        for (0..length) |index| {
            if (index > 0) try out.writeByte(',');
            const key = std.fmt.bufPrint(&index_buffer, "{d}", .{index}) catch unreachable;
            const item = try engine.getProperty(realm, value, key);
            defer item.release();
            try write(out, allocator, realm, item.borrow(), options, depth + 1);
        }
        return out.writeAll("]}");
    }
    const keys = try engine.enumerableOwnPropertyKeys(realm, value, allocator);
    defer {
        for (keys) |key| allocator.free(key);
        allocator.free(keys);
    }
    try out.writeAll("{\"type\":\"object\",\"value\":[");
    for (keys[0..@min(keys.len, options.max_items)], 0..) |key, i| {
        if (i > 0) try out.writeByte(',');
        try out.writeByte('[');
        try std.json.Stringify.encodeJsonString(key, .{}, out);
        try out.writeByte(',');
        const item = try engine.getProperty(realm, value, key);
        defer item.release();
        try write(out, allocator, realm, item.borrow(), options, depth + 1);
        try out.writeByte(']');
    }
    try out.writeAll("]}");
}

/// A platform object by its kind: BiDi's "window" for a Window, "node" for a
/// Node, else "object".
fn writeInstance(out: *std.Io.Writer, instance: *runtime.Instance) !void {
    if (std.mem.eql(u8, instance.vtable.name, "Window")) return writeTyped(out, "window");
    if (instance.implements(interfaces.Node.State)) return writeTyped(out, "node");
    return writeTyped(out, "object");
}

test "numbers serialize as BiDi's RemoteValue numbers, special values as strings" {
    const testing = std.testing;
    var out: std.Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();
    try writeNumber(&out.writer, 42);
    try writeNumber(&out.writer, -0.0);
    try writeNumber(&out.writer, std.math.nan(f64));
    try writeNumber(&out.writer, -std.math.inf(f64));
    try writeNumber(&out.writer, 1.5);
    try testing.expectEqualStrings(
        "{\"type\":\"number\",\"value\":42}{\"type\":\"number\",\"value\":\"-0\"}{\"type\":\"number\",\"value\":\"NaN\"}{\"type\":\"number\",\"value\":\"-Infinity\"}{\"type\":\"number\",\"value\":1.5}",
        out.written(),
    );
}
