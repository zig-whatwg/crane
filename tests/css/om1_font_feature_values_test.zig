//! Fonts 4 §§6.9 and 12.2; row 128 probes Q33/Q37/Q39, 2026-10-27.
const std = @import("std");
const css = @import("css");

fn mapOwnership(allocator: std.mem.Allocator) anyerror!void {
    if (comptime !@hasDecl(css, "font_feature_values")) return std.testing.expect(false);
    var map: css.font_feature_values.Map = .{};
    defer map.deinit(allocator);
    const key = try allocator.dupe(u8, "Feature");
    defer allocator.free(key);
    const values = try allocator.dupe(u32, &.{ 1, 2, 3 });
    defer allocator.free(values);
    try map.set(allocator, key, values);
    key[0] = 'x';
    values[0] = 9;
    try std.testing.expectEqualSlices(u32, &.{ 1, 2, 3 }, map.get("Feature").?);
    try map.set(allocator, "Other", &.{4});
    // Q33: CSSOM accepts zero values even on a single-valued block.
    try map.set(allocator, "Feature", &.{});
    try std.testing.expectEqual(@as(usize, 0), map.get("Feature").?.len);
    try std.testing.expectEqualStrings("Feature", map.entries.keys()[0]);
    try std.testing.expectEqualStrings("Other", map.entries.keys()[1]);
    try std.testing.expect(map.remove(allocator, "Feature"));
    try std.testing.expect(!map.remove(allocator, "missing"));
    try std.testing.expectEqualStrings("Other", map.entries.keys()[0]);
    map.clear(allocator);
    try std.testing.expectEqual(@as(usize, 0), map.entries.count());
}

test "font feature maps own names and indexes and preserve insertion order under allocation failures" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, mapOwnership, .{});
}

fn parseAndSerialize(allocator: std.mem.Allocator) anyerror!void {
    if (comptime !@hasDecl(css, "font_feature_values")) return std.testing.expect(false);
    var parsed = (try css.rules.parseRule(allocator,
        \\@font-feature-values "serif", "Foo Bar" {
        \\  font-display: swap;
        \\  @styleset { a: 2147483648; b: 4294967295; c: 4294967296; d: 99999999999999999999; zero: 0; more: 21 100; }
        \\  @character-variant { x: 100; y: 100 2; invalid: 1 2 3; }
        \\  @annotation { c: 3; invalid: 1 2; }
        \\  @ornaments { d: 4; }
        \\  @stylistic { e: 5; }
        \\  @swash { f: 6; F: 7; f: 8; }
        \\  @historical-forms { dropped: 1; }
        \\}
    )) orelse return error.TestUnexpectedResult;
    defer parsed.deinitOwned(allocator);
    var data = (try css.font_feature_values.fromParsed(allocator, &parsed)) orelse return error.TestUnexpectedResult;
    defer data.deinit();
    const text = try data.cssText(allocator);
    defer allocator.free(text);
    try std.testing.expectEqualStrings(
        "@font-feature-values \"serif\", Foo Bar { font-display: swap; " ++
            "@swash { f: 8; F: 7; } @stylistic { e: 5; } @ornaments { d: 4; } " ++
            "@annotation { c: 3; } @character-variant { x: 100; y: 100 2; } " ++
            "@styleset { a: 2147483647; b: 2147483647; c: 2147483647; d: 2147483647; zero: 0; more: 21 100; } }",
        text,
    );
    // Parsed source arity is separate from CSSOM set(): Q33's sole shipper
    // accepts all of these sequence lengths for every exposed map.
    inline for (@typeInfo(css.font_feature_values.Block).@"enum".fields) |field| {
        const block: css.font_feature_values.Block = @enumFromInt(field.value);
        for ([_][]const u32{ &.{}, &.{1}, &.{ 1, 2 }, &.{ 1, 2, 3 } }) |sequence| {
            try data.map(block).set(allocator, "probe", sequence);
            try std.testing.expectEqualSlices(u32, sequence, data.map(block).get("probe").?);
        }
    }
    try std.testing.expect(css.font_feature_values.Block.parse("historical-forms") == null);
    for ([_][]const u8{ "", "serif", "A,,B", "\"A\" B" }) |invalid| {
        try std.testing.expect(!try data.setFamily(invalid));
        try std.testing.expectEqualStrings("\"serif\", Foo Bar", data.font_families.text.bytes);
    }
    for ([_][]const u8{ "--A", "A, B", "Foo Bar", "\"serif\"" }, [_][]const u8{ "--A", "A, B", "Foo Bar", "\"serif\"" }) |source, want| {
        try std.testing.expect(try data.setFamily(source));
        try std.testing.expectEqualStrings(want, data.font_families.text.bytes);
    }
}

test "font feature parsed descriptors match all browser probe cases and release every allocation" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, parseAndSerialize, .{});
}
