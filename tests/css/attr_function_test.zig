//! CSS Values 5 §8.7: attr-specific parsing and conversion, before substitution.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

test "attr names preserve case, decode escapes and distinguish namespace prefixes" {
    const attr = css.attr_function;
    const cases = [_]struct { text: []const u8, prefix: ?[]const u8, local: []const u8 }{
        .{ .text = "data-X", .prefix = null, .local = "data-X" },
        .{ .text = " |data-x ", .prefix = null, .local = "data-x" },
        .{ .text = "ns|data-x", .prefix = "ns", .local = "data-x" },
        .{ .text = "n\\73|d\\61ta-x", .prefix = "ns", .local = "data-x" },
        .{ .text = "ns/**/|/**/data-x", .prefix = "ns", .local = "data-x" },
        .{ .text = "\\69 nitial", .prefix = null, .local = "initial" },
    };
    for (cases) |case| {
        const name = (try attr.parseName(testing.allocator, case.text)) orelse return error.ExpectedAttributeName;
        defer name.deinit(testing.allocator);
        try testing.expectEqualStrings(case.local, name.local_name);
        if (case.prefix) |prefix| {
            try testing.expectEqualStrings(prefix, name.namespace_prefix.?);
        } else try testing.expect(name.namespace_prefix == null);
    }
    for ([_][]const u8{ "", "*|x", "ns|*", "ns |x", "ns| x", "| x", "a||b", "a b", "1x", "\"x\"", "foo()" }) |text| {
        try testing.expect((try attr.parseName(testing.allocator, text)) == null);
    }
}

test "attr simple types accept future units but exclude CSS-wide and default keywords" {
    const attr = css.attr_function;
    try testing.expectEqual(attr.SimpleType.omitted, attr.parseSimpleType("").?);
    try testing.expectEqual(attr.SimpleType.raw_string, attr.parseSimpleType("raw-string").?);
    try testing.expectEqual(attr.SimpleType.raw_string, attr.parseSimpleType(" RAW-STRING ").?);
    try testing.expectEqual(attr.SimpleType.number, attr.parseSimpleType("NUMBER").?);
    try testing.expectEqual(attr.SimpleType.number, attr.parseSimpleType("n\\75mber").?);
    try testing.expectEqual(attr.SimpleType.unknown_unit, attr.parseSimpleType("future-unit").?);
    try testing.expectEqual(attr.SimpleType.unknown_unit, attr.parseSimpleType("string").?);
    for ([_][]const u8{ "inherit", "INITIAL", "unset", "revert", "revert-layer", "default", "\\69 nherit", "&", "px px", "10px" }) |text| {
        try testing.expect(attr.parseSimpleType(text) == null);
    }
    inline for (@typeInfo(css.math_values.Unit).@"enum".field_values) |field_value| {
        const unit: css.math_values.Unit = @enumFromInt(field_value);
        if (unit != .number and unit.base() != .resolution) try testing.expectEqual(unit, attr.parseSimpleType(unit.name()).?.unit);
    }
    for ([_][]const u8{ "dpi", "dpcm", "dppx", "x", "DPI" }) |text| {
        try testing.expectEqual(attr.SimpleType.unknown_unit, attr.parseSimpleType(text).?);
    }
}

fn expectConversion(allocator: std.mem.Allocator, type_text: []const u8, input: []const u8, expected: ?[]const u8) !void {
    const attr = css.attr_function;
    const result = try attr.convertSimple(allocator, attr.parseSimpleType(type_text).?, input);
    defer if (result) |text| allocator.free(text);
    if (expected) |text| {
        try testing.expectEqualStrings(text, result orelse return error.ExpectedConvertedValue);
    } else try testing.expect(result == null);
}

test "attr raw strings preserve whitespace, CSS-looking text, quotes and controls" {
    try expectConversion(testing.allocator, "", "", "\"\"");
    try expectConversion(testing.allocator, "", "  var(--x) /* literal */  ", "\"  var(--x) /* literal */  \"");
    try expectConversion(testing.allocator, "raw-string", "a\"b\\c\n\r\t", "\"a\\\"b\\\\c\\a \\d \\9 \"");
    try expectConversion(testing.allocator, "raw-string", "attr(", "\"attr(\"");
    try expectConversion(testing.allocator, "raw-string", "\x00", "\"\u{fffd}\"");
}

