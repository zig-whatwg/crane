//! Keyword capacity is independent of the Longhand and Value discriminants.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Keyword = css.style_values.Keyword;
const Value = css.style_values.Value;

test "keyword IDs have room beyond u8 and keep per-element layout measurable" {
    const Cursor = @typeInfo(@FieldType(Value, "cursor")).pointer.child;
    std.debug.print("BX1_KEYWORD_LAYOUT keywords={d} Keyword={d} Value={d} Declaration={d} ComputedStyle={d} AnimationItem={d} Cursor={d}\n", .{
        @typeInfo(Keyword).@"enum".field_names.len,
        @sizeOf(Keyword),
        @sizeOf(Value),
        @sizeOf(css.declarations.Declaration),
        @sizeOf(css.computed_style.ComputedStyle),
        @sizeOf(css.animation_values.Item),
        @sizeOf(Cursor),
    });
    try testing.expect(@typeInfo(@typeInfo(Keyword).@"enum".tag_type).int.bits > 8);
    try testing.expect(@FieldType(Value, "keyword") == Keyword);
    try testing.expect(@FieldType(css.animation_values.Item, "keyword") == Keyword);
    try testing.expect(@FieldType(Cursor, "fallback") == Keyword);
}

test "all keyword fields round trip through typed containers and CSS spelling" {
    try keywords(testing.allocator);
}

test "keyword serialization releases every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, keywords, .{});
}

fn keywords(allocator: std.mem.Allocator) !void {
    // Zig 0.17: @typeInfo is struct-of-arrays; rebuild the old field list.
    const fields = comptime zig017_fields: {
        const zig017_info = @typeInfo(Keyword).@"enum";
        var zig017_out: [zig017_info.field_names.len]struct { name: [:0]const u8, value: comptime_int } = undefined;
        for (zig017_info.field_names, zig017_info.field_values, 0..) |zig017_n, zig017_v, zig017_i| zig017_out[zig017_i] = .{ .name = zig017_n, .value = zig017_v };
        break :zig017_fields zig017_out;
    };
    const all_keywords = comptime blk: {
        var all: [fields.len]Keyword = undefined;
        for (fields, 0..) |field, i| all[i] = @fromBackingInt(@intCast(field.value));
        break :blk all;
    };
    // This floor records the baseline without fixing the growing table's size.
    try testing.expect(fields.len >= 160);
    var seen = std.EnumSet(Keyword).empty;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    for (all_keywords) |keyword| {
        const name = keyword.name();
        try testing.expectEqual(keyword, Keyword.parse(name).?);
        var upper: [32]u8 = undefined;
        try testing.expectEqual(keyword, Keyword.parse(std.ascii.upperString(&upper, name)).?);
        const value = Value.kw(keyword);
        value.retain();
        defer value.release();
        try testing.expect(value.isKeyword(keyword));
        try testing.expect(value.eql(.{ .keyword = keyword }));
        // Keyword serialization is independent of a property's grammar; its
        // typed value must survive without any conversion through a byte.
        out.clearRetainingCapacity();
        try css.properties.serializeValue(.white_space_collapse, value, &out, allocator);
        try testing.expectEqualStrings(name, out.items);
        try testing.expect(!seen.contains(keyword));
        seen.insert(keyword);
    }
    try testing.expectEqual(fields.len, seen.count());
    for (css.properties.lexicographic) |longhand| {
        for (longhand.info().keywords) |keyword| {
            try testing.expect(seen.contains(keyword));
            try testing.expectEqual(keyword, Keyword.parse(keyword.name()).?);
        }
    }
}