test "attr number and unit conversion consumes one number token" {
    try expectConversion(testing.allocator, "number", " \t+12.50\r\n", "12.5");
    try expectConversion(testing.allocator, "PX", "1e2", "100px");
    try expectConversion(testing.allocator, "%", "-.5", "-0.5%");
    try expectConversion(testing.allocator, "ms", "0", "0ms");
    try expectConversion(testing.allocator, "n\\75mber", "-0", "0");
    try expectConversion(testing.allocator, "NUMBER", "/**/12/**/", "12");
    try expectConversion(testing.allocator, "px", " \t/**/12/**/ \n", "12px");
    try expectConversion(testing.allocator, "future-unit", "12", null);
    try expectConversion(testing.allocator, "dpi", "12", null);
    for ([_][]const u8{ "", " ", "10px", "10%", "1e", "calc(2)", "var(--x)", "NaN", "infinity", "12 34", "12/**/34", "12,", "12;" }) |input| {
        try expectConversion(testing.allocator, "number", input, null);
        try expectConversion(testing.allocator, "px", input, null);
    }
}

test "attr oversized numbers use the engine's finite range and serializer" {
    for ([_]f64{ std.math.floatMax(f64), -std.math.floatMax(f64) }, [_][]const u8{ "1e999", "-1e999" }) |limit, input| {
        var expected: std.ArrayList(u8) = .empty;
        defer expected.deinit(testing.allocator);
        try css.style_values.appendNumber(limit, &expected, testing.allocator);
        try expectConversion(testing.allocator, "number", input, expected.items);
        try expected.appendSlice(testing.allocator, "px");
        try expectConversion(testing.allocator, "px", input, expected.items);
    }
}

test "attr URL taint follows component ranges and keeps adjacent literal URLs valid" {
    const attr = css.attr_function;
    const Range = css.style_values.ResourceUrl.Range;
    const url: Range = .{ .start = 10, .end = 30 };
    try testing.expect(!attr.urlIsTainted(url, &.{}));
    try testing.expect(!attr.urlIsTainted(url, &.{ .{ .start = 0, .end = 10 }, .{ .start = 30, .end = 40 } }));
    try testing.expect(attr.urlIsTainted(url, &.{.{ .start = 15, .end = 20 }}));
    try testing.expect(attr.urlIsTainted(url, &.{.{ .start = 0, .end = 100 }}));
    try testing.expect(attr.urlIsTainted(url, &.{.{ .start = 29, .end = 40 }}));
    try testing.expect(attr.urlIsTainted(url, &.{.{ .start = 0, .end = 11 }}));
    // Empty replacement sequences contribute no URL characters.
    try testing.expect(!attr.urlIsTainted(url, &.{.{ .start = 20, .end = 20 }}));
    try testing.expect(!attr.urlIsTainted(.{ .start = 20, .end = 20 }, &.{.{ .start = 0, .end = 100 }}));
}

test "attr failure distinguishes omitted type and omitted or empty fallback" {
    const attr = css.attr_function;
    try testing.expectEqual(attr.Fallback.empty_string, attr.fallbackFor(true, null));
    try testing.expectEqual(attr.Fallback.invalid, attr.fallbackFor(false, null));
    try testing.expectEqualStrings("", attr.fallbackFor(true, "").substitute);
    try testing.expectEqualStrings("", attr.fallbackFor(false, "").substitute);
    try testing.expectEqualStrings("var(--fallback)", attr.fallbackFor(false, "var(--fallback)").substitute);
}

fn allocationCase(allocator: std.mem.Allocator) anyerror!void {
    const name = (try css.attr_function.parseName(allocator, "n\\73|data-x")).?;
    defer name.deinit(allocator);
    try expectConversion(allocator, "raw-string", "\"long\\\nattribute value\"", "\"\\\"long\\\\\\a attribute value\\\"\"");
    try expectConversion(allocator, "px", "12.5", "12.5px");
}

test "attr helpers release every allocation on OOM" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{});
}
